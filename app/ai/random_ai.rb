# frozen_string_literal: true

require_relative "../weapons/basic_shot"

# Oponente simples que escolhe aleatoriamente uma célula ainda não atacada.
# O Board permanece como fonte de verdade do histórico de coordenadas.
# 
# @author Júlio Pedro
# @version 1.2
class RandomAI
  class NoAvailableCoordinateError < StandardError; end

  Decision = Struct.new(:row, :col, :weapon, :options, keyword_init: true)

  def initialize(random: Random.new)
    @random = random
  end

  def choose_attack(board, inventory: nil)
    cells = available_cells(board)
    ensure_available_coordinate!(cells)

    decision_for(random_cell(cells))
  end

  protected

  attr_reader :random

  def available_cells(board)
    board.grid.flatten.reject(&:attacked?)
  end

  def ensure_available_coordinate!(cells)
    return unless cells.empty?

    raise NoAvailableCoordinateError, "Não existem coordenadas disponíveis"
  end

  def random_cell(cells)
    cells.sample(random: random)
  end

  def decision_for(cell)
    Decision.new(
      row: cell.row,
      col: cell.col,
      weapon: BasicShot.new,
      options: {}
    ).freeze
  end
end
