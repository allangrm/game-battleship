# frozen_string_literal: true

require_relative "test_helper"

class ModelSupportTest < Minitest::Test
  def test_map_config_creates_all_maps
    expected = {
      poca: [5, [2, 3, 4]],
      lago: [8, [2, 3, 3, 4, 5]],
      oceano: [10, [2, 2, 3, 3, 4, 4, 5]]
    }

    expected.each do |map_type, (size, fleet_sizes)|
      config = MapConfig.new(map_type)

      assert_equal size, config.create_board.size
      assert_equal fleet_sizes, config.create_fleet.map(&:size)
      assert_equal fleet_sizes.sort, config.expected_fleet_sizes
    end
  end

  def test_map_config_accepts_complete_boards
    MapConfig.available_maps.each_with_index do |map_type, index|
      config = MapConfig.new(map_type)
      board = config.create_board

      board.auto_place_ships(
        config.create_fleet,
        random: Random.new(index)
      )

      assert config.valid_board?(board)
      assert config.validate_board!(board)
    end
  end

  def test_map_config_rejects_an_incomplete_fleet
    config = MapConfig.new(:poca)
    board = config.create_board
    ship = config.create_fleet.first

    board.place_ship(ship, [[0, 0], [0, 1]])

    refute config.valid_board?(board)
    assert_raises(ArgumentError) { config.validate_board!(board) }
  end

  def test_map_config_rejects_a_board_with_the_wrong_size
    config = MapConfig.new(:poca)
    board = Board.new(8)

    board.auto_place_ships(
      config.create_fleet,
      random: Random.new(10)
    )

    refute config.valid_board?(board)
  end

  def test_map_config_rejects_a_fleet_with_the_wrong_sizes
    config = MapConfig.new(:poca)
    board = config.create_board
    wrong_fleet = Array.new(3) { |index| Ship.new("Barco #{index + 1}", 2) }

    board.auto_place_ships(wrong_fleet, random: Random.new(20))

    refute config.valid_board?(board)
  end

  def test_map_config_rejects_invalid_objects
    config = MapConfig.new(:poca)

    refute config.valid_board?(nil)
    refute config.valid_board?(Object.new)
  end

  def test_player_normalizes_and_validates_name
    player = Player.new("  Allan  ")

    assert_equal "Allan", player.name
    assert_equal 0, player.score
    assert_raises(ArgumentError) { Player.new("   ") }
  end
end
