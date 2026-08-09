# frozen_string_literal: true
#
# @author Júlio Pedro
# @version 1.0
# @since 07-08-2026
require_relative "weapon"

# Míssil, atira em um bloco 2x2. a coordenada clicada é o canto superior esquerdo do bloco.
class Missile < Weapon
  def target_cells(row, col, board, **_opts)
    candidates = [
      [row, col],
      [row + 1, col], 
      [row, col +  1],
      [row + 1, col + 1]
    ]
    valid_cells(candidates, board)
  end
end