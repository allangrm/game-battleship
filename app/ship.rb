# Representa um barco posicionado no tabuleiro.
#
# @author Allan Guilherme
# @version 1.0
# @since 19-07-2026

class Ship

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

  def register_hit
    @hits += 1
  end

  def sunk?
    @hits >= size
  end

  def remaining_cells
    size - @hits
  end

end
