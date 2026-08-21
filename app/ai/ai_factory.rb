# frozen_string_literal: true

require_relative "random_ai"
require_relative "hunt_target_ai"
require_relative "strategic_ai"

# Fábrica simples das estratégias de IA e dificuldades por mapa.
#
# Game depende apenas do contrato #choose_attack e solicita a implementação
# adequada ao mapa. Centralizar essa decisão evita condicionais sobre mapas no
# núcleo da partida e permite que a interface consulte o rótulo de dificuldade.
#
# @author Júlio Pedro
# @version 1.0
class AIFactory
  # Registro imutável que associa mapa, dificuldade pública e classe concreta.
  CONFIGURATIONS = {
    poca: { difficulty: :easy, strategy: RandomAI }.freeze,
    lago: { difficulty: :medium, strategy: HuntTargetAI }.freeze,
    oceano: { difficulty: :hard, strategy: StrategicAI }.freeze
  }.freeze

  # Constrói uma nova IA para o mapa informado.
  #
  # @param map_type [Symbol, String] :poca, :lago ou :oceano
  # @param random [Random] fonte injetável compartilhada com a estratégia
  # @return [RandomAI, HuntTargetAI, StrategicAI]
  # @raise [ArgumentError] se o mapa não estiver registrado
  def self.build(map_type, random: Random.new)
    configuration = configuration_for(map_type)
    configuration[:strategy].new(random: random)
  end

  class << self
    alias for_map build
  end

  # Consulta a dificuldade sem precisar criar a estratégia.
  #
  # @param map_type [Symbol, String]
  # @return [Symbol] :easy, :medium ou :hard
  # @raise [ArgumentError] se o mapa não estiver registrado
  def self.difficulty_for(map_type)
    configuration_for(map_type)[:difficulty]
  end

  # Normaliza o mapa e recupera seu registro interno.
  #
  # @return [Hash] difficulty e strategy
  # @api private
  def self.configuration_for(map_type)
    normalized_map_type = map_type.to_s.strip.to_sym
    configuration = CONFIGURATIONS[normalized_map_type]
    return configuration if configuration

    raise ArgumentError, "Mapa inválido para a IA: #{map_type.inspect}"
  end

  private_class_method :configuration_for
end
