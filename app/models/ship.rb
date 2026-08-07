# Representa um barco posicionado no tabuleiro.
#
# @author Allan Guilherme
# @version 1.0
# @since 19-07-2026

class Ship
  attr_reader :name, :size, :cells, :hits

  def initialize(name, size)
    @name = name
    @size = size
    @cells = []
    @hits = 0
  end

  # para cada celula percorrida, atribui a celula ao navio especifico
  def place(cells)
    @cells = cells
    cells.each { |cell| cell.ship = self }
  end

  # registra numeros de ataques sofrido pelo navio
  def register_hit
    @hits += 1
  end

  # verifica se o numero de hits é maior ou igual ao tamanho do navio
  # @return [Boolean]
  def sunk?
    @hits >= size
  end

  #contador de quantas celulas vivas restam no navio
  def remaining_cells
    size - @hits
  end
end
