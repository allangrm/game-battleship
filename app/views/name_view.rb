# frozen_string_literal: true

require "gosu"

# Solicita o nome do vencedor depois da partida, em estilo fliperama.
# A view valida apenas a interação; Player é criado pelo PostGameController.
#
# @author Lívia Ferreira
# @version 1.0
class NameView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  INPUT_X = 454
  INPUT_Y = 345
  INPUT_WIDTH = 500
  INPUT_HEIGHT = 58
  CONFIRM_X = 554
  CONFIRM_Y = 445
  CONFIRM_WIDTH = 300
  CONFIRM_HEIGHT = 56

  attr_reader :text_input

  def initialize(window, game:, on_submit:)
    raise ArgumentError, "on_submit precisa responder a #call" unless on_submit.respond_to?(:call)

    @window = window
    @game = game
    @on_submit = on_submit
    @text_input = Gosu::TextInput.new
    @message = ""
    @background = Gosu::Image.new(File.join(ASSET_PATH, "fundo_ranking.png"))
    @title_font = Gosu::Font.new(42)
    @text_font = Gosu::Font.new(26)
    @small_font = Gosu::Font.new(20)

    # @confirm_image = Gosu::Image.new(File.join(ASSET_PATH, "botao_confirmar_nome.png"))
  end

  def draw
    draw_background
    draw_centered(@title_font, "VITÓRIA!", 205, Gosu::Color::YELLOW)
    draw_centered(@text_font, "Digite o nome do vencedor", 275, Gosu::Color::WHITE)
    draw_input
    draw_confirm
    draw_centered(@small_font, @message, 530, Gosu::Color::YELLOW) unless @message.empty?
  end

  def button_down(id, mouse_x, mouse_y)
    return submit if id == Gosu::KB_RETURN || id == Gosu::KB_ENTER
    return unless id == Gosu::MS_LEFT

    submit if inside_confirm?(mouse_x, mouse_y)
  end

  private

  def draw_background
    scale_x = @window.width.to_f / @background.width
    scale_y = @window.height.to_f / @background.height
    @background.draw(0, 0, 0, scale_x, scale_y)
    Gosu.draw_rect(0, 0, @window.width, @window.height, Gosu::Color.rgba(0, 0, 0, 80), 1)
  end

  def draw_input
    Gosu.draw_rect(INPUT_X, INPUT_Y, INPUT_WIDTH, INPUT_HEIGHT, Gosu::Color.rgba(0, 0, 0, 210), 3)
    value = text_input.text.empty? ? "Seu nome" : text_input.text
    color = text_input.text.empty? ? Gosu::Color::GRAY : Gosu::Color::WHITE
    @text_font.draw_text(value, INPUT_X + 16, INPUT_Y + 14, 4, 1, 1, color)
  end

  def draw_confirm
    hovered = inside_confirm?(@window.mouse_x, @window.mouse_y)
    color = hovered ? Gosu::Color.rgba(180, 135, 20, 240) : Gosu::Color.rgba(35, 35, 35, 220)
    Gosu.draw_rect(CONFIRM_X, CONFIRM_Y, CONFIRM_WIDTH, CONFIRM_HEIGHT, color, 3)
    label = "CONFIRMAR"
    x = CONFIRM_X + ((CONFIRM_WIDTH - @text_font.text_width(label)) / 2)
    @text_font.draw_text(label, x, CONFIRM_Y + 14, 4, 1, 1, Gosu::Color::WHITE)
  end

  def submit
    @on_submit.call(text_input.text)
  rescue ArgumentError => error
    @message = error.message
  end

  def inside_confirm?(mouse_x, mouse_y)
    mouse_x >= CONFIRM_X && mouse_x < CONFIRM_X + CONFIRM_WIDTH &&
      mouse_y >= CONFIRM_Y && mouse_y < CONFIRM_Y + CONFIRM_HEIGHT
  end

  def draw_centered(font, text, y, color)
    x = (@window.width - font.text_width(text)) / 2
    font.draw_text(text, x, y, 3, 1, 1, color)
  end
end
