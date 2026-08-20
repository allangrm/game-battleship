# frozen_string_literal: true

require "gosu"

class MessageBox
  DEFAULT_WIDTH = 900
  DEFAULT_HEIGHT = 80
  DEFAULT_BOTTOM_MARGIN = 12
  DEFAULT_MESSAGE_LIMIT = 3

  BACKGROUND_COLOR = Gosu::Color.rgba(0, 0, 0, 190)
  BORDER_COLOR = Gosu::Color.rgba(255, 255, 255, 180)
  TEXT_COLOR = Gosu::Color::WHITE

  def initialize(
    window,
    width: DEFAULT_WIDTH,
    height: DEFAULT_HEIGHT,
    bottom_margin: DEFAULT_BOTTOM_MARGIN,
    message_limit: DEFAULT_MESSAGE_LIMIT
  )
    @window = window
    @width = width
    @height = height
    @bottom_margin = bottom_margin
    @message_limit = message_limit

    @font = Gosu::Font.new(18)

    @messages = [
      "Selecione uma célula do tabuleiro inimigo."
    ]
  end

  def add(message)
    @messages << message
    @messages = @messages.last(@message_limit)
  end

  def draw
    x = (@window.width - @width) / 2
    y = @window.height - @height - @bottom_margin

    draw_background(x, y)
    draw_border(x, y)
    draw_messages(x, y)
  end

  private

  def draw_background(x, y)
    Gosu.draw_rect(
      x,
      y,
      @width,
      @height,
      BACKGROUND_COLOR,
      5
    )
  end

  def draw_border(x, y)
    right = x + @width
    bottom = y + @height

    Gosu.draw_line(x, y, BORDER_COLOR, right, y, BORDER_COLOR, 6)
    Gosu.draw_line(x, y, BORDER_COLOR, x, bottom, BORDER_COLOR, 6)
    Gosu.draw_line(right, y, BORDER_COLOR, right, bottom, BORDER_COLOR, 6)
    Gosu.draw_line(x, bottom, BORDER_COLOR, right, bottom, BORDER_COLOR, 6)
  end

  def draw_messages(x, y)
    @messages.each_with_index do |message, index|
      @font.draw_text(
        message,
        x + 14,
        y + 9 + (index * 22),
        6,
        1,
        1,
        TEXT_COLOR
      )
    end
  end
end