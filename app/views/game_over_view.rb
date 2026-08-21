# frozen_string_literal: true

require "gosu"

# Exibe o resultado final já calculado pelo PostGameController. Em vitórias, o
# controller também entrega o identificador da partida persistida ou uma
# mensagem de erro caso o banco não tenha podido ser atualizado.
#
# @author Lívia Ferreira
# @version 1.0
class GameOverView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  BACK_X = 23
  BACK_Y = 30
  RANKING_X = 920
  RANKING_Y = 490
  RESULT_PANEL_X = 424
  RESULT_PANEL_Y = 285
  RESULT_PANEL_WIDTH = 560
  RESULT_PANEL_HEIGHT = 190
  RESULT_PANEL_COLOR = Gosu::Color.rgba(0, 0, 0, 155)

  attr_reader :game, :player, :score, :saved_match_id, :persistence_error

  def initialize(
    window,
    game:,
    player: nil,
    score:,
    saved_match_id: nil,
    persistence_error: nil
  )
    @window = window
    @game = game
    @player = player
    @score = score
    @saved_match_id = saved_match_id
    @persistence_error = persistence_error
    background_file = game.victory? ? "fundo_vitoria.png" : "fundo_derrota.png"
    @background = load_image(background_file)
    @back_image = load_image("botao_voltar_play.png")
    @ranking_image = load_image("botao_ranking.png")
    @text_font = Gosu::Font.new(26)
    @small_font = Gosu::Font.new(18)
  end

  def draw
    draw_background
    draw_result_panel
    @back_image.draw(BACK_X, BACK_Y, 4)
    @ranking_image.draw(RANKING_X, RANKING_Y, 4)

    draw_centered(@text_font, "Jogador: #{player.name}", 310, Gosu::Color::WHITE) if player
    draw_centered(@text_font, "Pontuação: #{score}", 355, Gosu::Color::YELLOW)
    draw_centered(@text_font, "Duração: #{game.duration_seconds}s", 400, Gosu::Color::WHITE)
    draw_persistence_status
  end

  def button_down(id, mouse_x, mouse_y)
    return go_back if id == Gosu::KB_ESCAPE
    return unless id == Gosu::MS_LEFT

    if inside_image?(@back_image, BACK_X, BACK_Y, mouse_x, mouse_y)
      go_back
    elsif inside_image?(@ranking_image, RANKING_X, RANKING_Y, mouse_x, mouse_y)
      @window.navigate_to(:ranking, map_type: game.map_type)
    end
  end

  private

  def draw_result_panel
    Gosu.draw_rect(
      RESULT_PANEL_X,
      RESULT_PANEL_Y,
      RESULT_PANEL_WIDTH,
      RESULT_PANEL_HEIGHT,
      RESULT_PANEL_COLOR,
      2
    )
  end

  def draw_persistence_status
    if persistence_error
      draw_centered(
        @small_font,
        "Pontuação calculada, mas não foi possível salvar: #{persistence_error}",
        450,
        Gosu::Color::RED
      )
    elsif saved_match_id
      draw_centered(@small_font, "Resultado salvo no ranking.", 450, Gosu::Color::GREEN)
    end
  end

  def go_back
    @window.navigate_to(:map_menu)
  end

  def draw_background
    scale_x = @window.width.to_f / @background.width
    scale_y = @window.height.to_f / @background.height
    @background.draw(0, 0, 0, scale_x, scale_y)
  end

  def draw_centered(font, text, y, color)
    x = (@window.width - font.text_width(text)) / 2
    font.draw_text(text, x, y, 3, 1, 1, color)
  end

  def inside_image?(image, x, y, mouse_x, mouse_y)
    mouse_x >= x && mouse_x < x + image.width &&
      mouse_y >= y && mouse_y < y + image.height
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
