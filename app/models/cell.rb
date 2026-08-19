# frozen_string_literal: true

# Representa uma casa/célula do tabuleiro.
#
# @author Allan Guilherme
# @version 1.1
class Cell
  attr_reader :row, :col
  attr_accessor :ship, :status

  def initialize(row, col)
    @row = row
    @col = col
    @ship = nil
    @status = :unknown
  end

  def occupied?
    !ship.nil?
  end

  def attacked?
    status != :unknown
  end
end
