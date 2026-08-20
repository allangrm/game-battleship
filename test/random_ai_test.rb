# frozen_string_literal: true

require_relative "test_helper"

class RandomAITest < Minitest::Test
  def test_chooses_each_coordinate_at_most_once_as_board_is_updated
    board = Board.new(2)
    ai = RandomAI.new(random: Random.new(1234))
    coordinates = []

    4.times do
      decision = ai.choose_attack(board)
      coordinates << [decision.row, decision.col]
      assert_instance_of BasicShot, decision.weapon
      board.receive_attack(decision.row, decision.col)
    end

    assert_equal 4, coordinates.uniq.length
    assert_raises(RandomAI::NoAvailableCoordinateError) { ai.choose_attack(board) }
  end

  def test_only_available_coordinate_is_selected
    board = Board.new(2)
    board.receive_attack(0, 0)
    board.receive_attack(0, 1)
    board.receive_attack(1, 0)

    decision = RandomAI.new.choose_attack(board)

    assert_equal [1, 1], [decision.row, decision.col]
    assert_empty decision.options
  end

  def test_current_policy_receives_inventory_but_still_chooses_basic_shot
    board = Board.new(2)
    inventory = WeaponInventory.for_map(:oceano)

    decision = RandomAI.new(random: Random.new(9)).choose_attack(board, inventory: inventory)

    assert_instance_of BasicShot, decision.weapon
    assert_equal 3, inventory.remaining(:missile)
    assert_equal 3, inventory.remaining(:torpedo)
    assert_equal 1, inventory.remaining(:airplane)
  end
end
