# frozen_string_literal: true

require "gosu"

class GameView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  BACKGROUND_FILES = {
    poca: "mapa_poca.jpeg",
    lago: "mapa_lago.png",
    oceano: "fundo_jogo.png"
  }.freeze

  CELL_SIZES = {
    5 => 76,
    8 => 54,
    10 => 46
  }.freeze

  BOARD_GAP = 110
  BOARD_TOP = 190

  BACK_X = 23
  BACK_Y = 30

  WATER_COLOR = Gosu::Color.rgb(38, 117, 176)
  SHIP_COLOR = Gosu::Color.rgb(105, 105, 105)
  GRID_COLOR = Gosu::Color.rgba(255, 255, 255, 180)
  PAINEL_COLOR = Gosu::Color.rgba(0, 0, 0, 50)
  COR_DO_TEXTO = Gosu::Color::WHITE
  COR_DA_SELECAO = Gosu::Color.rgba(255, 215, 0, 100)

  def initialize(window, controller, map_type:)
    @window = window
    @controller = controller
    @map_type = map_type

    @background = load_background(map_type)
    @back_image = Gosu::Image.new(
      File.join(ASSET_PATH, "botao_voltar_play.png")
    )
    @title_font = Gosu::Font.new(26)
    @coordinate_font = Gosu::Font.new(18)
    @selected_enemy_coordinate = nil
  end

  def draw
    draw_background

    player_board = @controller.game.player_board
    enemy_board = @controller.game.enemy_board

    player_x, enemy_x = board_origins(player_board.size)

    draw_board(
      player_board,
      player_x,
      BOARD_TOP,
      "SEU TABULEIRO",
      reveal_ships: true
    )

    draw_board(
      enemy_board,
      enemy_x,
      BOARD_TOP,
      "TABULEIRO INIMIGO",
      reveal_ships: false
    )

    draw_selected_enemy_cell(
      enemy_board,
      enemy_x,
      BOARD_TOP
    )

    draw_back_button
  end

  def button_down(id, mouse_x, mouse_y)
    if id == Gosu::KB_ESCAPE
      go_back
      return
    end

    return unless id == Gosu::MS_LEFT

    if clicked_back_button?(mouse_x, mouse_y)
      go_back
      return
    end

    handle_enemy_board_click(mouse_x, mouse_y)
  end

  private

  def draw_back_button
    @back_image.draw(
      BACK_X,
      BACK_Y,
      5
    )
  end

  def go_back
    @window.navigate_to(:map_menu)
  end

  def clicked_back_button?(mouse_x, mouse_y)
    mouse_x >= BACK_X &&
      mouse_x < BACK_X + @back_image.width &&
      mouse_y >= BACK_Y &&
      mouse_y < BACK_Y + @back_image.height
  end

  def load_background(map_type)
    file_name = BACKGROUND_FILES.fetch(map_type) do
      raise ArgumentError, "Fundo não encontrado para o mapa: #{map_type}"
    end

    Gosu::Image.new(
      File.join(ASSET_PATH, file_name)
    )
  end

  def draw_background
    scale_x = @window.width.to_f / @background.width
    scale_y = @window.height.to_f / @background.height

    @background.draw(
      0,
      0,
      0,
      scale_x,
      scale_y
    )
  end

  def cell_size(board_size)
    CELL_SIZES.fetch(board_size)
  end

  def board_origins(board_size)
    current_cell_size = cell_size(board_size)
    board_width = board_size * current_cell_size
    total_width = (board_width * 2) + BOARD_GAP

    player_x = (@window.width - total_width) / 2
    enemy_x = player_x + board_width + BOARD_GAP

    [player_x, enemy_x]
  end

  def draw_board(board, x, y, title, reveal_ships:)
    current_cell_size = cell_size(board.size)
    board_width = board.size * current_cell_size

    draw_board_panel(x, y, board_width)
    draw_centered_title(title, x, y - 67, board_width)
    draw_coordinates(board, x, y, current_cell_size)

    board.grid.each do |row|
      row.each do |cell|
        draw_cell(
          cell,
          x,
          y,
          current_cell_size,
          reveal_ships
        )
      end
    end
  end

  def draw_board_panel(x, y, board_width)
    panel_x = x - 40
    panel_y = y - 80
    panel_width = board_width + 52
    panel_height = board_width + 94

    Gosu.draw_rect(
      panel_x,
      panel_y,
      panel_width,
      panel_height,
      PAINEL_COLOR,
      1
    )
  end

  def draw_coordinates(board, board_x, board_y, current_cell_size)
    board.size.times do |index|
      draw_column_coordinate(
        index,
        board_x,
        board_y,
        current_cell_size
      )

      draw_row_coordinate(
        index,
        board_x,
        board_y,
        current_cell_size
      )
    end
  end

  def draw_column_coordinate(col, board_x, board_y, current_cell_size)
    letter = ("A".ord + col).chr
    cell_x = board_x + (col * current_cell_size)

    text_width = @coordinate_font.text_width(letter)
    text_x = cell_x + ((current_cell_size - text_width) / 2)
    text_y = board_y - 27

    @coordinate_font.draw_text(
      letter,
      text_x,
      text_y,
      3,
      1,
      1,
      COR_DO_TEXTO
    )
  end

  def draw_row_coordinate(row, board_x, board_y, current_cell_size)
    number = (row + 1).to_s
    cell_y = board_y + (row * current_cell_size)

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
      COR_DO_TEXTO
    )
  end

  def draw_cell(
    cell,
    board_x,
    board_y,
    current_cell_size,
    reveal_ships
  )
    cell_x = board_x + (cell.col * current_cell_size)
    cell_y = board_y + (cell.row * current_cell_size)

    color =
      if reveal_ships && cell.occupied?
        SHIP_COLOR
      else
        WATER_COLOR
      end

    Gosu.draw_rect(
      cell_x,
      cell_y,
      current_cell_size,
      current_cell_size,
      color,
      2
    )

    draw_cell_border(
      cell_x,
      cell_y,
      current_cell_size
    )
  end

  def draw_centered_title(text, x, y, width)
    text_x = x + ((width - @title_font.text_width(text)) / 2)

    @title_font.draw_text(
      text,
      text_x,
      y,
      3,
      1,
      1,
      COR_DO_TEXTO
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

  def handle_enemy_board_click(mouse_x, mouse_y)
    enemy_board = @controller.game.enemy_board
    _player_x, enemy_x = board_origins(enemy_board.size)

    coordinate = board_coordinate_at(
      mouse_x,
      mouse_y,
      enemy_board,
      enemy_x,
      BOARD_TOP
    )

    return unless coordinate

    @selected_enemy_coordinate = coordinate

    row, col = coordinate
    letter = ("A".ord + col).chr
    displayed_row = row + 1

    puts "Célula inimiga selecionada: #{letter}#{displayed_row}"
    puts "Linha interna: #{row}, coluna interna: #{col}"
  end

  def board_coordinate_at(mouse_x, mouse_y, board, board_x, board_y)
    current_cell_size = cell_size(board.size)
    board_width = board.size * current_cell_size
    board_height = board.size * current_cell_size

    inside_horizontal =
      mouse_x >= board_x &&
      mouse_x < board_x + board_width

    inside_vertical =
      mouse_y >= board_y &&
      mouse_y < board_y + board_height

    return nil unless inside_horizontal && inside_vertical

    col = ((mouse_x - board_x) / current_cell_size).floor
    row = ((mouse_y - board_y) / current_cell_size).floor

    [row, col]
  end

  def draw_selected_enemy_cell(board, board_x, board_y)
    return unless @selected_enemy_coordinate

    row, col = @selected_enemy_coordinate
    current_cell_size = cell_size(board.size)

    cell_x = board_x + (col * current_cell_size)
    cell_y = board_y + (row * current_cell_size)

    Gosu.draw_rect(
      cell_x,
      cell_y,
      current_cell_size,
      current_cell_size,
      COR_DA_SELECAO,
      4
    )
  end
end