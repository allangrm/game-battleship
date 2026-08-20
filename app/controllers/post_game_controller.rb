# frozen_string_literal: true

require_relative "../game"
require_relative "../models/player"
require_relative "../services/database"
require_relative "../services/score_calculator"

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
      show_game_over(game, nil)
    end
  end

  def register_winner(game, name)
    validate_finished_game!(game)
    raise ArgumentError, "O nome só é solicitado em uma vitória" unless game.victory?

    player = Player.new(name)
    show_game_over(game, player)
    player
  end

  private

  def show_game_over(game, player)
    score = ScoreCalculator.calculate(**game.final_statistics)
    player.score = score if player

    saved_match_id = save_victory(game, player, score) if player

    @window.navigate_to(
      :game_over,
      game: game,
      player: player,
      score: score,
      saved_match_id: saved_match_id,
      persistence_error: nil
    )
  end

  def save_victory(game, player, score)
    database = Database.new

    database.save_match(
      player_name: player.name,
      map_type: game.map_type,
      result: game.result,
      score: score,
      duration_seconds: game.duration_seconds
    )
  ensure
    database&.close
  end

  def validate_finished_game!(game)
    raise ArgumentError, "game precisa ser um Game" unless game.is_a?(Game)
    raise ArgumentError, "A partida ainda não terminou" unless game.finished?
  end
end