# Representa um Jogador.
#
# @author Allan Guilherme
# @version 1.0
# @since 06-08-2026

module Battleship
  class Player
    attr_reader :name
    attr_accessor :board, :score

    def initialize(name)
      @name = name
      @board = nil
      @score = 0
    end
  end
end
