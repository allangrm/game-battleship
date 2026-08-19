# frozen_string_literal: true

# Calcula a pontuacao final da partida (RF10).
#
# Formula:
#   (acertos * 100) +
#   (navios aliados sobreviventes * 500) +
#   (celulas aliadas restantes * 50) -
#   duracao da partida em segundos
#
# A pontuacao minima e zero. A integridade da frota e representada pela
# quantidade total de celulas ainda intactas nos navios aliados.
#
# @author Allan Guilherme
# @version 1.0
class ScoreCalculator
  POINTS_PER_HIT = 100
  POINTS_PER_SURVIVING_SHIP = 500
  POINTS_PER_REMAINING_SHIP_CELL = 50
  TIME_PENALTY_PER_SECOND = 1

  def self.calculate(**attributes)
    new.calculate(**attributes)
  end

  def calculate(hits:, surviving_ships:, remaining_ship_cells:, duration_seconds:)
    values = {
      hits: hits,
      surviving_ships: surviving_ships,
      remaining_ship_cells: remaining_ship_cells,
      duration_seconds: duration_seconds
    }
    validate_values!(values)

    score = (hits * POINTS_PER_HIT) +
            (surviving_ships * POINTS_PER_SURVIVING_SHIP) +
            (remaining_ship_cells * POINTS_PER_REMAINING_SHIP_CELL) -
            (duration_seconds * TIME_PENALTY_PER_SECOND)

    [score, 0].max
  end

  private

  def validate_values!(values)
    values.each do |name, value|
      next if value.is_a?(Integer) && value >= 0

      raise ArgumentError, "#{name} deve ser um numero inteiro nao negativo"
    end
  end
end
