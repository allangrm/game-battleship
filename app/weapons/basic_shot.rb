# frozen_string_literal: true
#
# @author Júlio Pedro
# @version 1.0
# @since 07-08-2026
require_relative "weapon"

# Ataque básico, atira em uma única célula. (RF06)
class basic_shot < weapon
  def target_cells(row, col, board, **_opts)
    valid_cells([[row, col]], board)
  end
end

