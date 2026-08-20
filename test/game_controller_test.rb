# frozen_string_literal: true

require_relative "test_helper"

class GameControllerTest < Minitest::Test
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

  def test_resolves_one_computer_action_in_single_shot_mode
    game = build_game(
      player_ships: [[[2, 2]]],
      enemy_ships: [[[0, 0]]],
      ai: SequenceAI.new([0, 2])
    )

    events = GameController.new(game).handle_player_attack(1, 1)

    assert_equal %i[player computer], events.map(&:actor)
    assert_equal %i[miss miss], events.map { |event| event.cells.first.status }
    assert_equal :player, game.current_turn
    assert events.frozen?
  end

  def test_computer_keeps_playing_after_hits_in_sequential_mode
    game = build_game(
      player_ships: [[[0, 0], [0, 1]]],
      enemy_ships: [[[2, 2]]],
      turn_strategy: ExtraShotOnHitTurnStrategy.new,
      ai: SequenceAI.new([0, 0], [0, 1])
    )

    events = GameController.new(game).handle_player_attack(1, 1)

    assert_equal %i[player computer computer], events.map(&:actor)
    assert_equal %i[miss hit sunk], events.map { |event| event.cells.first.status }
    assert game.defeat?
    assert_equal :computer, events.last.winner
  end

  def test_does_not_run_computer_while_player_keeps_the_turn
    game = build_game(
      player_ships: [[[2, 2]]],
      enemy_ships: [[[0, 0], [0, 1]]],
      turn_strategy: ExtraShotOnHitTurnStrategy.new,
      ai: SequenceAI.new([2, 2])
    )

    events = GameController.new(game).attack(0, 0)

    assert_equal [:player], events.map(&:actor)
    assert events.first.extra_turn
    assert_equal :player, game.current_turn
  end

  def test_can_resolve_a_computer_first_turn
    game = build_game(
      player_ships: [[[2, 2]]],
      enemy_ships: [[[0, 0]]],
      ai: SequenceAI.new([1, 1]),
      first_turn: :computer
    )

    events = GameController.new(game).resolve_computer_turn

    assert_equal [:computer], events.map(&:actor)
    assert_equal :player, game.current_turn
  end

  def test_forwards_airplane_orientation_and_returns_stable_weapon_identifier
    game = build_game(
      player_ships: [[[2, 2]]],
      enemy_ships: [[[0, 1], [1, 1]]],
      ai: SequenceAI.new
    )

    events = GameController.new(game).handle_player_attack(
      0,
      1,
      Airplane.new,
      orientation: :col
    )

    assert_equal 1, events.length
    assert_equal :airplane, events.first.weapon
    assert_equal %i[hit sunk miss], events.first.cells.map(&:status)
    assert game.victory?
  end

  private

  def build_game(
    player_ships:,
    enemy_ships:,
    turn_strategy: SingleShotTurnStrategy.new,
    ai:,
    first_turn: :player
  )
    Game.new(
      player_board: board_with_ships(player_ships),
      enemy_board: board_with_ships(enemy_ships),
      turn_strategy: turn_strategy,
      ai: ai,
      first_turn: first_turn
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
