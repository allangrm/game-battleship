# frozen_string_literal: true

require "gosu"
require_relative "components/message_box"
require_relative "components/board_renderer"
require_relative "../weapons/basic_shot"
require_relative "../weapons/missile"
require_relative "../weapons/airplane"

class GameView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  BACKGROUND_FILES = {
    poca: "mapa_poca.jpeg",
    lago: "mapa_lago.png",
    oceano: "mapa_oceano.png"
  }.freeze

  BACK_X = 23
  BACK_Y = 30

  SPECIAL_BUTTON_X = 1_235
  SPECIAL_BUTTON_Y = 190
  SPECIAL_BUTTON_WIDTH = 150
  SPECIAL_BUTTON_GAP = 14
  ORIENTATION_BUTTON_HEIGHT = 36

  SPECIAL_PANEL_COLOR = Gosu::Color.rgba(0, 0, 0, 180)
  SPECIAL_GLOW_SCALE = 1.04
  SPECIAL_GLOW_COLOR = Gosu::Color.rgba(255, 255, 190, 150)
  SPECIAL_DISABLED_COLOR = Gosu::Color.rgba(105, 105, 105, 175)
  SPECIAL_TEXT_COLOR = Gosu::Color.rgb(65, 32, 12)
  ORIENTATION_COLOR = Gosu::Color.rgba(25, 25, 25, 220)
  ORIENTATION_SELECTED_COLOR = Gosu::Color.rgba(155, 105, 25, 235)


  def initialize(window, controller, map_type:, on_game_over: nil)
    if on_game_over && !on_game_over.respond_to?(:call)
      raise ArgumentError, "on_game_over precisa responder a #call"
    end

    @window = window
    @controller = controller
    @map_type = map_type
    @on_game_over = on_game_over
    @game_over_notified = false

    @background = load_background(map_type)
    @back_image = Gosu::Image.new(
      File.join(ASSET_PATH, "botao_voltar_play.png")
    )
    @board_renderer = BoardRenderer.new(window)
    @selected_enemy_coordinate = nil
    @selected_weapon = :basic_shot
    @airplane_orientation = :row
    @missile_image = load_image("botao_missil.png")
    @airplane_image = load_image("botao_aviao.png")
    @special_title_font = Gosu::Font.new(17)
    @special_counter_font = Gosu::Font.new(16)
    @orientation_font = Gosu::Font.new(15)

    configure_special_weapon_buttons

    @message_box = MessageBox.new(window)
  end

  def draw
    draw_background

    player_board = @controller.game.player_board
    enemy_board = @controller.game.enemy_board

    player_x, enemy_x = @board_renderer.origins(player_board.size)

    @board_renderer.draw(
      player_board,
      player_x,
      title: "SEU TABULEIRO",
      reveal_ships: true
    )

    @board_renderer.draw(
      enemy_board,
      enemy_x,
      title: "TABULEIRO INIMIGO",
      reveal_ships: false
    )

    @board_renderer.draw_selection(
      enemy_board,
      enemy_x,
      @selected_enemy_coordinate
    )
    draw_special_weapon_controls
    @message_box.draw
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

    weapon_action = weapon_action_at(mouse_x, mouse_y)

    if weapon_action
      handle_weapon_action(weapon_action)
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


  def handle_enemy_board_click(mouse_x, mouse_y)
    enemy_board = @controller.game.enemy_board
    _player_x, enemy_x = @board_renderer.origins(enemy_board.size)

    coordinate = @board_renderer.coordinate_at(
      mouse_x,
      mouse_y,
      enemy_board,
      enemy_x
    )

    return unless coordinate

    @selected_enemy_coordinate = coordinate

    row, col = coordinate
    perform_player_attack(row, col)
  end

  def perform_player_attack(row, col)
    weapon = selected_weapon_instance
    options = selected_weapon_options

    events = @controller.handle_player_attack(
      row,
      col,
      weapon,
      **options
    )

    events.each do |event|
      print_attack_event(event)
    end

    select_basic_shot_if_unavailable
    notify_game_over(events)
  rescue InvalidAttackError,
    Game::InvalidTurnError,
    Game::GameFinishedError,
    WeaponInventory::WeaponUnavailableError => error
    message = "Jogada inválida: #{error.message}"

    puts message
    @message_box.add(message)
  ensure
    @selected_enemy_coordinate = nil
  end

  def print_attack_event(event)
    actor =
      if event.actor == :player
        "Jogador"
      else
        "Computador"
      end

    event.cells.each do |cell_result|
      coordinate = formatted_coordinate(
        cell_result.row,
        cell_result.col
      )

      status = translated_status(cell_result.status)
      message = "#{actor} atacou #{coordinate}: #{status}"

      puts message
      @message_box.add(message)
    end

    return unless event.game_over?

    result =
      if event.winner == :player
        "Vitória do jogador!"
      else
        "Vitória do computador!"
      end

    puts "Fim de jogo: #{result}"
    @message_box.add("Fim de jogo: #{result}")
  end

  # Ponto de integração com a navegação de P3 e as telas finais de P4. A view
  # apenas informa o encerramento; não cria Player, não calcula nem persiste.
  def notify_game_over(events)
    return if @game_over_notified
    return unless events.any?(&:game_over?)

    @game_over_notified = true
    @on_game_over&.call(@controller.game)
  end

  def formatted_coordinate(row, col)
    letter = ("A".ord + col).chr

    "#{letter}#{row + 1}"
  end

  def translated_status(status)
    case status
    when :hit
      "acerto"
    when :miss
      "água"
    when :sunk
      "navio afundado"
    else
      status.to_s
    end
  end

  def configure_special_weapon_buttons
    missile_button = special_weapon_button(@missile_image, SPECIAL_BUTTON_Y)
    airplane_y = missile_button[:y] + missile_button[:height] + SPECIAL_BUTTON_GAP
    airplane_button = special_weapon_button(@airplane_image, airplane_y)

    @weapon_buttons = {
      missile: missile_button,
      airplane: airplane_button
    }
    @orientation_button = {
      x: SPECIAL_BUTTON_X,
      y: airplane_button[:y] + airplane_button[:height] + SPECIAL_BUTTON_GAP,
      width: SPECIAL_BUTTON_WIDTH,
      height: ORIENTATION_BUTTON_HEIGHT
    }
  end

  def special_weapon_button(image, y)
    scale = SPECIAL_BUTTON_WIDTH.to_f / image.width

    {
      image: image,
      x: SPECIAL_BUTTON_X,
      y: y,
      width: SPECIAL_BUTTON_WIDTH,
      height: image.height * scale,
      scale: scale
    }
  end

  def draw_special_weapon_controls
    draw_special_panel
    @weapon_buttons.each do |weapon, button|
      draw_special_weapon_button(weapon, button)
    end
    draw_orientation_button
  end

  def draw_special_panel
    title = selected_weapon_label
    title_x = SPECIAL_BUTTON_X +
              ((SPECIAL_BUTTON_WIDTH - @special_title_font.text_width(title)) / 2)
    panel_bottom = @orientation_button[:y] + @orientation_button[:height] + 8

    Gosu.draw_rect(
      SPECIAL_BUTTON_X - 7,
      SPECIAL_BUTTON_Y - 36,
      SPECIAL_BUTTON_WIDTH + 14,
      panel_bottom - SPECIAL_BUTTON_Y + 44,
      SPECIAL_PANEL_COLOR,
      3
    )
    @special_title_font.draw_text(
      title,
      title_x,
      SPECIAL_BUTTON_Y - 27,
      6,
      1,
      1,
      Gosu::Color::WHITE
    )
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end

  def draw_special_weapon_button(weapon, button)
    color = if player_inventory.available?(weapon)
              Gosu::Color::WHITE
            else
              SPECIAL_DISABLED_COLOR
            end
    button[:image].draw(
      button[:x],
      button[:y],
      5,
      button[:scale],
      button[:scale],
      color
    )
    draw_special_weapon_glow(button) if @selected_weapon == weapon
    draw_special_counter(weapon, button)
  end

  def draw_special_weapon_glow(button)
    offset_x = button[:width] * (SPECIAL_GLOW_SCALE - 1) / 2
    offset_y = button[:height] * (SPECIAL_GLOW_SCALE - 1) / 2
    glow_scale = button[:scale] * SPECIAL_GLOW_SCALE

    button[:image].draw(
      button[:x] - offset_x,
      button[:y] - offset_y,
      6,
      glow_scale,
      glow_scale,
      SPECIAL_GLOW_COLOR,
      :additive
    )
  end

  def draw_special_counter(weapon, button)
    label = if weapon == :missile
              "#{player_inventory.remaining(:missile)}"
            else
              "#{player_inventory.remaining(:airplane)}"
            end
    text_x = button[:x] +
             ((button[:width] - @special_counter_font.text_width(label)) / 2)
    text_y = button[:y] +
             (button[:height] * 0.75) -
             (@special_counter_font.height / 2)

    @special_counter_font.draw_text(
      label,
      text_x,
      text_y,
      7,
      1,
      1,
      SPECIAL_TEXT_COLOR
    )
  end

  def draw_orientation_button
    available = player_inventory.available?(:airplane)
    color = if !available
              SPECIAL_DISABLED_COLOR
            elsif @selected_weapon == :airplane
              ORIENTATION_SELECTED_COLOR
            else
              ORIENTATION_COLOR
            end
    Gosu.draw_rect(
      @orientation_button[:x],
      @orientation_button[:y],
      @orientation_button[:width],
      @orientation_button[:height],
      color,
      5
    )

    label = @airplane_orientation == :row ? "ALVO: LINHA" : "ALVO: COLUNA"
    text_x = @orientation_button[:x] +
             ((@orientation_button[:width] - @orientation_font.text_width(label)) / 2)
    text_y = @orientation_button[:y] +
             ((@orientation_button[:height] - @orientation_font.height) / 2)
    @orientation_font.draw_text(label, text_x, text_y, 6, 1, 1, Gosu::Color::WHITE)
  end

  def selected_weapon_label
    case @selected_weapon
    when :missile
      "ARMA: MÍSSIL"
    when :airplane
      "ARMA: AVIÃO"
    else
      "ARMA: TIRO BÁSICO"
    end
  end

  def weapon_action_at(mouse_x, mouse_y)
    return :orientation if inside_weapon_button?(@orientation_button, mouse_x, mouse_y)

    match = @weapon_buttons.find do |_action, button|
      inside_weapon_button?(button, mouse_x, mouse_y)
    end

    match&.first
  end

  def inside_weapon_button?(button, mouse_x, mouse_y)
    mouse_x >= button[:x] &&
      mouse_x < button[:x] + button[:width] &&
      mouse_y >= button[:y] &&
      mouse_y < button[:y] + button[:height]
  end

  def handle_weapon_action(action)
    if action == :orientation
      toggle_airplane_orientation
      return
    end

    unless player_inventory.available?(action)
      @message_box.add("Essa arma não possui cargas restantes.")
      return
    end

    if @selected_weapon == action
      @selected_weapon = :basic_shot
      @message_box.add("Tiro básico selecionado.")
    else
      @selected_weapon = action
      @message_box.add("Arma selecionada: #{weapon_name(action)}.")
    end
  end

  def toggle_airplane_orientation
    unless player_inventory.available?(:airplane)
      @message_box.add("O avião não possui cargas restantes.")
      return
    end

    @airplane_orientation =
      @airplane_orientation == :row ? :col : :row

    orientation =
      @airplane_orientation == :row ? "linha" : "coluna"

    @message_box.add("Orientação do avião: #{orientation}.")
  end

  def selected_weapon_instance
    case @selected_weapon
    when :basic_shot
      BasicShot.new
    when :missile
      Missile.new
    when :airplane
      Airplane.new
    end
  end

  def selected_weapon_options
    return {} unless @selected_weapon == :airplane

    { orientation: @airplane_orientation }
  end

  def select_basic_shot_if_unavailable
    return if player_inventory.available?(@selected_weapon)

    @selected_weapon = :basic_shot
    @message_box.add("As cargas acabaram. Tiro básico selecionado.")
  end

  def player_inventory
    @controller.game.player_inventory
  end

  def weapon_name(action)
    case action
    when :basic_shot
      "Tiro básico"
    when :missile
      "Míssil"
    when :airplane
      "Avião"
    end
  end

end
