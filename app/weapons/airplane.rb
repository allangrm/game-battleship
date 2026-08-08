# frozen_string_literal: true
#
# @author Júlio Pedro
# @version 1.0
# @since 07-08-2026

require_relative "weapon"

# Avião, atira em uma row ou col inteira
class Airplane < weapon
  def target_cells(row, col, board, orientation: :row, **_opts)
    candidates =
      case orientation
      when :row
        (0...board.size).map { |c| [row, c] }
      when :col
        (0...board.size).map { |r| [r, col] }
      else
        raise ArgumentError, "orientation inválida: #{orientation}"
      end
 
    valid_cells(candidates, board)
  end
end