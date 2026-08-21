# frozen_string_literal: true

# Classe-base do padrão Strategy aplicado à dinâmica de turnos.
#
# Game não possui condicionais para descobrir qual modo foi escolhido. Depois
# de uma ativação válida, ele entrega os CellResult a #keep_turn? e aceita a
# decisão polimórfica. Isso permite acrescentar novos modos sem reescrever o
# pipeline de ataque.
#
# @author Júlio Pedro
# @version 1.1
class TurnStrategy
  # Decide se o ator da última ação deve permanecer com o turno.
  #
  # @param _attack_results [Array<Game::CellResult>] resultados da ativação
  # @return [Boolean]
  # @raise [NotImplementedError] quando uma subclasse não implementa o contrato
  def keep_turn?(_attack_results)
    raise NotImplementedError, "#{self.class} precisa implementar #keep_turn?"
  end
end
