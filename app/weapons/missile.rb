# frozen_string_literal: true

require_relative "weapon"

# Arma especial que atinge um bloco de até 2x2.
#
# A coordenada escolhida representa o canto superior esquerdo do bloco, conforme
# a decisão de regra do grupo. Nas bordas, a ativação continua válida, mas
# valid_cells recorta as coordenadas inexistentes; por isso ela pode atingir
# uma, duas ou quatro células dependendo da origem.
#
# O Míssil apenas retorna a área. AttackHandler decide como lidar com células
# repetidas e Board resolve acerto, água e afundamento.
#
# @author Júlio Pedro
# @version 1.1
class Missile < Weapon
  # @param row [Integer] linha do canto superior esquerdo
  # @param col [Integer] coluna do canto superior esquerdo
  # @param board [Board] tabuleiro usado para recortar a área
  # @return [Array<Array(Integer, Integer)>] coordenadas válidas do bloco 2x2
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
