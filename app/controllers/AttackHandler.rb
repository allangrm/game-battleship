# frozen_string_literal: true

# @author Júlio Pedro
# @version 1.0
# @since 07-08-2026

class InvalidAttackError < StandardError; end

# Classe de controle, decide o que acontece quando o tabuleiro é atacado.
# valida a coordenada (RF07), pede à arma quais células
# ela mira (RF06/RF02), e resolve o efeito em cada uma (água,
# acerto ou afundamento). 
class AttackHandler
  # AttackResult: representa o resultado de um tiro numa célula.
  # cell: a Cell atingida
  # hit: true se acertou um navio
  AttackResult = Struct.new(:cell, :hit)

  def initialize(board)
    @board = board
  end
end