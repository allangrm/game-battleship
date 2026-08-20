# frozen_string_literal: true

require_relative "../game"
require_relative "../weapons/basic_shot"

# Ponto de integração entre a GameView e as regras da partida. Cada chamada
# devolve uma sequência de eventos: a ação humana e, quando aplicável, as ações
# automáticas do computador até o turno voltar ao jogador ou o jogo terminar.
class GameController
  attr_reader :game

  def initialize(game)
    raise ArgumentError, "game precisa ser um Game" unless game.is_a?(Game)

    @game = game
  end

  def handle_player_attack(row, col, weapon = BasicShot.new, **options)
    events = [game.player_attack(row, col, weapon, **options)]
    events.concat(resolve_computer_turn)
    events.freeze
  end

  alias attack handle_player_attack

  # Também pode ser chamado ao iniciar uma partida em que o computador joga
  # primeiro ou por uma interface que queira processar essa etapa separadamente.
  def resolve_computer_turn
    events = []

    while game.playing? && game.current_turn == :computer
      events << game.computer_attack
    end

    events.freeze
  end
end
