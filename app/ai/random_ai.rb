# frozen_string_literal: true

require_relative "../weapons/basic_shot"

# Oponente simples que escolhe aleatoriamente uma célula ainda não atacada.
# O Board permanece como fonte de verdade do histórico de coordenadas.
# 
# @author Júlio Pedro
# @version 1.1
class RandomAI
  class NoAvailableCoordinateError < StandardError; end

  Decision = Struct.new(:row, :col, :weapon, :options, keyword_init: true)

  def initialize(random: Random.new)
    @random = random
  end

  def choose_attack(board)
    available_cells = board.grid.flatten.reject(&:attacked?)
    raise NoAvailableCoordinateError, "Não existem coordenadas disponíveis" if available_cells.empty?

    cell = available_cells.sample(random: @random)
    Decision.new(
      row: cell.row,
      col: cell.col,
      weapon: BasicShot.new,
      options: {}
    ).freeze
  end
end
