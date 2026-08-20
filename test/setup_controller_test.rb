# frozen_string_literal: true

require "minitest/autorun"
require_relative "../app/controllers/setup_controller"

class SetupControllerTest < Minitest::Test
  class FakeWindow
    attr_reader :destination, :options

    def navigate_to(destination, **options)
      @destination = destination
      @options = options
    end
  end

  def setup
    @window = FakeWindow.new
    @controller = SetupController.new(@window, map_type: :poca)
  end

  def test_places_fleet_manually_and_builds_selected_game
    @controller.place_next_ship(0, 0, orientation: :horizontal)
    @controller.place_next_ship(1, 0, orientation: :horizontal)
    @controller.place_next_ship(2, 0, orientation: :horizontal)
    @controller.select_turn_mode(:extra_shot_on_hit)

    game_controller = @controller.start_game
    game = game_controller.game

    assert_equal :game, @window.destination
    assert_equal :poca, @window.options[:map_type]
    assert_equal "Poça", @window.options[:map_name]
    assert_instance_of ExtraShotOnHitTurnStrategy, game.turn_strategy
    assert_instance_of RandomAI, game.ai
    assert_same @controller.player_board, game.player_board
    refute_same game.player_board, game.enemy_board
  end

  def test_auto_place_replaces_partial_placement_with_complete_fleet
    old_board = @controller.player_board
    @controller.place_next_ship(0, 0, orientation: :horizontal)

    @controller.auto_place

    refute_same old_board, @controller.player_board
    assert @controller.placement_complete?
    assert_equal @controller.map_config.fleet_config.length, @controller.player_board.ships.length
  end

  def test_rejects_start_before_all_ships_are_placed
    error = assert_raises(ArgumentError) { @controller.start_game }

    assert_match(/Posicione todos/, error.message)
    assert_nil @window.destination
  end

  def test_rejects_invalid_turn_mode
    assert_raises(ArgumentError) { @controller.select_turn_mode(:invalid) }
  end
end
