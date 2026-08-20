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

    special_decision = StrategicAI.new(random: Random.new(3)).choose_attack(
      board,
      inventory: WeaponInventory.for_map(:oceano)
    )
    assert_instance_of Airplane, special_decision.weapon
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

  def test_easy_ai_keeps_the_basic_shot_policy
    inventory = WeaponInventory.for_map(:poca)
    decision = RandomAI.new(random: Random.new(5)).choose_attack(
      Board.new(5),
      inventory: inventory
    )

    assert_instance_of BasicShot, decision.weapon
    assert_equal({ basic_shot: nil, missile: 1, airplane: 1 }, inventory.to_h)
  end

  def test_medium_ai_uses_missile_around_a_visible_hit
    board = Board.new(5)
    ship = Ship.new("Fragata", 3)
    board.place_ship(ship, [[2, 2], [2, 3], [2, 4]])
    board.receive_attack(2, 2)
    inventory = WeaponInventory.for_map(:lago)

    decision = HuntTargetAI.new(random: Random.new(5)).choose_attack(
      board,
      inventory: inventory
    )
    targets = decision.weapon.target_cells(decision.row, decision.col, board)

    assert_instance_of Missile, decision.weapon
    assert_includes targets, [2, 2]
    refute board.cell_at(decision.row, decision.col).attacked?
    assert_equal 2, inventory.remaining(:missile)
  end

  def test_medium_ai_uses_airplane_for_aligned_visible_hits
    board = Board.new(5)
    ship = Ship.new("Corveta", 4)
    board.place_ship(ship, [[2, 0], [2, 1], [2, 2], [2, 3]])
    board.receive_attack(2, 1)
    board.receive_attack(2, 2)

    decision = HuntTargetAI.new(random: Random.new(8)).choose_attack(
      board,
      inventory: WeaponInventory.for_map(:lago)
    )

    assert_instance_of Airplane, decision.weapon
    assert_equal :row, decision.options[:orientation]
    assert_equal 2, decision.row
    refute board.cell_at(decision.row, decision.col).attacked?
  end

  def test_hard_ai_uses_special_weapons_proactively
    board = Board.new(5)
    inventory = WeaponInventory.for_map(:oceano)

    airplane_decision = StrategicAI.new(random: Random.new(5)).choose_attack(
      board,
      inventory: inventory
    )
    inventory.consume!(:airplane)
    missile_decision = StrategicAI.new(random: Random.new(5)).choose_attack(
      board,
      inventory: inventory
    )

    assert_instance_of Airplane, airplane_decision.weapon
    assert_includes %i[row col], airplane_decision.options[:orientation]
    assert_instance_of Missile, missile_decision.weapon
    assert_equal 3, inventory.remaining(:missile)
    assert_equal 0, inventory.remaining(:airplane)
  end
end
