# frozen_string_literal: true

require_relative "../weapons/missile"
require_relative "../weapons/airplane"

# Compartilha apenas os cálculos de alvo das armas especiais entre as IAs.
# As estratégias concretas continuam responsáveis por decidir quando usá-las.
# Nenhum método consulta navios ou células ocupadas ainda ocultas.
#
# @author Júlio Pedro
# @version 1.0
module SpecialWeaponTargeting
  protected

  def airplane_decision_for_aligned_hits(board, inventory)
    return unless special_available?(inventory, :airplane)

    lines = visible_hit_lines(board, minimum_hits: 2)
    build_airplane_decision(lines)
  end

  def airplane_decision_for_visible_hit(board, inventory)
    return unless special_available?(inventory, :airplane)

    lines = visible_hit_lines(board, minimum_hits: 1)
    build_airplane_decision(lines)
  end

  def best_airplane_decision(board, inventory)
    return unless special_available?(inventory, :airplane)

    build_airplane_decision(all_lines(board))
  end

  def missile_decision_near_visible_hit(board, inventory)
    return unless special_available?(inventory, :missile)

    origins = unresolved_hits(board).flat_map do |hit_cell|
      [-1, 0].product([-1, 0]).map do |row_offset, col_offset|
        [hit_cell.row + row_offset, hit_cell.col + col_offset]
      end
    end

    build_missile_decision(board, origins)
  end

  def best_missile_decision(board, inventory)
    return unless special_available?(inventory, :missile)

    origins = available_cells(board).map { |cell| [cell.row, cell.col] }
    build_missile_decision(board, origins)
  end

  def unresolved_hits(board)
    board.grid.flatten.select { |cell| cell.status == :hit }
  end

  private

  def special_available?(inventory, identifier)
    inventory && inventory.available?(identifier)
  end

  def build_airplane_decision(lines)
    candidates = lines.filter_map do |line|
      available = line.fetch(:cells).reject(&:attacked?)
      next if available.empty?

      line.merge(available: available, score: available.length)
    end
    selected = random_maximum(candidates) { |candidate| candidate.fetch(:score) }
    return unless selected

    origin = random_cell(selected.fetch(:available))
    decision_for(
      origin,
      weapon: Airplane.new,
      options: { orientation: selected.fetch(:orientation) }
    )
  end

  def build_missile_decision(board, origins)
    missile = Missile.new
    candidates = origins.uniq.filter_map do |row, col|
      next unless board.valid_coordinate?(row, col)

      origin = board.cell_at(row, col)
      next if origin.attacked?

      targets = missile.target_cells(row, col, board)
      score = targets.count do |target_row, target_col|
        !board.cell_at(target_row, target_col).attacked?
      end
      { origin: origin, score: score }
    end
    selected = random_maximum(candidates) { |candidate| candidate.fetch(:score) }
    return unless selected

    decision_for(selected.fetch(:origin), weapon: missile)
  end

  def visible_hit_lines(board, minimum_hits:)
    hits = unresolved_hits(board)
    rows = hits.group_by(&:row).filter_map do |row, row_hits|
      next if row_hits.length < minimum_hits

      { orientation: :row, cells: board.grid.fetch(row) }
    end
    columns = hits.group_by(&:col).filter_map do |col, col_hits|
      next if col_hits.length < minimum_hits

      { orientation: :col, cells: board.grid.map { |row| row.fetch(col) } }
    end

    rows + columns
  end

  def all_lines(board)
    rows = board.grid.map { |cells| { orientation: :row, cells: cells } }
    columns = (0...board.size).map do |col|
      { orientation: :col, cells: board.grid.map { |row| row.fetch(col) } }
    end

    rows + columns
  end

  def random_maximum(candidates)
    return if candidates.empty?

    maximum = candidates.map { |candidate| yield(candidate) }.max
    candidates.select { |candidate| yield(candidate) == maximum }.sample(random: random)
  end
end
