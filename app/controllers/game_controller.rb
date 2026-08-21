# frozen_string_literal: true

require_relative "../game"
require_relative "../weapons/basic_shot"

# Fachada de aplicação entre GameView e o domínio mantido por Game.
#
# Game executa uma única ação e protege as regras. Este controller coordena o
# caso de uso completo iniciado por um clique humano: registra o evento do
# jogador e, quando o turno muda, executa automaticamente a IA até o controle
# voltar ao jogador ou a partida terminar.
#
# Essa separação mantém loops de aplicação fora de Game e impede que a view
# precise conhecer detalhes da dinâmica de turnos.
#
# @author Júlio Pedro
# @version 1.1
class GameController
  attr_reader :game

  # @param game [Game] partida já criada e pronta para receber ações
  # @raise [ArgumentError] se o objeto não for uma instância de Game
  def initialize(game)
    raise ArgumentError, "game precisa ser um Game" unless game.is_a?(Game)

    @game = game
  end

  # Processa uma ação humana e todas as respostas automáticas decorrentes.
  #
  # No modo de tiro adicional, o primeiro evento pode manter o turno humano; nesse
  # caso nenhuma ação da IA é produzida. Quando o turno passa ao computador, o
  # retorno contém o evento humano seguido dos eventos da IA em ordem temporal.
  #
  # @param row [Integer] linha da origem selecionada
  # @param col [Integer] coluna da origem selecionada
  # @param weapon [Weapon] arma escolhida pelo jogador
  # @param options [Hash] opções específicas, como orientation do Airplane
  # @return [Array<Game::AttackEvent>] sequência congelada de eventos
  # @raise [InvalidAttackError, Game::InvalidTurnError] se a jogada for inválida
  # @raise [WeaponInventory::WeaponUnavailableError] se não houver carga
  def handle_player_attack(row, col, weapon = BasicShot.new, **options)
    events = [game.player_attack(row, col, weapon, **options)]
    events.concat(resolve_computer_turn)
    events.freeze
  end

  alias attack handle_player_attack

  # Executa a IA enquanto o domínio mantiver o turno do computador.
  #
  # O laço é necessário porque ExtraShotOnHitTurnStrategy pode conceder várias
  # ações consecutivas. Também pode ser chamado ao iniciar uma partida em que o
  # computador recebeu o primeiro turno.
  #
  # @return [Array<Game::AttackEvent>] eventos congelados em ordem de execução
  def resolve_computer_turn
    events = []

    while game.playing? && game.current_turn == :computer
      events << game.computer_attack
    end

    events.freeze
  end
end
