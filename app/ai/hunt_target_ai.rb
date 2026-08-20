# frozen_string_literal: true

require_relative "random_ai"

# IA intermediária que procura aleatoriamente até encontrar uma embarcação e,
# depois de um acerto, prioriza as células ortogonais ainda não atacadas.
# Somente informações visíveis do tabuleiro são consultadas.
#
# @author Júlio Pedro
# @version 1.0
class HuntTargetAI < RandomAI
  NEIGHBOR_OFFSETS = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1]
  ].freeze

  def choose_attack(board, inventory: nil)
    cells = available_cells(board)
    ensure_available_coordinate!(cells)

    target = random_cell(hunt_candidates(board)) || random_cell(cells)
    decision_for(target)
  end

  protected

  def unresolved_hits(board)
    board.grid.flatten.select { |cell| cell.status == :hit }
  end

  def hunt_candidates(board)
    unresolved_hits(board).flat_map do |hit_cell|
      NEIGHBOR_OFFSETS.filter_map do |row_offset, col_offset|
        row = hit_cell.row + row_offset
        col = hit_cell.col + col_offset
        next unless board.valid_coordinate?(row, col)

        candidate = board.cell_at(row, col)
        candidate unless candidate.attacked?
      end
    end.uniq
  end
end
