# frozen_string_literal: true

require_relative "test_helper"

class AIDifficultyTest < Minitest::Test
  def test_factory_assigns_a_difficulty_and_strategy_to_each_map
    assert_instance_of RandomAI, AIFactory.for_map(:poca, random: Random.new(1))
    assert_instance_of HuntTargetAI, AIFactory.for_map("lago", random: Random.new(1))
    assert_instance_of StrategicAI, AIFactory.for_map(:oceano, random: Random.new(1))

    assert_equal :easy, AIFactory.difficulty_for(:poca)
    assert_equal :medium, AIFactory.difficulty_for(:lago)
    assert_equal :hard, AIFactory.difficulty_for(:oceano)
    assert_raises(ArgumentError) { AIFactory.for_map(:rio) }
  end

  def test_medium_ai_prioritizes_an_unattacked_neighbor_after_a_hit
    board = Board.new(5)
    ship = Ship.new("Fragata", 3)
    board.place_ship(ship, [[2, 2], [2, 3], [2, 4]])
    board.receive_attack(2, 2)

    decision = HuntTargetAI.new(random: Random.new(4)).choose_attack(board)
    distance = (decision.row - 2).abs + (decision.col - 2).abs

    assert_equal 1, distance
    refute board.cell_at(decision.row, decision.col).attacked?
    assert_instance_of BasicShot, decision.weapon
  end

  def test_hard_ai_extends_two_aligned_hits
    board = Board.new(5)
    ship = Ship.new("Corveta", 4)
    board.place_ship(ship, [[2, 0], [2, 1], [2, 2], [2, 3]])
    board.receive_attack(2, 1)
    board.receive_attack(2, 2)

    decision = StrategicAI.new(random: Random.new(7)).choose_attack(board)

    assert_includes [[2, 0], [2, 3]], [decision.row, decision.col]
    assert_instance_of BasicShot, decision.weapon
  end

  def test_hard_ai_uses_checkerboard_search_without_active_hits
    board = Board.new(5)
    decision = StrategicAI.new(random: Random.new(9)).choose_attack(board)

    assert_predicate(decision.row + decision.col, :even?)
  end

  def test_every_difficulty_uses_only_visible_board_information
    board = Board.new(4)
    board.grid.flatten.each do |cell|
      cell.define_singleton_method(:ship) { raise "A IA consultou o navio oculto" }
      cell.define_singleton_method(:occupied?) { raise "A IA consultou uma posição oculta" }
    end

    [RandomAI, HuntTargetAI, StrategicAI].each do |strategy|
      decision = strategy.new(random: Random.new(3)).choose_attack(board)

      assert board.valid_coordinate?(decision.row, decision.col)
      assert_instance_of BasicShot, decision.weapon
    end
  end

  def test_every_difficulty_avoids_repeated_coordinates
    [RandomAI, HuntTargetAI, StrategicAI].each do |strategy|
      board = Board.new(3)
      ai = strategy.new(random: Random.new(11))
      coordinates = []

      9.times do
        decision = ai.choose_attack(board)
        coordinates << [decision.row, decision.col]
        board.receive_attack(decision.row, decision.col)
      end

      assert_equal 9, coordinates.uniq.length
      assert_raises(RandomAI::NoAvailableCoordinateError) { ai.choose_attack(board) }
    end
  end

  def test_new_strategies_do_not_consume_special_weapon_inventory
    inventory = WeaponInventory.for_map(:oceano)

    [HuntTargetAI, StrategicAI].each do |strategy|
      decision = strategy.new(random: Random.new(5)).choose_attack(Board.new(3), inventory: inventory)

      assert_instance_of BasicShot, decision.weapon
    end

    assert_equal 3, inventory.remaining(:missile)
    assert_equal 1, inventory.remaining(:airplane)
  end
end
