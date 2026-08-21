# frozen_string_literal: true

require_relative "turn_strategy"

# Estratégia do modo tradicional de um tiro por vez.
#
# O conteúdo do ataque não influencia a decisão: acerto, água, afundamento ou
# múltiplas células sempre encerram o turno atual enquanto a partida continuar.
#
# @author Júlio Pedro
# @version 1.1
class SingleShotTurnStrategy < TurnStrategy
  # @param _attack_results [Array<Game::CellResult>] ignorados por este modo
  # @return [false] sempre alterna o participante
  def keep_turn?(_attack_results)
    false
  end
end
