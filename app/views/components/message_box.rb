# frozen_string_literal: true

require "gosu"

# Mostra as mensagens mais recentes da partida em uma caixa na tela.
# O componente limita a quantidade de textos para não ocupar muito espaço.
#
# @author Raffael Wagner
# @version 1.0
class MessageBox
  DEFAULT_WIDTH = 900
  DEFAULT_HEIGHT = 80
  DEFAULT_BOTTOM_MARGIN = 12
  DEFAULT_MESSAGE_LIMIT = 3

  BACKGROUND_COLOR = Gosu::Color.rgba(0, 0, 0, 190)
  BORDER_COLOR = Gosu::Color.rgba(255, 255, 255, 180)
  TEXT_COLOR = Gosu::Color::WHITE

  # Cria a caixa que mostra as últimas mensagens da partida.
  #
  # @param window [Gosu::Window] janela usada para calcular a posição
  # @param width [Integer] largura da caixa
  # @param height [Integer] altura da caixa
  # @param bottom_margin [Integer] distância até a parte inferior da janela
  # @param message_limit [Integer] quantidade máxima de mensagens visíveis
  # @return [MessageBox] caixa criada
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

  # Adiciona uma mensagem e remove as mais antigas quando passa do limite.
  #
  # @param message [String] texto que será exibido
  # @return [Array<String>] mensagens mantidas na caixa
  def add(message)
    @messages << message
    @messages = @messages.last(@message_limit)
  end

  # Desenha o fundo, a borda e as mensagens.
  #
  # @return [void]
  def draw
    x = (@window.width - @width) / 2
    y = @window.height - @height - @bottom_margin

    draw_background(x, y)
    draw_border(x, y)
    draw_messages(x, y)
  end

  private

  # Desenha o retângulo escuro usado como fundo.
  #
  # @param x [Numeric] posição horizontal da caixa
  # @param y [Numeric] posição vertical da caixa
  # @return [void]
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

  # Desenha as quatro linhas da borda da caixa.
  #
  # @param x [Numeric] posição horizontal da caixa
  # @param y [Numeric] posição vertical da caixa
  # @return [void]
  def draw_border(x, y)
    right = x + @width
    bottom = y + @height

    Gosu.draw_line(x, y, BORDER_COLOR, right, y, BORDER_COLOR, 6)
    Gosu.draw_line(x, y, BORDER_COLOR, x, bottom, BORDER_COLOR, 6)
    Gosu.draw_line(right, y, BORDER_COLOR, right, bottom, BORDER_COLOR, 6)
    Gosu.draw_line(x, bottom, BORDER_COLOR, right, bottom, BORDER_COLOR, 6)
  end

  # Desenha cada mensagem dentro da caixa.
  #
  # @param x [Numeric] posição horizontal da caixa
  # @param y [Numeric] posição vertical da caixa
  # @return [void]
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
