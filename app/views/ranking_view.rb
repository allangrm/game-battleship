# frozen_string_literal: true

require "gosu"
require_relative "../controllers/ranking_controller"

# Tela visual do ranking. A listagem dos dados será integrada posteriormente;
# por enquanto, a view cuida do fundo e da navegação de retorno.
#
# @author Lívia Ferreira
# @version 1.1
class RankingView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  BACK_X = 23
  BACK_Y = 30

  MAP_LABELS = {
    poca: "POÇA",
    lago: "LAGO",
    oceano: "OCEANO"
  }.freeze

  TAB_Y = 135
  TAB_WIDTH = 180
  TAB_HEIGHT = 44
  TAB_GAP = 20

  TABLE_X = 260
  TABLE_Y = 205
  TABLE_WIDTH = 888
  TABLE_HEIGHT = 450
  ROW_HEIGHT = 36
  FIRST_ROW_Y = 260

  PANEL_COLOR = Gosu::Color.rgba(20, 10, 5, 185)
  HEADER_COLOR = Gosu::Color.rgba(90, 50, 20, 230)
  ROW_COLOR = Gosu::Color.rgba(40, 25, 15, 170)
  ALTERNATE_ROW_COLOR = Gosu::Color.rgba(70, 40, 20, 170)

  TAB_COLOR = Gosu::Color.rgba(55, 35, 20, 220)
  TAB_HOVER_COLOR = Gosu::Color.rgba(120, 75, 25, 235)
  TAB_SELECTED_COLOR = Gosu::Color.rgba(175, 115, 30, 245)

  TEXT_COLOR = Gosu::Color::WHITE
  HIGHLIGHT_COLOR = Gosu::Color::YELLOW

  HOVER_SCALE = 1.03
  HOVER_COLOR = Gosu::Color.rgba(255, 255, 190, 150)

  attr_reader :controller

  def initialize(window, controller)
    unless controller.is_a?(RankingController)
      raise ArgumentError, "controller precisa ser um RankingController"
    end

    @window = window
    @controller = controller

    @background = load_image("fundo_ranking.png")
    @back_image = load_image("botao_voltar_play.png")
    @back_button = {
      image: @back_image,
      x: BACK_X,
      y: BACK_Y
    }

    @title_font = Gosu::Font.new(38)
    @text_font = Gosu::Font.new(22)
    @small_font = Gosu::Font.new(18)

    configure_map_buttons
  end

  def draw
    draw_background
    draw_back_button
    draw_title
    draw_map_buttons
    draw_ranking_table
  end

  def button_down(id, mouse_x, mouse_y)
    return go_back if id == Gosu::KB_ESCAPE
    return unless id == Gosu::MS_LEFT

    if clicked_back?(mouse_x, mouse_y)
      go_back
      return
    end

    selected_map = map_button_at(mouse_x, mouse_y)
    controller.select_map(selected_map) if selected_map
  end

  def map_type
    controller.map_type
  end

  private

  def configure_map_buttons
    total_width =
      (MAP_LABELS.length * TAB_WIDTH) +
      ((MAP_LABELS.length - 1) * TAB_GAP)

    start_x = (@window.width - total_width) / 2

    @map_buttons = MAP_LABELS.keys.each_with_index.to_h do |map, index|
      [
        map,
        {
          x: start_x + (index * (TAB_WIDTH + TAB_GAP)),
          y: TAB_Y,
          width: TAB_WIDTH,
          height: TAB_HEIGHT
        }
      ]
    end
  end

  def draw_background
    scale_x = @window.width.to_f / @background.width
    scale_y = @window.height.to_f / @background.height

    @background.draw(0, 0, 0, scale_x, scale_y)
  end

  def draw_title
    draw_centered_text(
      @title_font,
      "HIGH SCORES",
      70,
      Gosu::Color.rgb(65, 30, 15),
      3
    )
  end

  def draw_map_buttons
    @map_buttons.each do |map, button|
      color =
        if map == map_type
          TAB_SELECTED_COLOR
        elsif inside_button?(button, @window.mouse_x, @window.mouse_y)
          TAB_HOVER_COLOR
        else
          TAB_COLOR
        end

      Gosu.draw_rect(
        button[:x],
        button[:y],
        button[:width],
        button[:height],
        color,
        3
      )

      label = MAP_LABELS.fetch(map)
      text_x =
        button[:x] +
        ((button[:width] - @text_font.text_width(label)) / 2)

      @text_font.draw_text(
        label,
        text_x,
        button[:y] + 10,
        4,
        1,
        1,
        TEXT_COLOR
      )
    end
  end

  def draw_ranking_table
    Gosu.draw_rect(
      TABLE_X,
      TABLE_Y,
      TABLE_WIDTH,
      TABLE_HEIGHT,
      PANEL_COLOR,
      2
    )

    draw_table_header

    if controller.entries.empty?
      draw_centered_text(
        @text_font,
        "Ainda não existem resultados para este mapa.",
        380,
        TEXT_COLOR,
        4
      )
      return
    end

    controller.entries.each_with_index do |entry, index|
      draw_ranking_entry(entry, index)
    end
  end

  def draw_table_header
    Gosu.draw_rect(
      TABLE_X + 15,
      TABLE_Y + 15,
      TABLE_WIDTH - 30,
      ROW_HEIGHT,
      HEADER_COLOR,
      3
    )

    draw_columns(
      position: "POS.",
      name: "JOGADOR",
      score: "PONTOS",
      duration: "TEMPO",
      y: TABLE_Y + 23,
      font: @small_font,
      color: HIGHLIGHT_COLOR
    )
  end

  def draw_ranking_entry(entry, index)
    y = FIRST_ROW_Y + (index * ROW_HEIGHT)

    row_color =
      index.even? ? ROW_COLOR : ALTERNATE_ROW_COLOR

    Gosu.draw_rect(
      TABLE_X + 15,
      y,
      TABLE_WIDTH - 30,
      ROW_HEIGHT - 2,
      row_color,
      3
    )

    draw_columns(
      position: (index + 1).to_s,
      name: shortened_name(entry[:name]),
      score: entry[:score].to_s,
      duration: format_duration(entry[:duration_seconds]),
      y: y + 7,
      font: @small_font,
      color: TEXT_COLOR
    )
  end

  def draw_columns(position:, name:, score:, duration:, y:, font:, color:)
    font.draw_text(position, TABLE_X + 35, y, 4, 1, 1, color)
    font.draw_text(name, TABLE_X + 130, y, 4, 1, 1, color)
    font.draw_text(score, TABLE_X + 560, y, 4, 1, 1, color)
    font.draw_text(duration, TABLE_X + 735, y, 4, 1, 1, color)
  end

  def shortened_name(name)
    value = name.to_s
    return value if value.length <= 24

    "#{value[0, 21]}..."
  end

  def format_duration(seconds)
    total_seconds = seconds.to_i
    minutes = total_seconds / 60
    remaining_seconds = total_seconds % 60

    format("%02d:%02d", minutes, remaining_seconds)
  end

  def map_button_at(mouse_x, mouse_y)
    match = @map_buttons.find do |_map, button|
      inside_button?(button, mouse_x, mouse_y)
    end

    match&.first
  end

  def inside_button?(button, mouse_x, mouse_y)
    mouse_x >= button[:x] &&
      mouse_x < button[:x] + button[:width] &&
      mouse_y >= button[:y] &&
      mouse_y < button[:y] + button[:height]
  end

  def draw_back_button
    @back_image.draw(BACK_X, BACK_Y, 4)
    return unless clicked_back?(@window.mouse_x, @window.mouse_y)

    offset_x = @back_image.width * (HOVER_SCALE - 1) / 2
    offset_y = @back_image.height * (HOVER_SCALE - 1) / 2

    @back_image.draw(
      BACK_X - offset_x,
      BACK_Y - offset_y,
      5,
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

  def draw_centered_text(font, text, y, color, z)
    x = (@window.width - font.text_width(text)) / 2
    font.draw_text(text, x, y, z, 1, 1, color)
  end

  def go_back
    @window.navigate_to(:menu)
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
