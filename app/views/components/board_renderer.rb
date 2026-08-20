# frozen_string_literal: true

require "gosu"

class BoardRenderer
  CELL_SIZES = {
    5 => 76,
    8 => 54,
    10 => 46
  }.freeze

  BOARD_GAP = 110
  BOARD_TOP = 190

  MISS_COLOR = Gosu::Color.rgb(85, 205, 255)
  HIT_COLOR = Gosu::Color.rgb(220, 45, 45)
  SUNK_COLOR = Gosu::Color.rgb(255, 130, 25)

  WATER_COLOR = Gosu::Color.rgb(38, 117, 176)
  SHIP_COLOR = Gosu::Color.rgb(105, 105, 105)
  GRID_COLOR = Gosu::Color.rgba(255, 255, 255, 180)
  PANEL_COLOR = Gosu::Color.rgba(0, 0, 0, 50)
  TEXT_COLOR = Gosu::Color::WHITE
  SELECTION_COLOR = Gosu::Color.rgba(255, 215, 0, 100)

  MARK_COLOR = Gosu::Color::WHITE
  SUNK_MARK_COLOR = Gosu::Color.rgb(80, 30, 10)

  def initialize(window)
    @window = window
    @title_font = Gosu::Font.new(26)
    @coordinate_font = Gosu::Font.new(18)
  end

  def origins(board_size)
    current_cell_size = cell_size(board_size)
    board_width = board_size * current_cell_size
    total_width = (board_width * 2) + BOARD_GAP

    player_x = (@window.width - total_width) / 2
    enemy_x = player_x + board_width + BOARD_GAP

    [player_x, enemy_x]
  end

  def draw(board, x, title:, reveal_ships:)
    current_cell_size = cell_size(board.size)
    board_width = board.size * current_cell_size

    draw_panel(x, board_width)
    draw_title(title, x, board_width)
    draw_coordinates(board, x, current_cell_size)

    board.grid.each do |row|
      row.each do |cell|
        draw_cell(
          cell,
          x,
          current_cell_size,
          reveal_ships
        )
      end
    end
  end

  def coordinate_at(mouse_x, mouse_y, board, board_x)
    current_cell_size = cell_size(board.size)
    board_width = board.size * current_cell_size
    board_height = board.size * current_cell_size

    inside_horizontal =
      mouse_x >= board_x &&
      mouse_x < board_x + board_width

    inside_vertical =
      mouse_y >= BOARD_TOP &&
      mouse_y < BOARD_TOP + board_height

    return nil unless inside_horizontal && inside_vertical

    col = ((mouse_x - board_x) / current_cell_size).floor
    row = ((mouse_y - BOARD_TOP) / current_cell_size).floor

    [row, col]
  end

  def draw_selection(board, board_x, coordinate)
    return unless coordinate

    row, col = coordinate
    current_cell_size = cell_size(board.size)

    cell_x = board_x + (col * current_cell_size)
    cell_y = BOARD_TOP + (row * current_cell_size)

    Gosu.draw_rect(
      cell_x,
      cell_y,
      current_cell_size,
      current_cell_size,
      SELECTION_COLOR,
      4
    )
  end

  private

  def cell_size(board_size)
    CELL_SIZES.fetch(board_size)
  end

  def draw_panel(x, board_width)
    panel_x = x - 40
    panel_y = BOARD_TOP - 80
    panel_width = board_width + 52
    panel_height = board_width + 94

    Gosu.draw_rect(
      panel_x,
      panel_y,
      panel_width,
      panel_height,
      PANEL_COLOR,
      1
    )
  end

  def draw_title(title, x, board_width)
    text_x =
      x +
      ((board_width - @title_font.text_width(title)) / 2)

    @title_font.draw_text(
      title,
      text_x,
      BOARD_TOP - 67,
      3,
      1,
      1,
      TEXT_COLOR
    )
  end

  def draw_coordinates(board, board_x, current_cell_size)
    board.size.times do |index|
      draw_column_coordinate(
        index,
        board_x,
        current_cell_size
      )

      draw_row_coordinate(
        index,
        board_x,
        current_cell_size
      )
    end
  end

  def draw_column_coordinate(col, board_x, current_cell_size)
    letter = ("A".ord + col).chr
    cell_x = board_x + (col * current_cell_size)

    text_width = @coordinate_font.text_width(letter)
    text_x = cell_x + ((current_cell_size - text_width) / 2)
    text_y = BOARD_TOP - 27

    @coordinate_font.draw_text(
      letter,
      text_x,
      text_y,
      3,
      1,
      1,
      TEXT_COLOR
    )
  end

  def draw_row_coordinate(row, board_x, current_cell_size)
    number = (row + 1).to_s
    cell_y = BOARD_TOP + (row * current_cell_size)

    text_width = @coordinate_font.text_width(number)
    text_x = board_x - text_width - 12
    text_y =
      cell_y +
      ((current_cell_size - @coordinate_font.height) / 2)

    @coordinate_font.draw_text(
      number,
      text_x,
      text_y,
      3,
      1,
      1,
      TEXT_COLOR
    )
  end

  def draw_cell(cell, board_x, current_cell_size, reveal_ships)
    cell_x = board_x + (cell.col * current_cell_size)
    cell_y = BOARD_TOP + (cell.row * current_cell_size)

    color = cell_color(cell, reveal_ships)

    Gosu.draw_rect(
      cell_x,
      cell_y,
      current_cell_size,
      current_cell_size,
      color,
      2
    )

    draw_cell_status(
      cell,
      cell_x,
      cell_y,
      current_cell_size
    )

    draw_cell_border(
      cell_x,
      cell_y,
      current_cell_size
    )
  end

  def draw_cell_border(x, y, current_cell_size)
    right = x + current_cell_size
    bottom = y + current_cell_size

    Gosu.draw_line(x, y, GRID_COLOR, right, y, GRID_COLOR, 3)
    Gosu.draw_line(x, y, GRID_COLOR, x, bottom, GRID_COLOR, 3)
    Gosu.draw_line(right, y, GRID_COLOR, right, bottom, GRID_COLOR, 3)
    Gosu.draw_line(x, bottom, GRID_COLOR, right, bottom, GRID_COLOR, 3)
  end

  def cell_color(cell, reveal_ships)
    case cell.status
    when :miss
      MISS_COLOR
    when :hit
      HIT_COLOR
    when :sunk
      SUNK_COLOR
    else
      if reveal_ships && cell.occupied?
        SHIP_COLOR
      else
        WATER_COLOR
      end
    end
  end

  def draw_cell_status(cell, x, y, current_cell_size)
    case cell.status
    when :miss
      draw_miss_marker(x, y, current_cell_size)
    when :hit
      draw_x_marker(
        x,
        y,
        current_cell_size,
        MARK_COLOR
      )
    when :sunk
      draw_x_marker(
        x,
        y,
        current_cell_size,
        SUNK_MARK_COLOR,
        thickness: 2
      )
    end
  end

  def draw_miss_marker(x, y, current_cell_size)
    marker_size = [current_cell_size * 0.16, 7].max

    marker_x = x + ((current_cell_size - marker_size) / 2)
    marker_y = y + ((current_cell_size - marker_size) / 2)

    Gosu.draw_rect(
      marker_x,
      marker_y,
      marker_size,
      marker_size,
      MARK_COLOR,
      4
    )
  end

  def draw_x_marker(
    x,
    y,
    current_cell_size,
    color,
    thickness: 1
  )
    inset = current_cell_size * 0.25

    left = x + inset
    right = x + current_cell_size - inset
    top = y + inset
    bottom = y + current_cell_size - inset

    (-thickness..thickness).each do |offset|
      Gosu.draw_line(
        left + offset,
        top,
        color,
        right + offset,
        bottom,
        color,
        4
      )

      Gosu.draw_line(
        right + offset,
        top,
        color,
        left + offset,
        bottom,
        color,
        4
      )
    end
  end
end