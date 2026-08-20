# frozen_string_literal: true

# Representa o jogador humano e os dados da partida atual.
#
# @author Allan Guilherme
# @version 1.1
class Player
  attr_reader :name
  attr_accessor :score

  def initialize(name)
    normalized_name = name.to_s.strip
    raise ArgumentError, "O nome do jogador não pode ficar vazio" if normalized_name.empty?

    @name = normalized_name
    @score = 0
  end
end
