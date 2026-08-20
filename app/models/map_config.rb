# frozen_string_literal: true

require_relative "board"
require_relative "ship"

# Configurações dos mapas disponíveis no jogo.
# Define os modos Poça, Lago e Oceano e suas frotas.
#
# @author Allan Guilherme
# @version 1.1
class MapConfig
  MAPS = {
    poca: {
      name: "Poça",
      size: 5,
      ships: [
        { name: "Barco", size: 2 },
        { name: "Fragata", size: 3 },
        { name: "Corveta", size: 4 }
      ]
    },
    lago: {
      name: "Lago",
      size: 8,
      ships: [
        { name: "Barco", size: 2 },
        { name: "Fragata", size: 3 },
        { name: "Fragata", size: 3 },
        { name: "Corveta", size: 4 },
        { name: "Submarino", size: 5 }
      ]
    },
    oceano: {
      name: "Oceano",
      size: 10,
      ships: [
        { name: "Barco", size: 2 },
        { name: "Barco", size: 2 },
        { name: "Fragata", size: 3 },
        { name: "Fragata", size: 3 },
        { name: "Corveta", size: 4 },
        { name: "Corveta", size: 4 },
        { name: "Submarino", size: 5 }
      ]
    }
  }.freeze

  attr_reader :map_type, :name, :board_size, :fleet_config

  def initialize(map_type)
    config = MAPS[map_type]
    raise ArgumentError, "Mapa inválido: #{map_type}. Use :poca, :lago ou :oceano" unless config

    @map_type = map_type
    @name = config[:name]
    @board_size = config[:size]
    @fleet_config = config[:ships]
  end

  def create_fleet
    fleet_config.map { |ship| Ship.new(ship[:name], ship[:size]) }
  end

  def expected_fleet_sizes
    fleet_config.map { |ship| ship[:size] }.sort.freeze
  end

  def valid_board?(board)
    board.is_a?(Board) &&
      board.size == board_size &&
      board.ships.all?(&:placed?) &&
      board.ships.map(&:size).sort == expected_fleet_sizes
  end

  def validate_board!(board)
    return true if valid_board?(board)

    raise ArgumentError, "Tabuleiro incompatível com o mapa #{name}"
  end

  def create_board
    Board.new(board_size)
  end

  def self.available_maps
    MAPS.keys
  end

  def to_s
    total_cells = fleet_config.sum { |ship| ship[:size] }
    "#{name} (#{board_size}x#{board_size}) — #{fleet_config.length} navios, #{total_cells} células ocupadas"
  end
end
