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
# O serviço é puro: recebe números e devolve um número, sem acessar Game,
# interface ou banco. Essa separação torna a fórmula simples de testar e mudar.
#
# @author Allan Guilherme
# @version 1.0
class ScoreCalculator
  POINTS_PER_HIT = 100
  POINTS_PER_SURVIVING_SHIP = 500
  POINTS_PER_REMAINING_SHIP_CELL = 50
  TIME_PENALTY_PER_SECOND = 1

  # Atalho de classe usado pelo fluxo de pós-jogo.
  #
  # @param attributes [Hash] fatores aceitos por #calculate
  # @return [Integer] pontuação final
  def self.calculate(**attributes)
    new.calculate(**attributes)
  end

  # Aplica a fórmula completa após validar seus quatro fatores.
  #
  # @param hits [Integer] segmentos atingidos na frota inimiga
  # @param surviving_ships [Integer] navios aliados não afundados
  # @param remaining_ship_cells [Integer] segmentos aliados ainda intactos
  # @param duration_seconds [Integer] duração total usada como penalidade
  # @return [Integer] pontuação nunca inferior a zero
  # @raise [ArgumentError] quando algum fator não é inteiro não negativo
  def calculate(hits:, surviving_ships:, remaining_ship_cells:, duration_seconds:)
    values = {
      hits: hits,
      surviving_ships: surviving_ships,
      remaining_ship_cells: remaining_ship_cells,
      duration_seconds: duration_seconds
    }
    validate_values!(values)

    # Cada parcela permanece explícita para que os pesos possam ser explicados
    # e ajustados de forma independente.
    score = (hits * POINTS_PER_HIT) +
            (surviving_ships * POINTS_PER_SURVIVING_SHIP) +
            (remaining_ship_cells * POINTS_PER_REMAINING_SHIP_CELL) -
            (duration_seconds * TIME_PENALTY_PER_SECOND)

    # Uma partida longa sem bônus não produz valores negativos no ranking.
    [score, 0].max
  end

  private

  # Aplica a mesma regra de domínio a todos os fatores recebidos.
  def validate_values!(values)
    values.each do |name, value|
      next if value.is_a?(Integer) && value >= 0

      raise ArgumentError, "#{name} deve ser um numero inteiro nao negativo"
    end
  end
end
