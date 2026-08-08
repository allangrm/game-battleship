# frozen_string_literal: true

# @author Júlio Pedro
# @version 1.0
# @since 07-08-2026

class InvalidAttackError < StandardError; end

# Classe de controle, decide o que acontece quando o tabuleiro é atacado.
# valida a coordenada (RF07), pede à arma quais células
# ela mira (RF06/RF02), e resolve o efeito em cada uma (água,
# acerto ou afundamento). 
class AttackHandler
  # AttackResult: representa o resultado de um tiro numa célula.
  # cell: a Cell atingida
  # hit: true se acertou um navio
  AttackResult = Struct.new(:cell, :hit)

  def initialize(board)
    @board = board
  end

  # row, col: coordenada clicada
  # weapon: instância de BasicShot, Missile ou Airplane
  # **opts: repassado à arma (ex: orientation: :col, pro Airplane)
  # Retorna um Array<AttackResult> — só com células que de fato mudaram de estado nesse ataque (ver resolve_attack).
  def attack(row, col, weapon, **opts)
    validate!(row, col)

    cells = weapon.target_cells(row, col, @board, **opts)
    cells.map{|(r, c)| resolve_attack(r, c) }.compact
  end

  private

  def validate!(row, col)
    unless @board.valid_coordinate?(row, col)
      raise InvalidAttackError, "Coordenada fora do tabuleiro: (#{row}, #{col})"
    end
    cell = @board.cell_at(row, col)
    if cell.attacked?
      raise InvalidAttackError, "Coordenada (#{row}, #{col}) já foi atacada"
    end
  end

  # Aplica o efeito do tiro na célula
  def resolve_attack(row, col)
    cell = @board.cell_at(row, col)
    return nil unless cell
    return nil if cell.attaceked?

    if cell.occupied?
      cell.ship.register_hit
      cell.status = cell.ship.sunk? ? :sunk : :hit
      AttackResult.new(cell, true)
    else
      cell.status=:miss
      AttackResult.new(cell, false)
    end
  end
end