# frozen_string_literal: true

require_relative "test_helper"

class GameServicesIntegrationTest < Minitest::Test
  def test_every_map_and_turn_mode_complete_and_can_be_persisted
    database = Database.new(path: ":memory:")
    strategies = [SingleShotTurnStrategy, ExtraShotOnHitTurnStrategy]

    MapConfig.available_maps.each_with_index do |map_type, map_index|
      strategies.each_with_index do |strategy_class, strategy_index|
        game = build_game(map_type, map_index, strategy_class, strategy_index)
        assert_equal map_type, game.map_type
        refute_same game.player_inventory, game.computer_inventory
        assert_equal game.player_inventory.to_h, game.computer_inventory.to_h
        play_until_finished(game)
        assert_unique_coordinates_per_actor(game)

        score = ScoreCalculator.calculate(**game.final_statistics)
        match_id = database.save_match(
          player_name: "Integração #{map_type} #{strategy_index}",
          map_type: map_type,
          result: game.result,
          score: score,
          duration_seconds: game.duration_seconds
        )

        assert game.finished?
        assert_operator match_id, :positive?
        assert_operator score, :>=, 0
      end

      assert_equal 2, database.top_scores(map_type).length
    end
  ensure
    database&.close
  end

  private

  def build_game(map_type, map_index, strategy_class, strategy_index)
    config = MapConfig.new(map_type)
    player_board = config.create_board
    enemy_board = config.create_board
    player_board.auto_place_ships(config.create_fleet, random: Random.new(100 + map_index))
    enemy_board.auto_place_ships(config.create_fleet, random: Random.new(200 + map_index))

    Game.new(
      player_board: player_board,
      enemy_board: enemy_board,
      map_type: map_type,
      turn_strategy: strategy_class.new,
      ai: RandomAI.new(random: Random.new(300 + strategy_index))
    )
  end

  def play_until_finished(game)
    controller = GameController.new(game)

    until game.finished?
      target = game.enemy_board.grid.flatten.find { |cell| !cell.attacked? }
      controller.handle_player_attack(target.row, target.col)
    end
  end

  def assert_unique_coordinates_per_actor(game)
    game.history.group_by(&:actor).each_value do |events|
      coordinates = events.flat_map do |event|
        event.cells.map { |cell| [cell.row, cell.col] }
      end

      assert_equal coordinates.length, coordinates.uniq.length
    end
  end
end
