# frozen_string_literal: true

require "minitest/autorun"

require_relative "../app/models/board"
require_relative "../app/models/map_config"
require_relative "../app/models/player"
require_relative "../app/weapons/basic_shot"
require_relative "../app/weapons/missile"
require_relative "../app/weapons/airplane"
require_relative "../app/weapons/weapon_inventory"
require_relative "../app/controllers/attack_handler"
require_relative "../app/turn_strategies/turn_strategy"
require_relative "../app/turn_strategies/single_shot"
require_relative "../app/turn_strategies/extra_shot_on_hit"
require_relative "../app/turn_strategies/factory"
require_relative "../app/ai/random_ai"
require_relative "../app/ai/hunt_target_ai"
require_relative "../app/ai/strategic_ai"
require_relative "../app/ai/ai_factory"
require_relative "../app/game"
require_relative "../app/controllers/game_controller"
require_relative "../app/services/score_calculator"
require_relative "../app/services/database"

module MapBoardTestHelpers
  def configured_board(map_type = :poca, placements: nil)
    config = MapConfig.new(map_type)
    board = config.create_board
    fleet = config.create_fleet
    selected_placements = placements || default_fleet_placements(fleet)

    fleet.zip(selected_placements).each do |ship, coordinates|
      board.place_ship(ship, coordinates)
    end

    board
  end

  def attack_all_ship_cells_except(board, *exceptions)
    preserved = exceptions.map { |row, col| [row, col] }

    board.ships.each do |ship|
      ship.cells.each do |cell|
        next if preserved.include?([cell.row, cell.col])

        board.receive_attack(cell.row, cell.col)
      end
    end

    board
  end

  private

  def default_fleet_placements(fleet)
    fleet.each_with_index.map do |ship, row|
      (0...ship.size).map { |col| [row, col] }
    end
  end
end

Minitest::Test.include(MapBoardTestHelpers)
