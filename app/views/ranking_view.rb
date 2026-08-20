# frozen_string_literal: true

require "gosu"

# Tela visual do ranking. A listagem dos dados será integrada posteriormente;
# por enquanto, a view cuida do fundo e da navegação de retorno.
#
# @author Lívia Ferreira
# @version 1.1
class RankingView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  BACK_X = 23
  BACK_Y = 30
  HOVER_SCALE = 1.03
  HOVER_COLOR = Gosu::Color.rgba(255, 255, 190, 150)

  attr_reader :map_type

  def initialize(window, map_type: nil)
    @window = window
    @map_type = map_type&.to_sym
    @background = load_image("fundo_ranking.png")
    @back_image = load_image("botao_voltar_play.png")
    @back_button = { image: @back_image, x: BACK_X, y: BACK_Y }
  end

  def draw
    @background.draw(0, 0, 0)
    draw_back_button
  end

  def button_down(id, mouse_x, mouse_y)
    return go_back if id == Gosu::KB_ESCAPE
    return unless id == Gosu::MS_LEFT

    go_back if clicked_back?(mouse_x, mouse_y)
  end

  private

  def draw_back_button
    @back_image.draw(BACK_X, BACK_Y, 1)
    return unless clicked_back?(@window.mouse_x, @window.mouse_y)

    offset_x = @back_image.width * (HOVER_SCALE - 1) / 2
    offset_y = @back_image.height * (HOVER_SCALE - 1) / 2
    @back_image.draw(
      BACK_X - offset_x,
      BACK_Y - offset_y,
      2,
      HOVER_SCALE,
      HOVER_SCALE,
      HOVER_COLOR,
      :additive
    )
  end

  def clicked_back?(mouse_x, mouse_y)
    mouse_x >= @back_button[:x] &&
      mouse_x < @back_button[:x] + @back_image.width &&
      mouse_y >= @back_button[:y] &&
      mouse_y < @back_button[:y] + @back_image.height
  end

  def go_back
    @window.navigate_to(:menu)
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
