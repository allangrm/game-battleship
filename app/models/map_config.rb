# frozen_string_literal: true

require_relative "board"
require_relative "ship"

# Configurações dos mapas disponíveis no jogo.
# Define os modos Poça, Lago e Oceano e suas frotas.
#
# Centralizar esses dados impede que controllers e views mantenham tamanhos ou
# frotas divergentes. Cada fábrica abaixo devolve objetos novos e independentes
# para o jogador e para o computador.
#
# @author Allan Guilherme
# @version 1.1
class MapConfig
  # Fonte única dos nomes, dimensões e embarcações de cada mapa.
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

  # Seleciona uma configuração pelo identificador simbólico do mapa.
  #
  # @param map_type [Symbol] :poca, :lago ou :oceano
  # @raise [ArgumentError] quando o identificador não existe
  def initialize(map_type)
    config = MAPS[map_type]
    raise ArgumentError, "Mapa inválido: #{map_type}. Use :poca, :lago ou :oceano" unless config

    @map_type = map_type
    @name = config[:name]
    @board_size = config[:size]
    @fleet_config = config[:ships]
  end

  # Constrói uma frota nova a partir da configuração imutável do mapa.
  #
  # Cada chamada cria instâncias diferentes de Ship; assim tabuleiros aliados e
  # inimigos nunca compartilham estado de posicionamento ou dano.
  #
  # @return [Array<Ship>]
  def create_fleet
    fleet_config.map { |ship| Ship.new(ship[:name], ship[:size]) }
  end

  # Produz a assinatura da frota esperada, independente da ordem dos navios.
  #
  # @return [Array<Integer>] tamanhos ordenados e congelados
  def expected_fleet_sizes
    fleet_config.map { |ship| ship[:size] }.sort.freeze
  end

  # Verifica se um tabuleiro representa integralmente este mapa.
  #
  # A comparação da frota usa os tamanhos porque eles determinam o comportamento
  # atual das embarcações. Todos os navios também precisam estar posicionados.
  #
  # @param board [Object] candidato a tabuleiro do mapa
  # @return [Boolean]
  def valid_board?(board)
    board.is_a?(Board) &&
      board.size == board_size &&
      board.ships.all?(&:placed?) &&
      board.ships.map(&:size).sort == expected_fleet_sizes
  end

  # Versão estrita de #valid_board?, usada na fronteira de criação de Game.
  #
  # @param board [Object]
  # @return [true]
  # @raise [ArgumentError] quando tamanho, frota ou posicionamento não conferem
  def validate_board!(board)
    return true if valid_board?(board)

    raise ArgumentError, "Tabuleiro incompatível com o mapa #{name}"
  end

  # @return [Board] tabuleiro vazio com a dimensão correspondente ao mapa
  def create_board
    Board.new(board_size)
  end

  # @return [Array<Symbol>] identificadores suportados
  def self.available_maps
    MAPS.keys
  end

  # Resume a configuração para logs, inspeção e apresentação.
  #
  # @return [String]
  def to_s
    total_cells = fleet_config.sum { |ship| ship[:size] }
    "#{name} (#{board_size}x#{board_size}) — #{fleet_config.length} navios, #{total_cells} células ocupadas"
  end
end
