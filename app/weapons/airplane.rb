# frozen_string_literal: true

require_relative "weapon"

# Avião que atinge uma linha ou coluna inteira.
#
# @author Júlio Pedro
# @version 1.1
class Airplane < Weapon
  def target_cells(row, col, board, orientation: :row, **_opts)
    candidates = case orientation
                 when :row
                   (0...board.size).map { |target_col| [row, target_col] }
                 when :col
                   (0...board.size).map { |target_row| [target_row, col] }
                 else
                   raise ArgumentError, "Orientação inválida: #{orientation}"
                 end

    valid_cells(candidates, board)
  end
end
