# frozen_string_literal: true

require_relative "test_helper"

class GameControllerTest < Minitest::Test
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

  def test_resolves_one_computer_action_in_single_shot_mode
    game = build_game(
      ai: SequenceAI.new([4, 4])
    )

    events = GameController.new(game).handle_player_attack(4, 4)

    assert_equal %i[player computer], events.map(&:actor)
    assert_equal %i[miss miss], events.map { |event| event.cells.first.status }
    assert_equal :player, game.current_turn
    assert events.frozen?
  end

  def test_computer_keeps_playing_after_hits_in_sequential_mode
    player_board = configured_board
    attack_all_ship_cells_except(player_board, [0, 0], [0, 1])
    game = build_game(
      player_board: player_board,
      turn_strategy: ExtraShotOnHitTurnStrategy.new,
      ai: SequenceAI.new([0, 0], [0, 1])
    )

    events = GameController.new(game).handle_player_attack(4, 4)

    assert_equal %i[player computer computer], events.map(&:actor)
    assert_equal %i[miss hit sunk], events.map { |event| event.cells.first.status }
    assert game.defeat?
    assert_equal :computer, events.last.winner
  end

  def test_does_not_run_computer_while_player_keeps_the_turn
    game = build_game(
      turn_strategy: ExtraShotOnHitTurnStrategy.new,
      ai: SequenceAI.new([4, 4])
    )

    events = GameController.new(game).attack(0, 0)

    assert_equal [:player], events.map(&:actor)
    assert events.first.extra_turn
    assert_equal :player, game.current_turn
  end

  def test_can_resolve_a_computer_first_turn
    game = build_game(
      ai: SequenceAI.new([4, 4]),
      first_turn: :computer
    )

    events = GameController.new(game).resolve_computer_turn

    assert_equal [:computer], events.map(&:actor)
    assert_equal :player, game.current_turn
  end

  def test_forwards_airplane_orientation_and_returns_stable_weapon_identifier
    enemy_board = configured_board(
      placements: [
        [[0, 1], [1, 1]],
        [[3, 0], [3, 1], [3, 2]],
        [[4, 0], [4, 1], [4, 2], [4, 3]]
      ]
    )
    attack_all_ship_cells_except(enemy_board, [0, 1], [1, 1])
    game = build_game(
      enemy_board: enemy_board,
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
    player_board: nil,
    enemy_board: nil,
    turn_strategy: SingleShotTurnStrategy.new,
    ai:,
    first_turn: :player
  )
    Game.new(
      player_board: player_board || configured_board,
      enemy_board: enemy_board || configured_board,
      map_type: :poca,
      turn_strategy: turn_strategy,
      ai: ai,
      first_turn: first_turn
    )
  end
end
