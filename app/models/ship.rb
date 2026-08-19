# frozen_string_literal: true

# Representa um navio posicionado no tabuleiro.
#
# @author Allan Guilherme
# @version 1.1
class Ship
  attr_reader :name, :size, :cells, :hits

  def initialize(name, size)
    raise ArgumentError, "O tamanho do navio deve ser positivo" unless size.is_a?(Integer) && size.positive?

    @name = name
    @size = size
    @cells = []
    @hits = 0
  end

  def place(cells)
    raise ArgumentError, "Quantidade de células diferente do tamanho do navio" unless cells.length == size
    raise ArgumentError, "Navio já está posicionado" if placed?

    @cells = cells
    cells.each { |cell| cell.ship = self }
    self
  end

  def register_hit
    @hits += 1 unless sunk?
  end

  def sunk?
    hits >= size
  end

  def remaining_cells
    [size - hits, 0].max
  end

  def placed?
    !cells.empty?
  end

  # Desfaz o posicionamento durante o setup. É usado pelo rollback do
  # posicionamento automático quando a frota completa não cabe no tabuleiro.
  def unplace
    cells.each { |cell| cell.ship = nil if cell.ship.equal?(self) }
    @cells = []
    @hits = 0
    self
  end
end
