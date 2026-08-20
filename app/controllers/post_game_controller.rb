# frozen_string_literal: true

require_relative "../game"
require_relative "../models/player"

# Define o contrato de navegação entre o fim da GameView e as telas de
# pós-partida. O nome é solicitado somente quando o jogador humano vence.
#
# @author Lívia Ferreira
# @version 1.1
class PostGameController
  def initialize(window)
    @window = window
  end

  def handle_game_over(game)
    validate_finished_game!(game)

    if game.victory?
      @window.navigate_to(
        :name,
        game: game,
        on_submit: ->(name) { register_winner(game, name) }
      )
    else
      @window.navigate_to(:game_over, game: game, player: nil)
    end
  end

  def register_winner(game, name)
    validate_finished_game!(game)
    raise ArgumentError, "O nome só é solicitado em uma vitória" unless game.victory?

    player = Player.new(name)
    @window.navigate_to(:game_over, game: game, player: player)
    player
  end

  private

  def validate_finished_game!(game)
    raise ArgumentError, "game precisa ser um Game" unless game.is_a?(Game)
    raise ArgumentError, "A partida ainda não terminou" unless game.finished?
  end
end
