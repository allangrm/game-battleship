# frozen_string_literal: true

require_relative "test_helper"

class AttackHandlerTest < Minitest::Test
  def test_ruby_names_follow_file_and_class_conventions
    assert_instance_of BasicShot, BasicShot.new
    assert_instance_of Missile, Missile.new
    assert_instance_of Airplane, Airplane.new
    assert_instance_of AttackHandler, AttackHandler.new(Board.new(5))
  end

  def test_weapon_target_patterns
    board = Board.new(5)

    assert_equal [[2, 3]], BasicShot.new.target_cells(2, 3, board)
    assert_equal [[4, 4]], Missile.new.target_cells(4, 4, board)
    assert_equal (0...5).map { |col| [2, col] }, Airplane.new.target_cells(2, 0, board)
    assert_equal (0...5).map { |row| [row, 3] },
                 Airplane.new.target_cells(0, 3, board, orientation: :col)
  end

  def test_airplane_rejects_an_invalid_orientation
    error = assert_raises(ArgumentError) do
      Airplane.new.target_cells(0, 0, Board.new(5), orientation: :diagonal)
    end

    assert_match(/Orientação inválida/, error.message)
  end

  def test_missile_clips_its_area_at_board_edges
    board = Board.new(5)
    missile = Missile.new

    assert_equal [[0, 0], [1, 0], [0, 1], [1, 1]], missile.target_cells(0, 0, board)
    assert_equal [[0, 4], [1, 4]], missile.target_cells(0, 4, board)
    assert_equal [[4, 0], [4, 1]], missile.target_cells(4, 0, board)
    assert_equal [[4, 4]], missile.target_cells(4, 4, board)
  end

  def test_handler_delegates_area_damage_and_sinking_to_board
    board = Board.new(5)
    ship = Ship.new("Barco", 2)
    board.place_ship(ship, [[0, 0], [0, 1]])

    results = AttackHandler.new(board).attack(0, 0, Missile.new)

    assert_equal %i[hit miss sunk miss], results.map(&:status)
    assert_equal 2, ship.hits
    assert ship.sunk?
    assert ship.cells.all? { |cell| cell.status == :sunk }
    assert results.first.hit?
  end

  def test_area_weapon_skips_already_attacked_cells_without_duplicate_hits
    board = Board.new(5)
    ship = Ship.new("Barco", 2)
    board.place_ship(ship, [[0, 1], [0, 2]])
    assert_equal :hit, board.receive_attack(0, 1)

    results = AttackHandler.new(board).attack(0, 0, Missile.new)

    assert_equal 3, results.length
    assert_equal 1, ship.hits
    refute ship.sunk?
  end

  def test_handler_rejects_invalid_and_repeated_origin
    board = Board.new(5)
    handler = AttackHandler.new(board)

    assert_raises(InvalidAttackError) { handler.attack(-1, 0, BasicShot.new) }

    handler.attack(0, 0, BasicShot.new)
    assert_raises(InvalidAttackError) { handler.attack(0, 0, BasicShot.new) }
  end
end
