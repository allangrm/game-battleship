# frozen_string_literal: true

require "gosu"
require_relative "components/message_box"
require_relative "components/board_renderer"

class GameView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  BACKGROUND_FILES = {
    poca: "mapa_poca.jpeg",
    lago: "mapa_lago.png",
    oceano: "mapa_oceano.png"
  }.freeze

  BACK_X = 23
  BACK_Y = 30


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
    events = @controller.handle_player_attack(row, col)

    events.each do |event|
      print_attack_event(event)
    end

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

end
