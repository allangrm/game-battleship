# frozen_string_literal: true

require "gosu"

# Tela textual temporária usada apenas para que as rotas do menu já funcionem
# antes da implementação das próximas views.
#
# @author Lívia Ferreira
# @version 1.0
class PlaceholderView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  BACK_X = 23
  BACK_Y = 30

  def initialize(window, title, message)
    @window = window
    @title = title
    @message = message

    @background = load_image("fundo_menu.png")
    @back_image = load_image("botao_voltar_play.png")

    # Fundos específicos podem ser carregados quando os novos assets existirem.
    # @ranking_background = load_image("fundo_ranking.png")
    # @instructions_background = load_image("fundo_instrucoes.png")

    @title_font = Gosu::Font.new(42)
    @message_font = Gosu::Font.new(24)
  end

  def draw
    @background.draw(0, 0, 0)
    @back_image.draw(BACK_X, BACK_Y, 1)
    draw_centered(@title_font, @title, 230, Gosu::Color::WHITE)
    draw_centered(@message_font, @message, 315, Gosu::Color::YELLOW)
  end

  def button_down(id, mouse_x, mouse_y)
    return go_back if id == Gosu::KB_ESCAPE
    return unless id == Gosu::MS_LEFT

    go_back if clicked_back?(mouse_x, mouse_y)
  end

  private

  def go_back
    @window.navigate_to(:menu)
  end

  def clicked_back?(mouse_x, mouse_y)
    mouse_x >= BACK_X &&
      mouse_x < BACK_X + @back_image.width &&
      mouse_y >= BACK_Y &&
      mouse_y < BACK_Y + @back_image.height
  end

  def draw_centered(font, text, y, color)
    x = (@window.width - font.text_width(text)) / 2
    font.draw_text(text, x, y, 2, 1, 1, color)
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
