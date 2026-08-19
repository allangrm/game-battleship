# frozen_string_literal: true

require_relative "../models/board"

class InvalidAttackError < StandardError; end

# Orquestra um ataque: valida a coordenada escolhida, solicita à arma sua área
# e delega ao Board a alteração de cada célula. Não contém regra de dano.
#
# @author Júlio Pedro
# @version 1.1
class AttackHandler
  AttackResult = Struct.new(:cell, :status) do
    def hit?
      %i[hit sunk].include?(status)
    end

    # Compatibilidade com o contrato anterior, que expunha `hit` como booleano.
    alias hit hit?
  end

  def initialize(board)
    @board = board
  end

  # Retorna apenas resultados de células que mudaram de estado. Em armas de
  # área, células já atacadas são ignoradas para impedir contagem duplicada.
  def attack(row, col, weapon, **opts)
    validate!(row, col)

    weapon.target_cells(row, col, @board, **opts).filter_map do |target_row, target_col|
      resolve_attack(target_row, target_col)
    end
  end

  private

  def validate!(row, col)
    unless @board.valid_coordinate?(row, col)
      raise InvalidAttackError, "Coordenada fora do tabuleiro: (#{row}, #{col})"
    end

    return unless @board.cell_at(row, col).attacked?

    raise InvalidAttackError, "Coordenada (#{row}, #{col}) já foi atacada"
  end

  def resolve_attack(row, col)
    status = @board.receive_attack(row, col)
    return nil if %i[invalid already_attacked].include?(status)

    AttackResult.new(@board.cell_at(row, col), status)
  end
end
