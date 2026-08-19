# frozen_string_literal: true

require_relative "weapon"

# Míssil que atinge um bloco 2x2. A coordenada escolhida representa o canto
# superior esquerdo; nas bordas, somente células válidas são atingidas.
#
# @author Júlio Pedro
# @version 1.1
class Missile < Weapon
  def target_cells(row, col, board, **_opts)
    candidates = [
      [row, col],
      [row + 1, col],
      [row, col + 1],
      [row + 1, col + 1]
    ]

    valid_cells(candidates, board)
  end
end
