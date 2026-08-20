# frozen_string_literal: true

require_relative "turn_strategy"

# Mantém o turno quando a ação atingiu ao menos uma embarcação. Uma arma de
# área concede no máximo uma continuação, independentemente do total de acertos.
# 
# @author Júlio Pedro
# @version 1.1
class ExtraShotOnHitTurnStrategy < TurnStrategy
  def keep_turn?(attack_results)
    attack_results.any?(&:hit?)
  end
end
