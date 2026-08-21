# frozen_string_literal: true

require_relative "controllers/attack_handler"
require_relative "models/map_config"
require_relative "turn_strategies/single_shot"
require_relative "ai/ai_factory"
require_relative "weapons/weapon_inventory"

# Agregado central do domínio de uma partida entre jogador e computador.
#
# A classe funciona como uma máquina de estados. Ela conhece o turno atual, os
# inventários, a estratégia de turno, a IA, o histórico e o encerramento, mas
# não altera Cell ou Ship diretamente. O dano continua delegado ao Board por
# meio de AttackHandler.
#
# O fluxo de uma ação é sempre o mesmo para jogador e computador:
#
# 1. validar estado, turno e carga da arma;
# 2. executar a arma no tabuleiro-alvo por AttackHandler;
# 3. consumir a carga após a validação;
# 4. verificar vitória/derrota e aplicar a estratégia de turno;
# 5. produzir um AttackEvent imutável para controllers e views.
#
# Essa centralização garante que a IA não possua regras privilegiadas: uma
# Decision do computador percorre exatamente o mesmo pipeline de ataque humano.
#
# @author Júlio Pedro
# @version 1.3
class Game
  # Erro levantado quando um ator tenta atacar fora do próprio turno.
  class InvalidTurnError < StandardError; end

  # Erro levantado quando uma nova ação é solicitada após o encerramento.
  class GameFinishedError < StandardError; end

  # Erro levantado quando dados finais são solicitados durante a partida.
  class GameNotFinishedError < StandardError; end

  # Atores aceitos pelo controle de turno.
  TURNS = %i[player computer].freeze

  # Estados que impedem qualquer novo ataque.
  FINAL_STATES = %i[victory defeat].freeze

  # Snapshot público e imutável de uma célula modificada por um ataque.
  # Diferentemente de Cell, não expõe referências mutáveis do tabuleiro.
  CellResult = Struct.new(:row, :col, :status, keyword_init: true) do
    # Indica se o resultado representa dano a uma embarcação.
    #
    # @return [Boolean] true para :hit e :sunk
    def hit?
      %i[hit sunk].include?(status)
    end
  end

  # Evento público de uma ativação de arma completa.
  #
  # Uma arma de área pode gerar vários CellResult, mas continua formando um
  # único evento e, portanto, concede no máximo uma continuação de turno.
  AttackEvent = Struct.new(
    :actor,
    :weapon,
    :remaining_uses,
    :cells,
    :turn_before,
    :turn_after,
    :state,
    :extra_turn,
    :winner,
    keyword_init: true
  ) do
    # @return [Boolean] true se ao menos uma célula do evento sofreu dano
    def hit?
      cells.any?(&:hit?)
    end

    # @return [Boolean] true quando o evento encerrou a partida
    def game_over?
      %i[victory defeat].include?(state)
    end
  end

  attr_reader :player_board, :enemy_board, :current_turn, :state,
              :started_at, :ended_at, :turn_strategy, :map_type,
              :player_inventory, :computer_inventory, :ai

  # Cria e valida todos os colaboradores necessários a uma partida.
  #
  # Os tabuleiros precisam corresponder integralmente ao MapConfig informado:
  # tamanho, navios posicionados e composição da frota por tamanho. A IA, a
  # estratégia, os inventários e o relógio podem ser injetados para permitir
  # extensões e testes determinísticos.
  #
  # @param player_board [Board] tabuleiro aliado já configurado
  # @param enemy_board [Board] tabuleiro inimigo já configurado
  # @param map_type [Symbol, String] :poca, :lago ou :oceano
  # @param turn_strategy [#keep_turn?] política de continuação do turno
  # @param ai [#choose_attack, nil] estratégia do computador; nil usa AIFactory
  # @param player_inventory [WeaponInventory, nil] inventário humano opcional
  # @param computer_inventory [WeaponInventory, nil] inventário da IA opcional
  # @param first_turn [Symbol] :player ou :computer
  # @param clock [#call, nil] fonte de tempo monotônico injetável
  # @raise [ArgumentError] se qualquer invariante de criação for violada
  def initialize(
    player_board:,
    enemy_board:,
    map_type:,
    turn_strategy: SingleShotTurnStrategy.new,
    ai: nil,
    player_inventory: nil,
    computer_inventory: nil,
    first_turn: :player,
    clock: nil
  )
    map_config = MapConfig.new(normalize_map_type(map_type))
    validate_board!(:player_board, player_board, map_config)
    validate_board!(:enemy_board, enemy_board, map_config)
    raise ArgumentError, "Os tabuleiros precisam ser objetos diferentes" if player_board.equal?(enemy_board)

    @map_type = map_config.map_type
    default_player_inventory = WeaponInventory.for_map(@map_type)
    @player_inventory = player_inventory || default_player_inventory
    @computer_inventory = computer_inventory || WeaponInventory.for_map(@map_type)
    validate_inventory!(:player_inventory, @player_inventory)
    validate_inventory!(:computer_inventory, @computer_inventory)
    if @player_inventory.equal?(@computer_inventory)
      raise ArgumentError, "Jogador e computador precisam de inventários independentes"
    end

    selected_ai = ai || AIFactory.for_map(@map_type)
    validate_collaborator!(:turn_strategy, turn_strategy, :keep_turn?)
    validate_collaborator!(:ai, selected_ai, :choose_attack)
    raise ArgumentError, "Turno inicial inválido: #{first_turn.inspect}" unless TURNS.include?(first_turn)

    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    validate_collaborator!(:clock, @clock, :call)

    @player_board = player_board
    @enemy_board = enemy_board
    @turn_strategy = turn_strategy
    @ai = selected_ai
    @current_turn = first_turn
    @state = :playing
    @history = []
    @started_at = @clock.call
    @ended_at = nil
  end

  # Executa uma ação do jogador contra o tabuleiro inimigo.
  #
  # @param row [Integer] linha da origem selecionada
  # @param col [Integer] coluna da origem selecionada
  # @param weapon [Weapon] arma escolhida; tiro básico por padrão
  # @param options [Hash] opções específicas, como orientation para Airplane
  # @return [AttackEvent] snapshot completo da ação
  # @raise [InvalidTurnError] se não for o turno do jogador
  # @raise [GameFinishedError] se a partida já terminou
  # @raise [InvalidAttackError] se a origem for inválida ou repetida
  # @raise [WeaponInventory::WeaponUnavailableError] se não houver carga
  def player_attack(row, col, weapon = BasicShot.new, **options)
    perform_attack(
      actor: :player,
      target_board: enemy_board,
      row: row,
      col: col,
      weapon: weapon,
      options: options
    )
  end

  # Solicita uma Decision à IA e a executa contra o tabuleiro aliado.
  #
  # A IA somente escolhe origem, arma e opções. Disponibilidade, consumo,
  # aplicação do dano, turno e encerramento continuam sob responsabilidade de
  # Game, preservando as mesmas regras utilizadas pelo jogador.
  #
  # @return [AttackEvent] snapshot completo da ação do computador
  # @raise [InvalidTurnError] se não for o turno do computador
  # @raise [GameFinishedError] se a partida já terminou
  def computer_attack
    ensure_can_attack!(:computer)
    decision = @ai.choose_attack(player_board, inventory: computer_inventory)

    perform_attack(
      actor: :computer,
      target_board: player_board,
      row: decision.row,
      col: decision.col,
      weapon: decision.weapon,
      options: decision.options || {}
    )
  end

  # @return [Boolean] true enquanto nenhum participante perdeu a frota
  def playing?
    state == :playing
  end

  # @return [Boolean] true quando o jogador afundou toda a frota inimiga
  def victory?
    state == :victory
  end

  # @return [Boolean] true quando o computador afundou toda a frota aliada
  def defeat?
    state == :defeat
  end

  # @return [Boolean] true para os estados finais :victory ou :defeat
  def finished?
    FINAL_STATES.include?(state)
  end

  # Traduz o estado final para o ator vencedor.
  #
  # @return [Symbol, nil] :player, :computer ou nil durante a partida
  def winner
    return :player if victory?
    return :computer if defeat?

    nil
  end

  # Traduz o estado para o vocabulário usado pela camada de persistência.
  #
  # @return [Symbol, nil] :vitoria, :derrota ou nil durante a partida
  def result
    return :vitoria if victory?
    return :derrota if defeat?

    nil
  end

  # Expõe o histórico sem permitir alteração do array interno.
  # Os próprios AttackEvent armazenados também são imutáveis.
  #
  # @return [Array<AttackEvent>] cópia congelada em ordem cronológica
  def history
    @history.dup.freeze
  end

  # Seleciona o inventário independente de um participante.
  #
  # @param actor [Symbol] :player ou :computer
  # @return [WeaponInventory]
  # @raise [ArgumentError] se o ator for desconhecido
  def inventory_for(actor)
    return player_inventory if actor == :player
    return computer_inventory if actor == :computer

    raise ArgumentError, "Ator inválido: #{actor.inspect}"
  end

  # Calcula a duração usando ended_at depois do fim ou o instante atual.
  # O resultado nunca é negativo e permanece estável após o encerramento.
  #
  # @return [Integer] segundos completos decorridos
  def duration_seconds
    reference_time = ended_at || @clock.call
    [(reference_time - started_at).floor, 0].max
  end

  # Produz o contrato consumido diretamente por ScoreCalculator.
  #
  # @return [Hash] acertos, sobreviventes, integridade e duração
  # @raise [GameNotFinishedError] se a partida ainda estiver em andamento
  def final_statistics
    raise GameNotFinishedError, "A partida ainda não terminou" unless finished?

    {
      hits: enemy_board.ships.sum(&:hits),
      surviving_ships: player_board.ships_remaining,
      remaining_ship_cells: player_board.ships.sum(&:remaining_cells),
      duration_seconds: duration_seconds
    }.freeze
  end

  private

  # Pipeline único de ataque compartilhado por jogador e computador.
  # A carga é consumida apenas depois que AttackHandler valida a ação.
  #
  # @return [AttackEvent]
  # @api private
  def perform_attack(actor:, target_board:, row:, col:, weapon:, options:)
    ensure_can_attack!(actor)
    inventory = inventory_for(actor)
    unless inventory.available?(weapon)
      raise WeaponInventory::WeaponUnavailableError,
            "A arma #{weapon.identifier} não possui cargas restantes"
    end

    turn_before = current_turn
    attack_results = AttackHandler.new(target_board).attack(row, col, weapon, **options)
    remaining_uses = inventory.consume!(weapon)
    cell_results = snapshot_results(attack_results)

    update_final_state!(actor, target_board)
    extra_turn = playing? && turn_strategy.keep_turn?(cell_results)
    @current_turn = opposite_turn(actor) if playing? && !extra_turn

    event = AttackEvent.new(
      actor: actor,
      weapon: weapon.identifier,
      remaining_uses: remaining_uses,
      cells: cell_results,
      turn_before: turn_before,
      turn_after: current_turn,
      state: state,
      extra_turn: extra_turn,
      winner: winner
    ).freeze

    @history << event
    event
  end

  # Desacopla o evento público dos objetos Cell mutáveis pertencentes ao Board.
  #
  # @return [Array<CellResult>] resultados congelados
  # @api private
  def snapshot_results(attack_results)
    attack_results.map do |result|
      CellResult.new(
        row: result.cell.row,
        col: result.cell.col,
        status: result.status
      ).freeze
    end.freeze
  end

  # Encerra a partida quando todos os navios do alvo foram afundados.
  # Também congela logicamente a duração ao registrar ended_at uma única vez.
  #
  # @api private
  def update_final_state!(actor, target_board)
    return unless target_board.all_ships_sunk?

    @state = actor == :player ? :victory : :defeat
    @ended_at = @clock.call
  end

  # Protege as invariantes de estado e de turno antes de qualquer ataque.
  #
  # @api private
  def ensure_can_attack!(actor)
    raise GameFinishedError, "A partida já terminou" if finished?
    return if current_turn == actor

    raise InvalidTurnError, "É o turno de #{current_turn}, não de #{actor}"
  end

  # @return [Symbol] o participante oposto
  # @api private
  def opposite_turn(actor)
    actor == :player ? :computer : :player
  end

  # Acrescenta o nome do argumento ao erro produzido por MapConfig.
  #
  # @api private
  def validate_board!(name, board, map_config)
    map_config.validate_board!(board)
  rescue ArgumentError => error
    raise ArgumentError, "#{name} inválido: #{error.message}"
  end

  # @return [Symbol] representação normalizada do tipo de mapa
  # @api private
  def normalize_map_type(map_type)
    map_type.to_s.strip.to_sym
  end

  # Aplica duck typing explícito aos colaboradores injetáveis.
  #
  # @api private
  def validate_collaborator!(name, collaborator, method_name)
    return if collaborator.respond_to?(method_name)

    raise ArgumentError, "#{name} precisa responder a ##{method_name}"
  end

  # Garante tipo correto e compatibilidade entre inventário e mapa.
  # Inventários sem map_type são aceitos para testes ou configurações customizadas.
  #
  # @api private
  def validate_inventory!(name, inventory)
    unless inventory.is_a?(WeaponInventory)
      raise ArgumentError, "#{name} precisa ser um WeaponInventory"
    end
    return if inventory.map_type.nil? || inventory.map_type == map_type

    raise ArgumentError, "#{name} pertence ao mapa #{inventory.map_type}, não a #{map_type}"
  end
end
