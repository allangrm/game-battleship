# frozen_string_literal: true

require "gosu"
require_relative "board_renderer"

# Desenha o avião passando pela linha ou coluna escolhida pelo jogador.
# O efeito é apenas visual e não altera o resultado do ataque.
#
# @author Raffael Wagner
# @version 1.0
class AirplaneAttackEffect
  DURATION_MS = 800
  SPRITE_SIZE = 72
  PATH_MARGIN = 45
  TRAIL_LENGTH = 65
  TRAIL_COLOR = Gosu::Color.rgba(230, 240, 255, 150)

  Effect = Struct.new(
    :board_size,
    :board_x,
    :row,
    :col,
    :orientation,
    :started_at,
    keyword_init: true
  )

  # Prepara o efeito visual do Avião.
  # Os argumentos de relógio e desenho facilitam os testes sem abrir uma janela.
  #
  # @param image [Gosu::Image] sprite do avião
  # @param clock [#call] objeto que devolve o tempo atual em milissegundos
  # @param line_drawer [#call] função usada para desenhar o rastro
  # @return [AirplaneAttackEffect] efeito criado
  def initialize(
    image,
    clock: -> { Gosu.milliseconds },
    line_drawer: ->(*arguments) { Gosu.draw_line(*arguments) }
  )
    @image = image
    @clock = clock
    @line_drawer = line_drawer
    @effect = nil
  end

  # Inicia uma nova passagem do avião no tabuleiro inimigo.
  #
  # @param board_size [Integer] quantidade de linhas e colunas do tabuleiro
  # @param board_x [Numeric] posição horizontal onde o tabuleiro começa
  # @param row [Integer] linha escolhida
  # @param col [Integer] coluna escolhida
  # @param orientation [Symbol] direção do ataque, :row ou :col
  # @return [Effect] dados do efeito iniciado
  # @raise [ArgumentError] quando a orientação é inválida
  def start(board_size:, board_x:, row:, col:, orientation:)
    unless %i[row col].include?(orientation)
      raise ArgumentError, "Orientação inválida para o avião: #{orientation.inspect}"
    end

    @effect = Effect.new(
      board_size: board_size,
      board_x: board_x,
      row: row,
      col: col,
      orientation: orientation,
      started_at: @clock.call
    )
  end

  # Informa se existe uma animação acontecendo neste momento.
  #
  # @return [Boolean] true enquanto o avião estiver na tela
  def active?
    !@effect.nil?
  end

  # Atualiza o tempo da animação e encerra o efeito quando ele termina.
  #
  # @return [void]
  def update
    return unless active?

    @effect = nil if elapsed_ms >= DURATION_MS
  end

  # Desenha o avião e seu rastro na posição atual.
  #
  # @return [void]
  def draw
    return unless active?

    x, y, angle = current_position
    draw_trail(x, y)

    scale = SPRITE_SIZE.to_f / [@image.width, @image.height].max
    @image.draw_rot(
      x,
      y,
      8,
      angle,
      0.5,
      0.5,
      scale,
      scale,
      Gosu::Color::WHITE
    )
  end

  private

  # Calcula há quantos milissegundos o efeito começou.
  #
  # @return [Numeric] tempo decorrido em milissegundos
  def elapsed_ms
    @clock.call - @effect.started_at
  end

  # Converte o tempo decorrido em um valor entre 0 e 1.
  #
  # @return [Float] progresso atual da animação
  def progress
    [[elapsed_ms.to_f / DURATION_MS, 0.0].max, 1.0].min
  end

  # Calcula a posição e a rotação do avião no frame atual.
  #
  # @return [Array<Numeric>] posição x, posição y e ângulo do sprite
  def current_position
    cell_size = BoardRenderer::CELL_SIZES.fetch(@effect.board_size)
    board_length = @effect.board_size * cell_size
    path_length = board_length + (PATH_MARGIN * 2)

    if @effect.orientation == :row
      x = @effect.board_x - PATH_MARGIN + (path_length * progress)
      y = BoardRenderer::BOARD_TOP + (@effect.row * cell_size) + (cell_size / 2.0)
      [x, y, 90]
    else
      x = @effect.board_x + (@effect.col * cell_size) + (cell_size / 2.0)
      y = BoardRenderer::BOARD_TOP + board_length + PATH_MARGIN - (path_length * progress)
      [x, y, 0]
    end
  end

  # Desenha uma linha clara atrás do avião para representar o rastro.
  #
  # @param x [Numeric] posição horizontal atual do avião
  # @param y [Numeric] posição vertical atual do avião
  # @return [void]
  def draw_trail(x, y)
    if @effect.orientation == :row
      @line_drawer.call(x - TRAIL_LENGTH, y, TRAIL_COLOR, x - 15, y, TRAIL_COLOR, 7)
    else
      @line_drawer.call(x, y + TRAIL_LENGTH, TRAIL_COLOR, x, y + 15, TRAIL_COLOR, 7)
    end
  end
end
