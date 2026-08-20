# frozen_string_literal: true

require_relative "single_shot"
require_relative "extra_shot_on_hit"

# Converte a opção coletada no setup em uma estratégia de turno.
#
# @author Júlio Pedro
# @version 1.1
class TurnStrategyFactory
  STRATEGIES = {
    single_shot: SingleShotTurnStrategy,
    extra_shot_on_hit: ExtraShotOnHitTurnStrategy
  }.freeze

  def self.build(mode)
    normalized_mode = mode.to_s.strip.to_sym
    strategy_class = STRATEGIES[normalized_mode]
    return strategy_class.new if strategy_class

    raise ArgumentError, "Modo de turno inválido: #{mode.inspect}"
  end
end
