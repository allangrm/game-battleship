# frozen_string_literal: true

require_relative "hunt_target_ai"

# Estratégia de IA difícil usada no mapa Oceano.
#
# Além do Hunt/Target herdado, ela reconhece sequências consecutivas de acertos,
# tenta prolongá-las pelas extremidades e usa busca quadriculada para descobrir
# navios com menos tiros. Como o menor navio possui duas células, todo navio
# horizontal ou vertical cruza ao menos uma casa de cada paridade.
#
# A política de especiais também é proativa: depois das prioridades baseadas em
# hits visíveis, ela escolhe a linha/coluna ou bloco com maior quantidade de
# células ainda não atacadas. Empates são resolvidos pela fonte Random injetada.
# Nenhuma decisão consulta ocupação ou navios escondidos.
#
# @author Júlio Pedro
# @version 1.1
class StrategicAI < HuntTargetAI
  # Seleciona a primeira decisão possível segundo a prioridade difícil.
  #
  # A cadeia de fallback é: Airplane em hits alinhados, Missile próximo de hit,
  # Airplane em hit isolado, melhor linha/coluna, melhor bloco 2x2, extensão de
  # sequência, Hunt/Target, quadriculado e aleatório.
  #
  # @param board [Board] tabuleiro-alvo observado por informações visíveis
  # @param inventory [WeaponInventory, nil] cargas pertencentes ao computador
  # @return [RandomAI::Decision]
  # @raise [RandomAI::NoAvailableCoordinateError] se não houver origem livre
  def choose_attack(board, inventory: nil)
    cells = available_cells(board)
    ensure_available_coordinate!(cells)

    special_decision = airplane_decision_for_aligned_hits(board, inventory) ||
                       missile_decision_near_visible_hit(board, inventory) ||
                       airplane_decision_for_visible_hit(board, inventory) ||
                       best_airplane_decision(board, inventory) ||
                       best_missile_decision(board, inventory)
    return special_decision if special_decision

    target = random_cell(aligned_extension_candidates(board)) ||
             random_cell(hunt_candidates(board)) ||
             random_cell(checkerboard_candidates(cells)) ||
             random_cell(cells)

    decision_for(target)
  end

  private

  # Localiza células livres imediatamente antes/depois de sequências alinhadas.
  #
  # @param board [Board]
  # @return [Array<Cell>] extensões válidas e ainda não atacadas
  # @api private
  def aligned_extension_candidates(board)
    hits = unresolved_hits(board)
    coordinates = horizontal_extensions(hits) + vertical_extensions(hits)

    coordinates.filter_map do |row, col|
      next unless board.valid_coordinate?(row, col)

      candidate = board.cell_at(row, col)
      candidate unless candidate.attacked?
    end.uniq
  end

  # @return [Array<Array(Integer, Integer)>] extremos de sequências horizontais
  # @api private
  def horizontal_extensions(hits)
    hits.group_by(&:row).flat_map do |row, row_hits|
      consecutive_runs(row_hits.sort_by(&:col), &:col).flat_map do |run|
        next [] if run.length < 2

        [[row, run.first.col - 1], [row, run.last.col + 1]]
      end
    end
  end

  # @return [Array<Array(Integer, Integer)>] extremos de sequências verticais
  # @api private
  def vertical_extensions(hits)
    hits.group_by(&:col).flat_map do |col, col_hits|
      consecutive_runs(col_hits.sort_by(&:row), &:row).flat_map do |run|
        next [] if run.length < 2

        [[run.first.row - 1, col], [run.last.row + 1, col]]
      end
    end
  end

  # Separa uma lista ordenada de hits em sequências de coordenadas consecutivas.
  # O bloco informa qual eixo (linha ou coluna) deve ser comparado.
  #
  # @param cells [Array<Cell>] hits previamente ordenados
  # @yieldparam cell [Cell]
  # @yieldreturn [Integer] coordenada do eixo analisado
  # @return [Array<Array<Cell>>] sequências consecutivas
  # @api private
  def consecutive_runs(cells)
    cells.each_with_object([]) do |cell, runs|
      coordinate = yield(cell)
      previous_coordinate = runs.last && yield(runs.last.last)

      if previous_coordinate && coordinate == previous_coordinate + 1
        runs.last << cell
      else
        runs << [cell]
      end
    end
  end

  # Reduz o espaço inicial de busca usando casas de paridade par.
  #
  # @param cells [Array<Cell>] origens ainda disponíveis
  # @return [Array<Cell>] subconjunto do padrão quadriculado
  # @api private
  def checkerboard_candidates(cells)
    cells.select { |cell| (cell.row + cell.col).even? }
  end
end
