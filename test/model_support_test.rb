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
    end
  end

  def test_player_normalizes_and_validates_name
    player = Player.new("  Allan  ")

    assert_equal "Allan", player.name
    assert_equal 0, player.score
    assert_raises(ArgumentError) { Player.new("   ") }
  end
end
