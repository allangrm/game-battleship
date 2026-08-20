# frozen_string_literal: true

require_relative "test_helper"

class TurnStrategiesTest < Minitest::Test
  Result = Struct.new(:status) do
    def hit?
      %i[hit sunk].include?(status)
    end
  end

  def test_base_strategy_requires_an_implementation
    assert_raises(NotImplementedError) do
      TurnStrategy.new.keep_turn?([])
    end
  end

  def test_single_shot_never_keeps_the_turn
    strategy = SingleShotTurnStrategy.new

    refute strategy.keep_turn?([Result.new(:hit)])
    refute strategy.keep_turn?([Result.new(:miss)])
  end

  def test_extra_shot_keeps_turn_when_any_cell_was_hit
    strategy = ExtraShotOnHitTurnStrategy.new

    refute strategy.keep_turn?([Result.new(:miss), Result.new(:miss)])
    assert strategy.keep_turn?([Result.new(:miss), Result.new(:hit)])
    assert strategy.keep_turn?([Result.new(:sunk), Result.new(:miss)])
  end
end
