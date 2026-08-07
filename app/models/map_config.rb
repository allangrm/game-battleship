# Configurações dos mapas disponíveis no jogo.
# Define os 3 modos de mapa: Poça, Lago e Oceano.
# Cada mapa possui um tamanho de tabuleiro e uma frota específica.
#
# @author Allan Guilherme
# @version 1.0
# @since 06-08-2026

class MapConfig
  #definição dos mapas com tamanho e composição da frota
  MAPS = {
    poca: {
      name: "Poça",
      size: 5,
      ships: [
        { name: "Barco",    size: 2 },
        { name: "Fragata",  size: 3 },
        { name: "Corveta",  size: 4 },
      ]
    },
    lago: {
      name: "Lago",
      size: 8,
      ships: [
        { name: "Barco",         size: 2 },
        { name: "Fragata",       size: 3 },
        { name: "Fragata",       size: 3 },
        { name: "Corveta",       size: 4 },
        { name: "Submarino",     size: 5 }
      ]
    },
    oceano: {
      name: "Oceano",
      size: 10,
      ships: [
        { name: "Barco",        size: 2 },
        { name: "Barco",        size: 2 },
        { name: "Fragata",      size: 3 },
        { name: "Fragata",      size: 3 },
        { name: "Corveta",      size: 4 },
        { name: "Corveta",      size: 4 },
        { name: "Submarino",    size: 5 }
      ]
    }
  }.freeze

  attr_reader :map_type, :name, :board_size, :fleet_config

  # @param map_type [selecionado] :poca, :lago, ou :oceano
  # @raise [ArgumentError] se o tipo de mapa for inválido
  def initialize(map_type)
    config = MAPS[map_type]
    raise ArgumentError, "Mapa inválido: #{map_type}. Use :poca, :lago ou :oceano" unless config

    @map_type     = map_type
    @name         = config[:name]
    @board_size   = config[:size]
    @fleet_config = config[:ships]
  end

  # cria os objetos Ship (frota) a partir da configuração do mapa
  # @return [Array<Ship>] lista de navios prontos para posicionar
  def create_fleet
    fleet_config.map { |s| Ship.new(s[:name], s[:size]) }
  end

  # cria um tabuleiro com o tamanho definido pelo mapa
  # @return [Board] o tabuleiro novo
  def create_board
    Board.new(board_size)
  end

  # lista todos os mapas disponíveis
  # @return [Array<Symbol>] [:poca, :lago, :oceano]
  def self.available_maps
    MAPS.keys
  end

  # eetorna informações resumidas do mapa para exibição
  # (reescrita do 'to String')
  # passa por cada navio s da frota, pega o valor do seu tamanho
  # (:size) e soma tudo. o resultado vai pra variável total_cells,
  # indicando quantas casas do mapa estão ocupadas por navios
  # @return [String]
  def to_s
    total_cells = fleet_config.sum { |s| s[:size] }
    "#{name} (#{board_size}x#{board_size}) — #{fleet_config.length} navios, #{total_cells} células ocupadas"
  end
end
