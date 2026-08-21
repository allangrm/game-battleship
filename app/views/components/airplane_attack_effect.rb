# frozen_string_literal: true

require "gosu"
require_relative "board_renderer"

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

  def active?
    !@effect.nil?
  end

  def update
    return unless active?

    @effect = nil if elapsed_ms >= DURATION_MS
  end

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

  def elapsed_ms
    @clock.call - @effect.started_at
  end

  def progress
    [[elapsed_ms.to_f / DURATION_MS, 0.0].max, 1.0].min
  end

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

  def draw_trail(x, y)
    if @effect.orientation == :row
      @line_drawer.call(x - TRAIL_LENGTH, y, TRAIL_COLOR, x - 15, y, TRAIL_COLOR, 7)
    else
      @line_drawer.call(x, y + TRAIL_LENGTH, TRAIL_COLOR, x, y + 15, TRAIL_COLOR, 7)
    end
  end
end
