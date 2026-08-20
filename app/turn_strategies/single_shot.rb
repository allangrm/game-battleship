# frozen_string_literal: true

require_relative "turn_strategy"

# Modo tradicional: toda ação de ataque encerra o turno atual.
class SingleShotTurnStrategy < TurnStrategy
  def keep_turn?(_attack_results)
    false
  end
end
