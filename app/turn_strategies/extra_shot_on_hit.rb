# frozen_string_literal: true

require_relative "turn_strategy"

# Estratégia do modo que concede outra ação depois de um acerto.
#
# A decisão considera a ativação inteira. Se um Míssil ou Avião produzir
# resultados mistos, basta um :hit ou :sunk para manter o turno. Como o retorno
# é apenas booleano, uma arma de área concede no máximo uma continuação, não uma
# ação extra para cada célula acertada.
#
# @author Júlio Pedro
# @version 1.1
class ExtraShotOnHitTurnStrategy < TurnStrategy
  # @param attack_results [Array<Game::CellResult>] resultados da ativação
  # @return [Boolean] true quando houve ao menos um hit/sunk
  def keep_turn?(attack_results)
    attack_results.any?(&:hit?)
  end
end
