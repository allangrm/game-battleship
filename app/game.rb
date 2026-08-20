# frozen_string_literal: true

require_relative "controllers/attack_handler"
require_relative "turn_strategies/single_shot"
require_relative "ai/ai_factory"
require_relative "weapons/weapon_inventory"

# Mantém o estado e as regras de uma partida entre jogador e computador.
# Toda alteração de Cell/Ship continua delegada ao Board via AttackHandler.
#
# @author Júlio Pedro
# @version 1.2
class Game
  class InvalidTurnError < StandardError; end
  class GameFinishedError < StandardError; end
  class GameNotFinishedError < StandardError; end

  TURNS = %i[player computer].freeze
  FINAL_STATES = %i[victory defeat].freeze

  CellResult = Struct.new(:row, :col, :status, keyword_init: true) do
    def hit?
      %i[hit sunk].include?(status)
    end
  end

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
    def hit?
      cells.any?(&:hit?)
    end

    def game_over?
      %i[victory defeat].include?(state)
    end
  end

  attr_reader :player_board, :enemy_board, :current_turn, :state,
              :started_at, :ended_at, :turn_strategy, :map_type,
              :player_inventory, :computer_inventory, :ai

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
    validate_board!(:player_board, player_board)
    validate_board!(:enemy_board, enemy_board)
    raise ArgumentError, "Os tabuleiros precisam ser objetos diferentes" if player_board.equal?(enemy_board)
    raise ArgumentError, "Os tabuleiros precisam ter o mesmo tamanho" unless player_board.size == enemy_board.size

    default_player_inventory = WeaponInventory.for_map(map_type)
    @map_type = default_player_inventory.map_type
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

  def playing?
    state == :playing
  end

  def victory?
    state == :victory
  end

  def defeat?
    state == :defeat
  end

  def finished?
    FINAL_STATES.include?(state)
  end

  def winner
    return :player if victory?
    return :computer if defeat?

    nil
  end

  def result
    return :vitoria if victory?
    return :derrota if defeat?

    nil
  end

  def history
    @history.dup.freeze
  end

  def inventory_for(actor)
    return player_inventory if actor == :player
    return computer_inventory if actor == :computer

    raise ArgumentError, "Ator inválido: #{actor.inspect}"
  end

  def duration_seconds
    reference_time = ended_at || @clock.call
    [(reference_time - started_at).floor, 0].max
  end

  # Hash compatível diretamente com ScoreCalculator.calculate(**attributes).
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

  def snapshot_results(attack_results)
    attack_results.map do |result|
      CellResult.new(
        row: result.cell.row,
        col: result.cell.col,
        status: result.status
      ).freeze
    end.freeze
  end

  def update_final_state!(actor, target_board)
    return unless target_board.all_ships_sunk?

    @state = actor == :player ? :victory : :defeat
    @ended_at = @clock.call
  end

  def ensure_can_attack!(actor)
    raise GameFinishedError, "A partida já terminou" if finished?
    return if current_turn == actor

    raise InvalidTurnError, "É o turno de #{current_turn}, não de #{actor}"
  end

  def opposite_turn(actor)
    actor == :player ? :computer : :player
  end

  def validate_board!(name, board)
    raise ArgumentError, "#{name} precisa ser um Board" unless board.is_a?(Board)
    raise ArgumentError, "#{name} precisa ter ao menos um navio posicionado" if board.ships.empty?
  end

  def validate_collaborator!(name, collaborator, method_name)
    return if collaborator.respond_to?(method_name)

    raise ArgumentError, "#{name} precisa responder a ##{method_name}"
  end

  def validate_inventory!(name, inventory)
    unless inventory.is_a?(WeaponInventory)
      raise ArgumentError, "#{name} precisa ser um WeaponInventory"
    end
    return if inventory.map_type.nil? || inventory.map_type == map_type

    raise ArgumentError, "#{name} pertence ao mapa #{inventory.map_type}, não a #{map_type}"
  end
end
