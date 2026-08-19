# frozen_string_literal: true

require_relative "weapon"

# Ataque básico em uma única célula (RF06).
#
# @author Júlio Pedro
# @version 1.1
class BasicShot < Weapon
  def target_cells(row, col, board, **_opts)
    valid_cells([[row, col]], board)
  end
end

