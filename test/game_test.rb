# frozen_string_literal: true

require_relative "test_helper"

class GameTest < Minitest::Test
  class SequenceAI
    def initialize(*coordinates)
      @coordinates = coordinates
    end

    def choose_attack(_board)
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

  def test_requires_both_boards_to_have_a_fleet
    populated_board = board_with_ships([[[0, 0]]])

    assert_raises(ArgumentError) do
      Game.new(player_board: Board.new(3), enemy_board: populated_board)
    end
    assert_raises(ArgumentError) do
      Game.new(player_board: populated_board, enemy_board: Board.new(3))
    end
  end

  def test_requires_distinct_boards_with_the_same_size
    board = board_with_ships([[[0, 0]]])
    smaller_board = Board.new(2)
    smaller_board.place_ship(Ship.new("Navio", 1), [[0, 0]])

    assert_raises(ArgumentError) do
      Game.new(player_board: board, enemy_board: board)
    end
    assert_raises(ArgumentError) do
      Game.new(player_board: board, enemy_board: smaller_board)
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
  end

  private

  def build_game(
    player_ships:,
    enemy_ships:,
    turn_strategy: SingleShotTurnStrategy.new,
    ai: RandomAI.new(random: Random.new(7)),
    first_turn: :player,
    clock: nil
  )
    Game.new(
      player_board: board_with_ships(player_ships),
      enemy_board: board_with_ships(enemy_ships),
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
