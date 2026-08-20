# frozen_string_literal: true

require "gosu"

# Contrato visual mínimo de pós-partida. Recebe Game e Player prontos para que
# a Pessoa 4 acrescente pontuação, persistência e apresentação final sem mudar
# o fluxo de navegação.
#
# @author Lívia Ferreira
# @version 1.0
class GameOverView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  BACK_X = 23
  BACK_Y = 30
  RANKING_X = 920
  RANKING_Y = 490

  attr_reader :game, :player

  def initialize(window, game:, player: nil)
    @window = window
    @game = game
    @player = player
    @background = load_image("fundo_ranking.png")
    @back_image = load_image("botao_voltar_play.png")
    @ranking_image = load_image("botao_ranking.png")
    @title_font = Gosu::Font.new(46)
    @text_font = Gosu::Font.new(26)
  end

  def draw
    draw_background
    @back_image.draw(BACK_X, BACK_Y, 4)
    @ranking_image.draw(RANKING_X, RANKING_Y, 4)

    result = game.victory? ? "VITÓRIA" : "DERROTA"
    color = game.victory? ? Gosu::Color::YELLOW : Gosu::Color::WHITE
    draw_centered(@title_font, result, 230, color)
    draw_centered(@text_font, "Jogador: #{player.name}", 310, Gosu::Color::WHITE) if player
    draw_centered(@text_font, "Duração: #{game.duration_seconds}s", 355, Gosu::Color::WHITE)
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
