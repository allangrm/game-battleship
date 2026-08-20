# frozen_string_literal: true

require_relative "weapon"

# Torpedo direcional que atinge até três células consecutivas a partir da
# coordenada escolhida. Células que ultrapassam a borda são descartadas.
# 
# @author Júlio Pedro
# @version 1.1
class Torpedo < Weapon
  DIRECTIONS = {
    up: [-1, 0],
    down: [1, 0],
    left: [0, -1],
    right: [0, 1]
  }.freeze

  RANGE = 3

  def target_cells(row, col, board, direction: :right, **_opts)
    row_step, col_step = DIRECTIONS.fetch(direction) do
      raise ArgumentError, "Direção inválida: #{direction.inspect}"
    end

    candidates = (0...RANGE).map do |offset|
      [row + (row_step * offset), col + (col_step * offset)]
    end

    valid_cells(candidates, board)
  end
end
