# frozen_string_literal: true

require_relative "weapon"

# Arma especial que atinge uma linha ou coluna inteira do tabuleiro.
#
# A orientação faz parte da intenção do ataque e é transportada por
# RandomAI::Decision ou pelas opções informadas pela interface. A classe não
# verifica carga nem altera o tabuleiro; ela somente devolve a área escolhida.
#
# @author Júlio Pedro
# @version 1.1
class Airplane < Weapon
  # @param row [Integer] linha usada quando orientation é :row
  # @param col [Integer] coluna usada quando orientation é :col
  # @param board [Board] fornece o tamanho da linha/coluna
  # @param orientation [Symbol] :row ou :col; :row por padrão
  # @return [Array<Array(Integer, Integer)>] linha ou coluna completa
  # @raise [ArgumentError] se a orientação não for reconhecida
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
