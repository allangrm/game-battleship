# frozen_string_literal: true

require_relative "single_shot"
require_relative "extra_shot_on_hit"

# Fábrica simples que converte a opção do setup em uma TurnStrategy.
#
# Centralizar o mapeamento evita que SetupController ou Game dependam de vários
# nomes concretos. Embora cumpra o papel de criação, esta é uma fábrica simples
# e não o Factory Method clássico do GoF baseado em subclasses criadoras.
#
# @author Júlio Pedro
# @version 1.1
class TurnStrategyFactory
  # Registro imutável entre identificadores públicos e classes concretas.
  STRATEGIES = {
    single_shot: SingleShotTurnStrategy,
    extra_shot_on_hit: ExtraShotOnHitTurnStrategy
  }.freeze

  # Cria uma nova estratégia para o modo solicitado.
  #
  # @param mode [Symbol, String] :single_shot ou :extra_shot_on_hit
  # @return [TurnStrategy]
  # @raise [ArgumentError] se o modo não estiver registrado
  def self.build(mode)
    normalized_mode = mode.to_s.strip.to_sym
    strategy_class = STRATEGIES[normalized_mode]
    return strategy_class.new if strategy_class

    raise ArgumentError, "Modo de turno inválido: #{mode.inspect}"
  end
end
