# frozen_string_literal: true

require_relative "../models/map_config"
require_relative "../turn_strategies/factory"
require_relative "../game"
require_relative "game_controller"

# Coordena a preparação da partida. Mantém a criação de tabuleiros, frotas,
# estratégia e Game fora da MainWindow e expõe uma API simples para a SetupView.
#
# @author Lívia Ferreira
# @version 1.0
class SetupController
  TURN_MODES = TurnStrategyFactory::STRATEGIES.keys.freeze

  attr_reader :map_config, :player_board, :fleet, :turn_mode

  def initialize(window, map_type:)
    @window = window
    @map_config = MapConfig.new(map_type)
    @turn_mode = :single_shot
    reset_placement
  end

  def select_turn_mode(mode)
    normalized_mode = mode.to_s.strip.to_sym
    TurnStrategyFactory.build(normalized_mode)
    @turn_mode = normalized_mode
  end

  def next_ship
    fleet.find { |ship| !ship.placed? }
  end

  def placement_complete?
    next_ship.nil?
  end

  def place_next_ship(row, col, orientation:)
    ship = next_ship
    raise ArgumentError, "Todos os navios já foram posicionados" unless ship

    coordinates = player_board.generate_coordinates(row, col, ship.size, orientation)
    raise ArgumentError, "O navio não cabe nessa posição" unless coordinates

    player_board.place_ship(ship, coordinates)
  end

  def auto_place
    reset_placement
    player_board.auto_place_ships(fleet)
    player_board
  end

  def reset_placement
    @player_board = map_config.create_board
    @fleet = map_config.create_fleet
    player_board
  end

  def start_game
    raise ArgumentError, "Posicione todos os navios antes de iniciar" unless placement_complete?

    enemy_board = map_config.create_board
    enemy_board.auto_place_ships(map_config.create_fleet)

    game = Game.new(
      player_board: player_board,
      enemy_board: enemy_board,
      map_type: map_config.map_type,
      turn_strategy: TurnStrategyFactory.build(turn_mode)
    )

    game_controller = GameController.new(game)
    @window.navigate_to(
      :game,
      game_controller: game_controller,
      map_type: map_config.map_type,
      map_name: map_config.name
    )
    game_controller
  end
end
