# frozen_string_literal: true

require "gosu"

# Preserva o fluxo visual do protótipo: capa com Play e seleção de mapa.
# As ações são encaminhadas ao controller, sem montar a partida na view.
#
# @author Lívia Ferreira
# @version 1.2
class MenuView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  PLAY_X = 365
  PLAY_Y = 347
  RANKING_X = 920
  RANKING_Y = 490
  MENU_X = 748
  MENU_Y = 347
  EXIT_X = 1_270
  EXIT_Y = 650
  BACK_X = 23
  BACK_Y = 30
  MAP_BUTTON_Y = 344

  MAP_BUTTON_X = {
    poca: 368,
    lago: 608,
    oceano: 851
  }.freeze

  HOVER_SCALE = 1.03
  HOVER_COLOR = Gosu::Color.rgba(255, 255, 190, 150)

  def initialize(window, controller, screen: :cover)
    unless %i[cover map_menu].include?(screen)
      raise ArgumentError, "Estado inicial inválido: #{screen.inspect}"
    end

    @window = window
    @controller = controller
    @screen = screen
    @menu_message = nil

    load_assets
    configure_buttons
  end

  def draw
    case @screen
    when :cover
      draw_cover
    when :map_menu
      draw_map_menu
    end
  end

  def button_down(id, mouse_x, mouse_y)
    if id == Gosu::KB_ESCAPE
      go_back
      return
    end

    return unless id == Gosu::MS_LEFT

    case @screen
    when :cover
      handle_cover_click(mouse_x, mouse_y)
    when :map_menu
      handle_map_menu_click(mouse_x, mouse_y)
    end
  end

  private

  def load_assets
    @cover_background = load_image("fundo_play.png")
    @menu_background = load_image("fundo_menu.png")
    @play_image = load_image("play.png")
    @ranking_image = load_image("botao_ranking.png")
    @menu_image = load_image("botao_menu.png")
    @exit_image = load_image("botao_sair.png")
    @back_image = load_image("botao_voltar_play.png")

    @map_button_images = {
      poca: load_image("botao_poca.png"),
      lago: load_image("botao_lago.png"),
      oceano: load_image("botao_oceano.png")
    }

    # Este asset ainda não existe. A rota correspondente permanece disponível
    # no MenuController para ser conectada quando a arte for adicionada.
    # @instructions_image = load_image("botao_instrucoes.png")

    @message_font = Gosu::Font.new(24)
  end

  def configure_buttons
    @play_button = image_button(@play_image, PLAY_X, PLAY_Y)
    @ranking_button = image_button(@ranking_image, RANKING_X, RANKING_Y)
    @menu_button = image_button(@menu_image, MENU_X, MENU_Y)
    @exit_button = image_button(@exit_image, EXIT_X, EXIT_Y)
    @back_button = image_button(@back_image, BACK_X, BACK_Y)

    @map_buttons = MAP_BUTTON_X.to_h do |map_name, x|
      [map_name, image_button(@map_button_images.fetch(map_name), x, MAP_BUTTON_Y)]
    end
  end

  def draw_cover
    @cover_background.draw(0, 0, 0)
    draw_image_button(@play_button)
    draw_image_button(@menu_button)
    draw_image_button(@ranking_button)
    draw_image_button(@exit_button)
  end

  def draw_map_menu
    @menu_background.draw(0, 0, 0)
    draw_image_button(@back_button)
    @map_buttons.each_value { |button| draw_image_button(button) }
    draw_menu_message
  end

  def draw_menu_message
    return unless @menu_message

    text_x = (@window.width - @message_font.text_width(@menu_message)) / 2
    @message_font.draw_text(
      @menu_message,
      text_x,
      455,
      2,
      1,
      1,
      Gosu::Color::YELLOW
    )
  end

  def handle_map_menu_click(mouse_x, mouse_y)
    if clicked_image?(@back_button, mouse_x, mouse_y)
      @screen = :cover
      @menu_message = nil
      return
    end

    selected_map = @map_buttons.find do |_map_name, button|
      clicked_image?(button, mouse_x, mouse_y)
    end

    select_map(selected_map.first) if selected_map
  end

  def handle_cover_click(mouse_x, mouse_y)
    if clicked_image?(@play_button, mouse_x, mouse_y)
      @controller.handle(:start_game)
    elsif clicked_image?(@menu_button, mouse_x, mouse_y)
      @controller.handle(:show_options_menu)
    elsif clicked_image?(@ranking_button, mouse_x, mouse_y)
      @controller.handle(:show_ranking)
    elsif clicked_image?(@exit_button, mouse_x, mouse_y)
      @controller.handle(:exit)
    end
  end

  def select_map(map_name)
    @controller.select_map(map_name)
  end

  def go_back
    case @screen
    when :cover
      return
    when :map_menu
      @window.navigate_to(:menu)
    end
  end

  def image_button(image, x, y)
    { image: image, x: x, y: y }
  end

  def draw_image_button(button)
    button[:image].draw(button[:x], button[:y], 1)
    draw_button_glow(button) if hovered?(button)
  end

  def draw_button_glow(button)
    image = button[:image]
    offset_x = image.width * (HOVER_SCALE - 1) / 2
    offset_y = image.height * (HOVER_SCALE - 1) / 2

    image.draw(
      button[:x] - offset_x,
      button[:y] - offset_y,
      2,
      HOVER_SCALE,
      HOVER_SCALE,
      HOVER_COLOR,
      :additive
    )
  end

  def hovered?(button)
    clicked_image?(button, @window.mouse_x, @window.mouse_y)
  end

  def clicked_image?(button, mouse_x, mouse_y)
    mouse_x >= button[:x] &&
      mouse_x < button[:x] + button[:image].width &&
      mouse_y >= button[:y] &&
      mouse_y < button[:y] + button[:image].height
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
