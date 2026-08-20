# frozen_string_literal: true

# Contrato comum para todas as armas. Cada arma calcula as coordenadas-alvo;
# a alteração do estado pertence ao Board.
#
# @author Júlio Pedro
# @version 1.1
class Weapon
  # Identificador estável usado nos eventos enviados à interface.
  def identifier
    self.class.name
        .split("::")
        .last
        .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
        .downcase
        .to_sym
  end

  def target_cells(row, col, board, **_opts)
    raise NotImplementedError, "#{self.class} precisa implementar #target_cells"
  end

  private

  def valid_cells(coordinates, board)
    coordinates.select { |target_row, target_col| board.valid_coordinate?(target_row, target_col) }
  end
end
