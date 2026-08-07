# Representa o tabuleiro.
#
# @author Allan Guilherme
# @version 1.0
# @since 06-08-2026

class Board
  attr_reader :size, :grid, :ships

  def initialize(size)
    @size = size
    @grid = Array.new(size) { |row| Array.new(size) { |col| Cell.new(row, col) }}
    @ships = []
  end

  #verifica se a coordenada está dentro dos limites do tabuleiro
  def valid_coordinate?(row, col)
    row.between?(0, size - 1) && col.between?(0, size - 1)
  end

  # retorna a célula na posição inserida (row, col)
  # ou nil se fora dos limites
  def cell_at(row, col)
    return nil unless valid_coordinate?(row, col)
    grid[row][col]
  end

  # posiciona um navio nas coordenadas fornecidas
  # @param ship [Ship] o navio a ser posicionado
  # @param coordinates [Array<Array(Integer, Integer)>] lista de celulas[row, col]
  # @raise [ArgumentError] se a posição for inválida ou ja houver um navio
  def place_ship(ship, coordinates)
    raise ArgumentError, "Posição inválida para o navio" unless valid_placement?(ship, coordinates)

    #aloca as coordenadas especificamente em |linha, coluna|
    cells = coordinates.map { |(row, col)| cell_at(row, col) }

    raise ArgumentError, "Já existe um navio em uma dessas células" if cells.any?(&:occupied?)

    ship.place(cells)
    ships << ship
  end

  # valida se as coordenadas formam um posicionamento válido para o navio
  # @param ship [Ship] navio a posicionar
  # @param coordinates [Array<Array(Integer, Integer)>] coordenadas
  # @return [Boolean]
  def valid_placement?(ship, coordinates)
    #quantidade de coordenadas deve ser igual ao tamanho do navio
    return false unless coordinates.length == ship.size

    #todas as coordenadas devem estar dentro do tabuleiro
    return false unless coordinates.all? { |(row, col)| valid_coordinate?(row, col) }

    #nenhuma célula das candidatas pode estar ocupada
    return false if coordinates.any? { |(row, col)| cell_at(row, col).occupied? }

    #coordenadas devem formar uma linha reta (horizontal ou vertical)
    rows = coordinates.map(&:first) #extrai apenas o primeiro elemento do par [x,y]
    cols = coordinates.map(&:last)  # " o ultimo elemento (apenas colunas)

    horizontal = rows.uniq.length == 1 # mesma linha (verifica se todas as instancias em rows sao iguais,
    # se sim diminui o tamanho; [2, 2, 2] .uniq transforma so em [2])
    vertical   = cols.uniq.length == 1 # mesma coluna (mesma coisa)

    return false unless horizontal || vertical

    # coordenadas devem ser consecutivas (sem espacos brancos)
    # .each_cons() metodo que agrupa os elementos do array em blocos de 2
    # [4, 5, 6] vira [4, 5]: a = 4, b =5; [5, 6]: a = 5, b=6
    # e para cada um desses pares sera verificado se a subtração de a em b
    # resulta em 1, se resultar as casas sao consecutivas
    if horizontal
      sorted = cols.sort
      sorted.each_cons(2).all? { |a, b| b - a == 1 }
    else
      sorted = rows.sort
      sorted.each_cons(2).all? { |a, b| b - a == 1 }
    end
  end

  # verifica se todos os navios foram afundados
  def all_ships_sunk?
    ships.all?(&:sunk?)
  end

  # conta quantos navios ainda estao vivos
  def ships_remaining
    ships.reject(&:sunk?).length
  end


  #todo def auto_place_ships


end