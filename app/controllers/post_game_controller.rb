# frozen_string_literal: true

require_relative "../game"
require_relative "../models/player"
require_relative "../services/database"
require_relative "../services/score_calculator"

# Controla o encerramento da partida, calcula a pontuação e registra a vitória.
# Depois disso, envia os dados necessários para a tela de resultado.
#
# @author Raffael Wagner
# @version 1.0
class PostGameController
  # Cria o controller que cuida das telas mostradas depois da partida.
  #
  # @param window [MainWindow] janela usada para trocar de tela
  # @return [PostGameController] controller criado
  def initialize(window)
    @window = window
  end

  # Decide qual tela abrir quando a partida termina.
  # Em uma vitória, primeiro pede o nome. Em uma derrota, vai direto ao resultado.
  #
  # @param game [Game] partida que acabou
  # @return [void]
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

  # Cria o jogador vencedor e continua para a tela de resultado.
  #
  # @param game [Game] partida vencida pelo jogador
  # @param name [String] nome digitado na tela
  # @return [Player] jogador criado com o nome informado
  def register_winner(game, name)
    validate_finished_game!(game)
    raise ArgumentError, "O nome só é solicitado em uma vitória" unless game.victory?

    player = Player.new(name)
    show_game_over(game, player)
    player
  end

  private

  # Calcula a pontuação, salva a vitória quando existe jogador e abre o resultado.
  #
  # @param game [Game] partida finalizada
  # @param player [Player, nil] vencedor ou nil em caso de derrota
  # @return [void]
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

  # Grava uma vitória no banco de dados e fecha a conexão no final.
  #
  # @param game [Game] partida vencida
  # @param player [Player] jogador que venceu
  # @param score [Integer] pontuação calculada
  # @return [Integer] identificador da partida salva
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

  # Confere se o objeto recebido é uma partida que já terminou.
  #
  # @param game [Object] objeto que será validado
  # @return [void]
  # @raise [ArgumentError] quando o objeto não é um Game finalizado
  def validate_finished_game!(game)
    raise ArgumentError, "game precisa ser um Game" unless game.is_a?(Game)
    raise ArgumentError, "A partida ainda não terminou" unless game.finished?
  end
end
