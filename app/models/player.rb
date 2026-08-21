# frozen_string_literal: true

# Representa o jogador humano e os dados da partida atual.
#
# O tabuleiro não pertence a Player: Game mantém `player_board` como fonte
# única do estado da partida. Player concentra apenas identidade e pontuação.
#
# @author Allan Guilherme
# @version 1.1
class Player
  attr_reader :name
  attr_accessor :score

  # Cria um jogador com nome normalizado e pontuação inicial zero.
  #
  # @param name [Object] valor convertível para texto
  # @raise [ArgumentError] quando o nome fica vazio após remover espaços
  def initialize(name)
    normalized_name = name.to_s.strip
    raise ArgumentError, "O nome do jogador não pode ficar vazio" if normalized_name.empty?

    @name = normalized_name
    @score = 0
  end
end
