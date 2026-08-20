# frozen_string_literal: true

require_relative "hunt_target_ai"

# IA avançada que prolonga sequências de acertos alinhados, investiga acertos
# isolados e usa um padrão quadriculado durante a busca por novas embarcações.
# Não consulta navios ou células ocupadas ainda ocultas do jogador.
#
# @author Júlio Pedro
# @version 1.1
class StrategicAI < HuntTargetAI
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

  def aligned_extension_candidates(board)
    hits = unresolved_hits(board)
    coordinates = horizontal_extensions(hits) + vertical_extensions(hits)

    coordinates.filter_map do |row, col|
      next unless board.valid_coordinate?(row, col)

      candidate = board.cell_at(row, col)
      candidate unless candidate.attacked?
    end.uniq
  end

  def horizontal_extensions(hits)
    hits.group_by(&:row).flat_map do |row, row_hits|
      consecutive_runs(row_hits.sort_by(&:col), &:col).flat_map do |run|
        next [] if run.length < 2

        [[row, run.first.col - 1], [row, run.last.col + 1]]
      end
    end
  end

  def vertical_extensions(hits)
    hits.group_by(&:col).flat_map do |col, col_hits|
      consecutive_runs(col_hits.sort_by(&:row), &:row).flat_map do |run|
        next [] if run.length < 2

        [[run.first.row - 1, col], [run.last.row + 1, col]]
      end
    end
  end

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

  def checkerboard_candidates(cells)
    cells.select { |cell| (cell.row + cell.col).even? }
  end
end
