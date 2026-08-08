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

  # Posiciona navios automaticamente de forma aleatória
  # @param fleet [Array<Ship>] frota de navios a posicionar
  def auto_place_ships(fleet)
    fleet.each do |ship|
      placed = false

      until placed
        #escolhe uma orientação aletoria pro barco (vert ou horiz)
        orientarion = [:horizontal, :vertical].sample
        #escolhe a posição inicial aleatoria
        row = rand(size)
        col = rand(size)

        #gera coordenadas baseadas na orientacao
        coordinates = generate_coordinates(row, col, ship.size, orientarion)

        #tenta posicionar se a posição for válida
        if coordinates && valid_coordinate?(ship, coordinates)
          place_ship(ship, coordinates)
          placed = true
        end
      end
    end
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

  # Recebe um ataque na coordenada/celula (row, col)
  # @param row [Integer] linha do ataque
  # @param col [Integer] coluna do ataque
  # @return [Symbol] :hit, :miss, :sunk, :invalid ou :already_attacked
  def receive_attack(row, col)
    return :invalid unless valid_coordinate?(row, col)

    cell = cell_at(row, col)
    #verifica se ja foi atacado
    return :already_attacked if cell.attacked?

    #se a celula estiver ocupada pega o navio q aquela
    #celula pertence e define o status da celula como atacada
    if cell.occupied?
      ship = cell.ship
      cell.status = :hit
      ship.register_hit

      #verifica se o navio ja levou hit em todas as celulas dele
      if ship.sunk?
        ship.cells.each { |c| c.status = :sunk }
        :sunk
      else
        :hit
      end
    else
      cell.status = :miss
      :miss
    end
  end

  # gera coordenadas que um navio vai ocupar com base na posição inicial e orientação
  def generate_coordinates(row, col, length, orientation)
    coords = (0...length).map do |i| #range; map transforma cada i em par[r,c]
      if orientation == :horizontal
        [row, col + i]
      else
        [row + i, col]
      end
    end

    # retorna nil se alguma coordenada ficar fora do tabuleiro
    return nil unless coords.all? { |(r, c)| valid_coordinate?(r, c) }

    coords
  end

  # verifica se todos os navios foram afundados
  def all_ships_sunk?
    ships.all?(&:sunk?)
  end

  # conta quantos navios ainda estao vivos
  def ships_remaining
    ships.reject(&:sunk?).length
  end

end