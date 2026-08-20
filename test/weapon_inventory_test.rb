# frozen_string_literal: true

require_relative "test_helper"

class WeaponInventoryTest < Minitest::Test
  def test_loadouts_scale_special_weapons_by_map
    expected = {
      poca: { basic_shot: nil, missile: 1, torpedo: 1, airplane: 1 },
      lago: { basic_shot: nil, missile: 2, torpedo: 2, airplane: 1 },
      oceano: { basic_shot: nil, missile: 3, torpedo: 3, airplane: 1 }
    }

    expected.each do |map_type, loadout|
      assert_equal loadout, WeaponInventory.for_map(map_type).to_h
    end
  end

  def test_basic_shot_is_available_and_unlimited
    inventory = WeaponInventory.for_map(:poca)

    10.times { assert_nil inventory.consume!(BasicShot.new) }

    assert inventory.available?(:basic_shot)
    assert_nil inventory.remaining(:basic_shot)
  end

  def test_special_charge_is_consumed_and_cannot_be_overused
    inventory = WeaponInventory.for_map(:poca)

    assert_equal 0, inventory.consume!(Missile.new)
    refute inventory.available?(:missile)
    assert_raises(WeaponInventory::WeaponUnavailableError) { inventory.consume!(:missile) }
  end

  def test_participants_receive_independent_inventories
    player_inventory = WeaponInventory.for_map(:lago)
    computer_inventory = WeaponInventory.for_map(:lago)

    player_inventory.consume!(:torpedo)

    assert_equal 1, player_inventory.remaining(:torpedo)
    assert_equal 2, computer_inventory.remaining(:torpedo)
  end

  def test_rejects_invalid_maps_weapons_and_amounts
    assert_raises(ArgumentError) { WeaponInventory.for_map(:rio) }
    assert_raises(ArgumentError) { WeaponInventory.new({ laser: 1 }) }
    assert_raises(ArgumentError) { WeaponInventory.new({ missile: -1 }) }
    assert_raises(ArgumentError) { WeaponInventory.new({ missile: 1.5 }) }
    assert_raises(ArgumentError) { WeaponInventory.new({ basic_shot: 1 }) }
  end
end
