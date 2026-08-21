# frozen_string_literal: true

require "gosu"
require_relative "components/board_renderer"

# Tela de preparação: seleciona o modo de turno e posiciona a frota manual ou
# automaticamente. Toda alteração do domínio passa pelo SetupController.
#
# @author Lívia Ferreira
# @version 1.3
class SetupView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  BACKGROUND_FILES = {
    poca: "mapa_poca.jpeg",
    lago: "mapa_lago.png",
    oceano: "mapa_oceano.png"
  }.freeze

  BACK_X = 23
  BACK_Y = 30
  CONTROL_X = 760
  CONTROL_WIDTH = 560
  CONTROL_HEIGHT = 48
  CONTROL_GAP = 14
  CONTROL_START_Y = 175
  PREVIEW_X = CONTROL_X
  PREVIEW_Y = 45
  PREVIEW_WIDTH = CONTROL_WIDTH
  PREVIEW_HEIGHT = 110
  PREVIEW_IMAGE_X = PREVIEW_X + 240
  PREVIEW_IMAGE_Y = PREVIEW_Y + 16
  PREVIEW_IMAGE_WIDTH = 296
  PREVIEW_IMAGE_HEIGHT = 78

  NORMAL_COLOR = Gosu::Color.rgba(30, 30, 30, 210)
  HOVER_COLOR = Gosu::Color.rgba(120, 90, 20, 230)
  SELECTED_COLOR = Gosu::Color.rgba(170, 125, 20, 235)
  DISABLED_COLOR = Gosu::Color.rgba(55, 55, 55, 170)
  TEXT_COLOR = Gosu::Color::WHITE
  MESSAGE_COLOR = Gosu::Color::YELLOW

  def initialize(window, controller)
    @window = window
    @controller = controller
    @orientation = :horizontal
    @message = "Escolha o modo e posicione o primeiro navio."
    @board_renderer = BoardRenderer.new(window)

    @background = load_image(BACKGROUND_FILES.fetch(controller.map_config.map_type))
    @back_image = load_image("botao_voltar_play.png")
    @ship_images = {
      "Barco" => load_image("navio_barco_perfil.png"),
      "Fragata" => load_image("navio_fragata_perfil.png"),
      "Corveta" => load_image("navio_corveta_perfil.png"),
      "Submarino" => load_image("navio-submarino_perfil.png")
    }

    # Artes próprias poderão substituir os controles desenhados quando forem
    # entregues, sem alterar a lógica ou o controller.
    # @single_shot_image = load_image("botao_um_tiro.png")
    # @extra_shot_image = load_image("botao_tiro_extra.png")
    # @orientation_image = load_image("botao_orientacao.png")
    # @auto_place_image = load_image("botao_posicionar_automaticamente.png")
    # @reset_image = load_image("botao_reiniciar_posicionamento.png")
    # @start_image = load_image("botao_iniciar_batalha.png")

    @title_font = Gosu::Font.new(34)
    @text_font = Gosu::Font.new(22)
    @small_font = Gosu::Font.new(18)
    configure_controls
  end

  def draw
    draw_background
    draw_back_button
    draw_board
    draw_ship_preview
    draw_controls
    draw_status
  end

  def button_down(id, mouse_x, mouse_y)
    return go_back if id == Gosu::KB_ESCAPE
    return toggle_orientation if id == Gosu::KB_SPACE
    return unless id == Gosu::MS_LEFT

    return go_back if inside_image?(@back_image, BACK_X, BACK_Y, mouse_x, mouse_y)
    return handle_control_click(mouse_x, mouse_y) if control_at(mouse_x, mouse_y)

    handle_board_click(mouse_x, mouse_y)
  end

  private

  def configure_controls
    labels = %i[single_shot extra_shot orientation auto_place reset start]
    @controls = labels.each_with_index.to_h do |name, index|
      [name, {
        x: CONTROL_X,
        y: CONTROL_START_Y + (index * (CONTROL_HEIGHT + CONTROL_GAP)),
        width: CONTROL_WIDTH,
        height: CONTROL_HEIGHT
      }]
    end
  end

  def draw_background
    scale_x = @window.width.to_f / @background.width
    scale_y = @window.height.to_f / @background.height
    @background.draw(0, 0, 0, scale_x, scale_y)
    Gosu.draw_rect(0, 0, @window.width, @window.height, Gosu::Color.rgba(0, 0, 0, 75), 1)
  end

  def draw_back_button
    @back_image.draw(BACK_X, BACK_Y, 5)
  end

  def draw_board
    player_x, = @board_renderer.origins(@controller.player_board.size)
    @board_renderer.draw(
      @controller.player_board,
      player_x,
      title: "POSICIONE SUA FROTA",
      reveal_ships: true
    )
  end

  def draw_ship_preview
    ship = @controller.next_ship
    Gosu.draw_rect(
      PREVIEW_X,
      PREVIEW_Y,
      PREVIEW_WIDTH,
      PREVIEW_HEIGHT,
      NORMAL_COLOR,
      4
    )

    unless ship
      draw_preview_text("Frota pronta para a batalha", PREVIEW_Y + 42)
      return
    end

    @text_font.draw_text(ship.name, PREVIEW_X + 24, PREVIEW_Y + 25, 5, 1, 1, TEXT_COLOR)
    @small_font.draw_text(
      "#{ship.size} casas",
      PREVIEW_X + 24,
      PREVIEW_Y + 65,
      5,
      1,
      1,
      MESSAGE_COLOR
    )

    image = @ship_images[ship.name]
    if image
      draw_preview_image(image)
    else
      @small_font.draw_text(
        "Imagem ainda não adicionada",
        PREVIEW_IMAGE_X,
        PREVIEW_Y + 45,
        5,
        1,
        1,
        TEXT_COLOR
      )
    end
  end

  def draw_preview_image(image)
    scale = [
      PREVIEW_IMAGE_WIDTH.to_f / image.width,
      PREVIEW_IMAGE_HEIGHT.to_f / image.height
    ].min
    drawn_width = image.width * scale
    drawn_height = image.height * scale
    image_x = PREVIEW_IMAGE_X + ((PREVIEW_IMAGE_WIDTH - drawn_width) / 2)
    image_y = PREVIEW_IMAGE_Y + ((PREVIEW_IMAGE_HEIGHT - drawn_height) / 2)

    image.draw(image_x, image_y, 5, scale, scale)
  end

  def draw_preview_text(text, y)
    x = PREVIEW_X + ((PREVIEW_WIDTH - @text_font.text_width(text)) / 2)
    @text_font.draw_text(text, x, y, 5, 1, 1, TEXT_COLOR)
  end

  def draw_controls
    draw_control(:single_shot, "Modo: um tiro por vez", selected: @controller.turn_mode == :single_shot)
    draw_control(:extra_shot, "Modo: novo tiro ao acertar", selected: @controller.turn_mode == :extra_shot_on_hit)
    draw_control(:orientation, "Orientação: #{orientation_label} (Espaço)")
    draw_control(:auto_place, "Posicionar automaticamente")
    draw_control(:reset, "Reiniciar posicionamento")
    draw_control(:start, "Iniciar batalha", disabled: !@controller.placement_complete?)
  end

  def draw_control(name, label, selected: false, disabled: false)
    control = @controls.fetch(name)
    color = if disabled
              DISABLED_COLOR
            elsif selected
              SELECTED_COLOR
            elsif inside_control?(control, @window.mouse_x, @window.mouse_y)
              HOVER_COLOR
            else
              NORMAL_COLOR
            end

    Gosu.draw_rect(control[:x], control[:y], control[:width], control[:height], color, 4)
    text_x = control[:x] + ((control[:width] - @text_font.text_width(label)) / 2)
    text_y = control[:y] + ((control[:height] - @text_font.height) / 2)
    @text_font.draw_text(label, text_x, text_y, 5, 1, 1, TEXT_COLOR)
  end

  def draw_status
    ship = @controller.next_ship
    status = if ship
               "Próximo navio: #{ship.name} (#{ship.size} casas)"
             else
               "Frota pronta para a batalha"
             end

    @small_font.draw_text(status, CONTROL_X, 560, 5, 1, 1, TEXT_COLOR)
    @small_font.draw_text(@message, CONTROL_X, 600, 5, 1, 1, MESSAGE_COLOR)
  end

  def handle_control_click(mouse_x, mouse_y)
    case control_at(mouse_x, mouse_y)
    when :single_shot
      @controller.select_turn_mode(:single_shot)
      @message = "Modo de um tiro por vez selecionado."
    when :extra_shot
      @controller.select_turn_mode(:extra_shot_on_hit)
      @message = "Modo de tiro adicional ao acertar selecionado."
    when :orientation
      toggle_orientation
    when :auto_place
      @controller.auto_place
      @message = "Frota posicionada automaticamente."
    when :reset
      @controller.reset_placement
      @message = "Posicionamento reiniciado."
    when :start
      if @controller.placement_complete?
        @controller.start_game
      else
        @message = "Posicione todos os navios antes de iniciar."
      end
    end
  rescue ArgumentError, Board::AutoPlacementError => error
    @message = error.message
  end

  def handle_board_click(mouse_x, mouse_y)
    player_x, = @board_renderer.origins(@controller.player_board.size)
    coordinate = @board_renderer.coordinate_at(
      mouse_x,
      mouse_y,
      @controller.player_board,
      player_x
    )
    return unless coordinate

    row, col = coordinate
    ship = @controller.place_next_ship(row, col, orientation: @orientation)
    @message = "#{ship.name} posicionado."
  rescue ArgumentError => error
    @message = error.message
  end

  def toggle_orientation
    @orientation = @orientation == :horizontal ? :vertical : :horizontal
    @message = "Orientação alterada para #{orientation_label.downcase}."
  end

  def orientation_label
    @orientation == :horizontal ? "Horizontal" : "Vertical"
  end

  def control_at(mouse_x, mouse_y)
    match = @controls.find { |_name, control| inside_control?(control, mouse_x, mouse_y) }
    match&.first
  end

  def inside_control?(control, mouse_x, mouse_y)
    mouse_x >= control[:x] && mouse_x < control[:x] + control[:width] &&
      mouse_y >= control[:y] && mouse_y < control[:y] + control[:height]
  end

  def inside_image?(image, x, y, mouse_x, mouse_y)
    mouse_x >= x && mouse_x < x + image.width &&
      mouse_y >= y && mouse_y < y + image.height
  end

  def go_back
    @window.navigate_to(:map_menu)
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
