# Representa uma casa do tabuleiro.
#
# @author Allan Guilherme
# @version 1.0
# @since 19-07-2026

class Cell
  def initialize(row, col )
    @row = row
    @col = col
    @ship = nil
    @status = :unknown
  end

  # no caso inicial nao esta ocupado por nenhum navio
  def occupied?
    !!@ship
  end

  def attacked?
    #@status vai mudar para algum outro estado
  end

  # estados possiveis:
  # :unknown  - nao foi atacado
  # :hit      - navio atacado
  # :sunk     - navio atacado e afundado
  # :miss     - água

  # reader: getter
  # accessor: getter e setter
  attr_reader :row, :col
  attr_accessor :ship, :status

end
