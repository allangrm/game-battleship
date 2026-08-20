# frozen_string_literal: true

require "gosu"

# Preserva o fluxo visual do protótipo: capa com Play, seleção de mapa e mapa
# escolhido. A classe apenas separa essa interface da janela principal.
#
# @author Lívia Ferreira
# @version 1.0
class MenuView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  PLAY_X = 365
  PLAY_Y = 347
  RANKING_X = 920
  RANKING_Y = 490
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
    unless %i[cover map_menu playing].include?(screen)
      raise ArgumentError, "Estado inicial inválido: #{screen.inspect}"
    end

    @window = window
    @controller = controller
    @screen = screen
    @current_map = nil
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
    when :playing
      draw_selected_map
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
    when :playing
      handle_map_click(mouse_x, mouse_y)
    end
  end

  private

  def load_assets
    @cover_background = load_image("fundo_play.png")
    @menu_background = load_image("fundo_menu.png")
    @play_image = load_image("play.png")
    @ranking_image = load_image("botao_ranking.png")
    @back_image = load_image("botao_voltar_play.png")

    @map_button_images = {
      poca: load_image("botao_poca.png"),
      lago: load_image("botao_lago.png"),
      oceano: load_image("botao_oceano.png")
    }

    @maps = {
      poca: load_image("mapa_poca.jpeg"),
      lago: load_image("mapa_lago.png")
    }

    # Estes assets ainda não existem. As rotas correspondentes já permanecem
    # no MenuController, mas seus botões não são desenhados por enquanto.
    # @instructions_image = load_image("botao_instrucoes.png")
    # @exit_image = load_image("botao_sair.png")

    @message_font = Gosu::Font.new(24)
  end

  def configure_buttons
    @play_button = image_button(@play_image, PLAY_X, PLAY_Y)
    @ranking_button = image_button(@ranking_image, RANKING_X, RANKING_Y)
    @back_button = image_button(@back_image, BACK_X, BACK_Y)

    @map_buttons = MAP_BUTTON_X.to_h do |map_name, x|
      [map_name, image_button(@map_button_images.fetch(map_name), x, MAP_BUTTON_Y)]
    end
  end

  def draw_cover
    @cover_background.draw(0, 0, 0)
    draw_image_button(@play_button)
    draw_image_button(@ranking_button)
  end

  def draw_map_menu
    @menu_background.draw(0, 0, 0)
    draw_image_button(@back_button)
    @map_buttons.each_value { |button| draw_image_button(button) }
    draw_menu_message
  end

  def draw_selected_map
    map = @maps.fetch(@current_map)
    scale_x = @window.width.to_f / map.width
    scale_y = @window.height.to_f / map.height

    map.draw(0, 0, 0, scale_x, scale_y)
    draw_image_button(@back_button)
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
      open_map_menu
    elsif clicked_image?(@ranking_button, mouse_x, mouse_y)
      @controller.handle(:show_ranking)
    end
  end

  def handle_map_click(mouse_x, mouse_y)
    if clicked_image?(@back_button, mouse_x, mouse_y)
      open_map_menu
    else
      puts "Clique no tabuleiro: X=#{mouse_x.to_i}, Y=#{mouse_y.to_i}"
    end
  end

  def select_map(map_name)
    unless @maps.key?(map_name)
      @menu_message = "Mapa Oceano em desenvolvimento"
      return
    end

    @current_map = map_name
    @screen = :playing
    @menu_message = nil
    @window.caption = "Batalha Naval - #{map_name.to_s.capitalize}"
  end

  def open_map_menu
    @screen = :map_menu
    @menu_message = nil
    @window.caption = MainWindow::TITLE
  end

  def go_back
    case @screen
    when :cover
      @controller.handle(:exit)
    when :map_menu
      @screen = :cover
      @menu_message = nil
    when :playing
      open_map_menu
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
