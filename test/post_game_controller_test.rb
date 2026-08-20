# frozen_string_literal: true

require "minitest/autorun"
require_relative "../app/models/map_config"
require_relative "../app/controllers/post_game_controller"

class PostGameControllerTest < Minitest::Test
  class FakeWindow
    attr_reader :destination, :options

    def navigate_to(destination, **options)
      @destination = destination
      @options = options
    end
  end

  def setup
    @window = FakeWindow.new
    @controller = PostGameController.new(@window)
  end

  def test_victory_requests_winner_name_and_then_delivers_player_to_game_over
    game = finished_game(:victory)

    @controller.handle_game_over(game)

    assert_equal :name, @window.destination
    assert_same game, @window.options[:game]

    player = @window.options[:on_submit].call("Lívia")

    assert_equal :game_over, @window.destination
    assert_same game, @window.options[:game]
    assert_same player, @window.options[:player]
    assert_equal "Lívia", player.name
  end

  def test_defeat_goes_directly_to_game_over_without_player
    game = finished_game(:defeat)

    @controller.handle_game_over(game)

    assert_equal :game_over, @window.destination
    assert_same game, @window.options[:game]
    assert_nil @window.options[:player]
  end

  def test_rejects_a_game_that_is_still_running
    map = MapConfig.new(:poca)
    player_board = map.create_board
    enemy_board = map.create_board
    player_board.auto_place_ships(map.create_fleet)
    enemy_board.auto_place_ships(map.create_fleet)
    game = Game.new(player_board: player_board, enemy_board: enemy_board, map_type: :poca)

    assert_raises(ArgumentError) { @controller.handle_game_over(game) }
  end

  private

  def finished_game(result)
    map = MapConfig.new(:poca)
    player_board = map.create_board
    enemy_board = map.create_board
    player_board.auto_place_ships(map.create_fleet)
    enemy_board.auto_place_ships(map.create_fleet)
    game = Game.new(player_board: player_board, enemy_board: enemy_board, map_type: :poca)

    target_board = result == :victory ? enemy_board : player_board
    target_board.ships.each do |ship|
      ship.cells.each { |cell| target_board.receive_attack(cell.row, cell.col) }
    end
    game.instance_variable_set(:@state, result)
    game.instance_variable_set(:@ended_at, game.started_at)
    game
  end
end
