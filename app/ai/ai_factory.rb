# frozen_string_literal: true

require_relative "random_ai"
require_relative "hunt_target_ai"
require_relative "strategic_ai"

# Seleciona a estratégia e o nível de dificuldade padrão de cada mapa.
#
# @author Júlio Pedro
# @version 1.0
class AIFactory
  CONFIGURATIONS = {
    poca: { difficulty: :easy, strategy: RandomAI }.freeze,
    lago: { difficulty: :medium, strategy: HuntTargetAI }.freeze,
    oceano: { difficulty: :hard, strategy: StrategicAI }.freeze
  }.freeze

  def self.build(map_type, random: Random.new)
    configuration = configuration_for(map_type)
    configuration[:strategy].new(random: random)
  end

  class << self
    alias for_map build
  end

  def self.difficulty_for(map_type)
    configuration_for(map_type)[:difficulty]
  end

  def self.configuration_for(map_type)
    normalized_map_type = map_type.to_s.strip.to_sym
    configuration = CONFIGURATIONS[normalized_map_type]
    return configuration if configuration

    raise ArgumentError, "Mapa inválido para a IA: #{map_type.inspect}"
  end

  private_class_method :configuration_for
end
