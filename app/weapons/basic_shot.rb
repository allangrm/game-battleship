# frozen_string_literal: true

require_relative "weapon"

# Ataque básico em uma única célula, responsável por atender ao RF06.
#
# Não possui opções adicionais e é ilimitado no WeaponInventory. Mesmo sendo a
# arma mais simples, respeita o mesmo contrato polimórfico das armas especiais.
#
# @author Júlio Pedro
# @version 1.1
class BasicShot < Weapon
  # @param row [Integer] linha selecionada
  # @param col [Integer] coluna selecionada
  # @param board [Board] tabuleiro usado para validar os limites
  # @return [Array<Array(Integer, Integer)>] zero ou uma coordenada válida
  def target_cells(row, col, board, **_opts)
    valid_cells([[row, col]], board)
  end
end

