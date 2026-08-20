# frozen_string_literal: true

require_relative "test_helper"

class BoardTest < Minitest::Test
  def test_board_starts_with_a_two_dimensional_grid
    board = Board.new(5)

    assert_equal 5, board.grid.length
    assert board.grid.all? { |row| row.length == 5 }
    refute board.all_ships_sunk?
  end

  def test_manual_placement_and_attack_lifecycle
    board = Board.new(5)
    ship = Ship.new("Barco", 2)

    board.place_ship(ship, [[1, 1], [1, 2]])

    assert_equal :hit, board.receive_attack(1, 1)
    assert_equal :already_attacked, board.receive_attack(1, 1)
    assert_equal :sunk, board.receive_attack(1, 2)
    assert board.all_ships_sunk?
    assert ship.cells.all? { |cell| cell.status == :sunk }
  end

  def test_invalid_manual_placements_are_rejected
    board = Board.new(5)

    refute board.valid_placement?(Ship.new("Diagonal", 2), [[0, 0], [1, 1]])
    refute board.valid_placement?(Ship.new("Lacuna", 2), [[0, 0], [0, 2]])
    refute board.valid_placement?(Ship.new("Fora", 2), [[0, 4], [0, 5]])
  end

  def test_remove_ship_releases_its_cells
    board = Board.new(5)
    ship = Ship.new("Barco", 2)
    board.place_ship(ship, [[0, 0], [0, 1]])

    removed_ship = board.remove_ship(ship)

    assert_same ship, removed_ship
    assert_empty board.ships
    refute ship.placed?
    refute board.cell_at(0, 0).occupied?
    refute board.cell_at(0, 1).occupied?
  end

  def test_remove_ship_rejects_a_ship_from_another_board
    board = Board.new(5)
    ship = Ship.new("Barco", 2)

    error = assert_raises(ArgumentError) { board.remove_ship(ship) }

    assert_equal "Navio não pertence a este tabuleiro", error.message
  end

  def test_reposition_ship_moves_without_duplicating_the_ship
    board = Board.new(5)
    ship = Ship.new("Barco", 2)
    board.place_ship(ship, [[0, 0], [0, 1]])

    repositioned_ship = board.reposition_ship(ship, [[2, 1], [2, 2]])

    assert_same ship, repositioned_ship
    assert_equal [ship], board.ships
    refute board.cell_at(0, 0).occupied?
    refute board.cell_at(0, 1).occupied?
    assert_same ship, board.cell_at(2, 1).ship
    assert_same ship, board.cell_at(2, 2).ship
  end

  def test_invalid_reposition_restores_the_previous_position
    board = Board.new(5)
    ship = Ship.new("Barco", 2)
    board.place_ship(ship, [[0, 0], [0, 1]])

    assert_raises(ArgumentError) do
      board.reposition_ship(ship, [[4, 4], [4, 5]])
    end

    assert_equal [ship], board.ships
    assert_same ship, board.cell_at(0, 0).ship
    assert_same ship, board.cell_at(0, 1).ship
    assert_equal [[0, 0], [0, 1]], ship.cells.map { |cell| [cell.row, cell.col] }
  end

  def test_remove_ship_is_rejected_after_an_attack
    board = Board.new(5)
    ship = Ship.new("Barco", 2)
    board.place_ship(ship, [[0, 0], [0, 1]])
    board.receive_attack(4, 4)

    error = assert_raises(ArgumentError) { board.remove_ship(ship) }

    assert_equal "Não é possível remover um navio depois do início da partida", error.message
    assert_equal [ship], board.ships
    assert ship.placed?
  end

  def test_auto_placement_positions_the_complete_fleet_without_overlap
    config = MapConfig.new(:poca)
    board = config.create_board
    fleet = config.create_fleet

    board.auto_place_ships(fleet, random: Random.new(1234))

    assert_equal fleet, board.ships
    assert fleet.all?(&:placed?)
    occupied_cells = board.grid.flatten.select(&:occupied?)
    assert_equal fleet.sum(&:size), occupied_cells.length
    assert_equal occupied_cells.length, occupied_cells.map(&:object_id).uniq.length
  end

  def test_auto_placement_rolls_back_when_a_ship_cannot_fit
    board = Board.new(2)
    fleet = [Ship.new("Pequeno", 2), Ship.new("Impossível", 3)]

    assert_raises(Board::AutoPlacementError) do
      board.auto_place_ships(
        fleet,
        random: Random.new(7),
        max_attempts_per_ship: 20
      )
    end

    assert_empty board.ships
    assert fleet.none?(&:placed?)
    assert board.grid.flatten.none?(&:occupied?)
  end

  def test_invalid_coordinate_types_do_not_raise
    board = Board.new(5)

    refute board.valid_coordinate?(nil, 0)
    refute board.valid_coordinate?("1", 0)
    assert_equal :invalid, board.receive_attack(nil, 0)
  end
end
