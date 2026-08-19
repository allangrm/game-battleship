# frozen_string_literal: true

require_relative "cell"
require_relative "ship"

# Representa o tabuleiro e concentra as invariantes de posicionamento e ataque.
# Controllers podem escolher coordenadas, mas somente o Board altera Cell/Ship.
#
# @author Allan Guilherme
# @version 1.1
class Board
  class AutoPlacementError < StandardError; end

  ORIENTATIONS = %i[horizontal vertical].freeze
  DEFAULT_AUTO_PLACEMENT_ATTEMPTS = 1_000

  attr_reader :size, :grid, :ships

  def initialize(size)
    raise ArgumentError, "O tamanho do tabuleiro deve ser positivo" unless size.is_a?(Integer) && size.positive?

    @size = size
    @grid = Array.new(size) { |row| Array.new(size) { |col| Cell.new(row, col) } }
    @ships = []
  end

  def valid_coordinate?(row, col)
    row.is_a?(Integer) && col.is_a?(Integer) &&
      row.between?(0, size - 1) && col.between?(0, size - 1)
  end

  def cell_at(row, col)
    return nil unless valid_coordinate?(row, col)

    grid[row][col]
  end

  def place_ship(ship, coordinates)
    raise ArgumentError, "Navio já está posicionado" if ship.placed?
    raise ArgumentError, "Posição inválida para o navio" unless valid_placement?(ship, coordinates)

    cells = coordinates.map { |row, col| cell_at(row, col) }
    ship.place(cells)
    ships << ship
    ship
  end

  # Posiciona uma frota de forma aleatória e limitada. Em caso de falha, todos
  # os navios posicionados por esta chamada são removidos para manter o Board
  # consistente e permitir uma nova tentativa.
  def auto_place_ships(
    fleet,
    random: Random.new,
    max_attempts_per_ship: DEFAULT_AUTO_PLACEMENT_ATTEMPTS
  )
    unless max_attempts_per_ship.is_a?(Integer) && max_attempts_per_ship.positive?
      raise ArgumentError, "O limite de tentativas deve ser positivo"
    end

    placed_in_this_call = []

    begin
      fleet.each do |ship|
        placed = try_auto_place_ship(ship, random, max_attempts_per_ship)
        raise AutoPlacementError, "Não foi possível posicionar o navio #{ship.name}" unless placed

        placed_in_this_call << ship
      end
    rescue StandardError
      rollback_auto_placements(placed_in_this_call)
      raise
    end

    ships
  end

  def valid_placement?(ship, coordinates)
    return false unless coordinates.is_a?(Array)
    return false unless coordinates.length == ship.size
    return false unless coordinates.all? { |row, col| valid_coordinate?(row, col) }
    return false if coordinates.any? { |row, col| cell_at(row, col).occupied? }

    rows = coordinates.map(&:first)
    cols = coordinates.map(&:last)
    horizontal = rows.uniq.length == 1
    vertical = cols.uniq.length == 1
    return false unless horizontal || vertical

    axis = horizontal ? cols.sort : rows.sort
    axis.each_cons(2).all? { |first, second| second - first == 1 }
  end

  # Fonte de verdade do ataque a uma célula.
  #
  # @return [Symbol] :hit, :miss, :sunk, :invalid ou :already_attacked
  def receive_attack(row, col)
    return :invalid unless valid_coordinate?(row, col)

    cell = cell_at(row, col)
    return :already_attacked if cell.attacked?

    if cell.occupied?
      resolve_hit(cell)
    else
      cell.status = :miss
      :miss
    end
  end

  def generate_coordinates(row, col, length, orientation)
    return nil unless ORIENTATIONS.include?(orientation)

    coordinates = (0...length).map do |offset|
      if orientation == :horizontal
        [row, col + offset]
      else
        [row + offset, col]
      end
    end

    return nil unless coordinates.all? { |candidate_row, candidate_col| valid_coordinate?(candidate_row, candidate_col) }

    coordinates
  end

  def all_ships_sunk?
    ships.any? && ships.all?(&:sunk?)
  end

  def ships_remaining
    ships.count { |ship| !ship.sunk? }
  end

  private

  def try_auto_place_ship(ship, random, max_attempts)
    max_attempts.times do
      orientation = ORIENTATIONS.sample(random: random)
      row = random.rand(size)
      col = random.rand(size)
      coordinates = generate_coordinates(row, col, ship.size, orientation)
      next unless coordinates && valid_placement?(ship, coordinates)

      place_ship(ship, coordinates)
      return true
    end

    false
  end

  def rollback_auto_placements(placed_ships)
    placed_ships.each do |ship|
      ships.delete(ship)
      ship.unplace
    end
  end

  def resolve_hit(cell)
    ship = cell.ship
    cell.status = :hit
    ship.register_hit

    return :hit unless ship.sunk?

    ship.cells.each { |ship_cell| ship_cell.status = :sunk }
    :sunk
  end
end
