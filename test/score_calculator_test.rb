# frozen_string_literal: true

require_relative "test_helper"

class ScoreCalculatorTest < Minitest::Test
  def test_calculates_score_using_every_required_factor
    score = ScoreCalculator.calculate(
      hits: 5,
      surviving_ships: 2,
      remaining_ship_cells: 8,
      duration_seconds: 60
    )

    assert_equal 1_840, score
  end

  def test_each_positive_factor_increases_the_score
    attributes = {
      hits: 1,
      surviving_ships: 1,
      remaining_ship_cells: 1,
      duration_seconds: 10
    }
    baseline = ScoreCalculator.calculate(**attributes)

    assert_equal 100, ScoreCalculator.calculate(**attributes.merge(hits: 2)) - baseline
    assert_equal 500, ScoreCalculator.calculate(**attributes.merge(surviving_ships: 2)) - baseline
    assert_equal 50, ScoreCalculator.calculate(**attributes.merge(remaining_ship_cells: 2)) - baseline
  end

  def test_longer_duration_reduces_the_score
    attributes = {
      hits: 5,
      surviving_ships: 1,
      remaining_ship_cells: 4,
      duration_seconds: 30
    }

    faster_score = ScoreCalculator.calculate(**attributes)
    slower_score = ScoreCalculator.calculate(**attributes.merge(duration_seconds: 90))

    assert_equal 60, faster_score - slower_score
  end

  def test_score_never_becomes_negative
    score = ScoreCalculator.calculate(
      hits: 0,
      surviving_ships: 0,
      remaining_ship_cells: 0,
      duration_seconds: 3_600
    )

    assert_equal 0, score
  end

  def test_rejects_negative_or_non_integer_values
    valid_attributes = {
      hits: 1,
      surviving_ships: 1,
      remaining_ship_cells: 1,
      duration_seconds: 1
    }

    valid_attributes.each_key do |attribute|
      assert_raises(ArgumentError) do
        ScoreCalculator.calculate(**valid_attributes.merge(attribute => -1))
      end
    end

    assert_raises(ArgumentError) do
      ScoreCalculator.calculate(**valid_attributes.merge(duration_seconds: 1.5))
    end
  end
end
