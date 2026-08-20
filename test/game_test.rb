# frozen_string_literal: true

require_relative "test_helper"

class GameTest < Minitest::Test
  class SequenceAI
    def initialize(*coordinates)
      @coordinates = coordinates
    end

    def choose_attack(_board, inventory: nil)
      row, col = @coordinates.shift
      raise "Sequência da IA esgotada" if row.nil?

      RandomAI::Decision.new(
        row: row,
        col: col,
        weapon: BasicShot.new,
        options: {}
      ).freeze
    end
  end

  class SpecialWeaponAI
    attr_reader :received_inventory

    def choose_attack(_board, inventory:)
      @received_inventory = inventory
      RandomAI::Decision.new(
        row: 0,
        col: 0,
        weapon: Missile.new,
        options: {}
      ).freeze
    end
  end

  def test_requires_both_boards_to_have_a_fleet
    populated_board = board_with_ships([[[0, 0]]])

    assert_raises(ArgumentError) do
      Game.new(player_board: Board.new(3), enemy_board: populated_board, map_type: :poca)
    end
    assert_raises(ArgumentError) do
      Game.new(player_board: populated_board, enemy_board: Board.new(3), map_type: :poca)
    end
  end

  def test_requires_distinct_boards_with_the_same_size
    board = board_with_ships([[[0, 0]]])
    smaller_board = Board.new(2)
    smaller_board.place_ship(Ship.new("Navio", 1), [[0, 0]])

    assert_raises(ArgumentError) do
      Game.new(player_board: board, enemy_board: board, map_type: :poca)
    end
    assert_raises(ArgumentError) do
      Game.new(player_board: board, enemy_board: smaller_board, map_type: :poca)
    end
  end

  def test_requires_independent_inventories_from_the_selected_map
    player_board = board_with_ships([[[0, 0]]])
    enemy_board = board_with_ships([[[1, 1]]])
    shared_inventory = WeaponInventory.for_map(:poca)

    assert_raises(ArgumentError) do
      Game.new(
        player_board: player_board,
        enemy_board: enemy_board,
        map_type: :poca,
        player_inventory: shared_inventory,
        computer_inventory: shared_inventory
      )
    end

    assert_raises(ArgumentError) do
      Game.new(
        player_board: player_board,
        enemy_board: enemy_board,
        map_type: :poca,
        player_inventory: WeaponInventory.for_map(:lago)
      )
    end
  end

  def test_single_shot_changes_turn_even_after_a_hit
    game = build_game(
      player_ships: [[[2, 1], [2, 2]]],
      enemy_ships: [[[0, 0], [0, 1]]]
    )

    event = game.player_attack(0, 0)

    assert event.hit?
    refute event.extra_turn
    assert_equal :computer, game.current_turn
    assert_equal :playing, event.state
    assert_equal({ row: 0, col: 0, status: :hit }, event.cells.first.to_h)
  end

  def test_extra_shot_uses_any_hit_from_a_mixed_area_result
    game = build_game(
      player_ships: [[[2, 0], [2, 1]]],
      enemy_ships: [
        [[0, 0], [1, 0]],
        [[2, 2]]
      ],
      turn_strategy: ExtraShotOnHitTurnStrategy.new
    )

    event = game.player_attack(0, 0, Missile.new)

    assert_equal %i[hit sunk miss miss], event.cells.map(&:status)
    assert event.extra_turn
    assert_equal :player, event.turn_after
    assert game.playing?
  end

  def test_special_charge_is_consumed_only_after_a_valid_attack
    game = build_game(
      player_ships: [[[2, 0], [2, 1]]],
      enemy_ships: [
        [[0, 0]],
        [[2, 2]]
      ],
      turn_strategy: ExtraShotOnHitTurnStrategy.new
    )

    assert_raises(InvalidAttackError) { game.player_attack(-1, 0, Missile.new) }
    assert_equal 1, game.player_inventory.remaining(:missile)

    event = game.player_attack(0, 0, Missile.new)

    assert_equal 0, event.remaining_uses
    assert_equal 0, game.player_inventory.remaining(:missile)
    assert event.extra_turn
    assert_raises(WeaponInventory::WeaponUnavailableError) do
      game.player_attack(2, 2, Missile.new)
    end
    refute game.enemy_board.cell_at(2, 2).attacked?
  end

  def test_repeated_origin_and_invalid_direction_do_not_consume_charges
    game = build_game(
      player_ships: [[[2, 0], [2, 1]]],
      enemy_ships: [
        [[0, 0]],
        [[2, 2]]
      ],
      map_type: :lago,
      turn_strategy: ExtraShotOnHitTurnStrategy.new
    )

    game.player_attack(0, 0, Missile.new)
    assert_equal 1, game.player_inventory.remaining(:missile)

    assert_raises(InvalidAttackError) { game.player_attack(0, 0, Missile.new) }
    assert_equal 1, game.player_inventory.remaining(:missile)

    assert_raises(ArgumentError) do
      game.player_attack(2, 2, Torpedo.new, direction: :diagonal)
    end
    assert_equal 2, game.player_inventory.remaining(:torpedo)
  end

  def test_computer_receives_its_inventory_and_can_spend_a_special_weapon
    ai = SpecialWeaponAI.new
    game = build_game(
      player_ships: [
        [[0, 0]],
        [[2, 2]]
      ],
      enemy_ships: [[[1, 1]]],
      ai: ai,
      first_turn: :computer
    )

    event = game.computer_attack

    assert_same game.computer_inventory, ai.received_inventory
    assert_equal :missile, event.weapon
    assert_equal 0, event.remaining_uses
    assert_equal 0, game.computer_inventory.remaining(:missile)
    assert_equal 1, game.player_inventory.remaining(:missile)
  end

  def test_victory_freezes_duration_and_exposes_scoring_statistics
    clock_values = [10.0, 85.9]
    game = build_game(
      player_ships: [[[2, 2]]],
      enemy_ships: [[[1, 1]]],
      clock: -> { clock_values.shift }
    )

    event = game.player_attack(1, 1)

    assert event.game_over?
    assert_equal :victory, event.state
    assert_equal :player, event.winner
    assert game.victory?
    assert_equal 75, game.duration_seconds
    assert_equal(
      {
        hits: 1,
        surviving_ships: 1,
        remaining_ship_cells: 1,
        duration_seconds: 75
      },
      game.final_statistics
    )
    assert_equal :vitoria, game.result
    assert_equal 575, ScoreCalculator.calculate(**game.final_statistics)
    assert_raises(Game::GameFinishedError) { game.player_attack(0, 0) }
  end

  def test_computer_can_finish_the_game_with_defeat
    game = build_game(
      player_ships: [[[1, 1]]],
      enemy_ships: [[[2, 2]]],
      ai: SequenceAI.new([1, 1]),
      first_turn: :computer
    )

    event = game.computer_attack

    assert_equal :computer, event.actor
    assert_equal :defeat, event.state
    assert_equal :computer, event.winner
    assert game.defeat?
    assert_equal 0, game.final_statistics[:surviving_ships]
    assert_equal 0, game.final_statistics[:remaining_ship_cells]
    assert_equal :derrota, game.result
  end

  def test_rejects_action_from_the_wrong_turn_and_early_statistics
    game = build_game(
      player_ships: [[[2, 2]]],
      enemy_ships: [[[0, 0]]]
    )

    assert_raises(Game::InvalidTurnError) { game.computer_attack }
    assert_raises(Game::GameNotFinishedError) { game.final_statistics }
  end

  def test_history_uses_coordinate_snapshots_instead_of_mutable_cells
    game = build_game(
      player_ships: [[[2, 1], [2, 2]]],
      enemy_ships: [[[0, 0], [0, 1]]]
    )

    event = game.player_attack(0, 0)

    assert_same event, game.history.first
    assert event.frozen?
    assert event.cells.frozen?
    assert event.cells.first.frozen?
    assert_equal :basic_shot, event.weapon
    assert_nil event.remaining_uses
    assert_nil game.player_inventory.remaining(:basic_shot)
  end

  private

  def build_game(
    player_ships:,
    enemy_ships:,
    map_type: :poca,
    turn_strategy: SingleShotTurnStrategy.new,
    ai: RandomAI.new(random: Random.new(7)),
    first_turn: :player,
    clock: nil
  )
    Game.new(
      player_board: board_with_ships(player_ships),
      enemy_board: board_with_ships(enemy_ships),
      map_type: map_type,
      turn_strategy: turn_strategy,
      ai: ai,
      first_turn: first_turn,
      clock: clock
    )
  end

  def board_with_ships(ship_coordinates)
    board = Board.new(3)

    ship_coordinates.each_with_index do |coordinates, index|
      board.place_ship(Ship.new("Navio #{index}", coordinates.length), coordinates)
    end

    board
  end
end
