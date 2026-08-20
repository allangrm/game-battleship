# frozen_string_literal: true

require "gosu"
require_relative "../controllers/menu_controller"
require_relative "../controllers/game_controller"
require_relative "../models/map_config"

require_relative "menu_view"
require_relative "game_view"
require_relative "placeholder_view"

# Janela principal do jogo. Mantém apenas a view ativa e delega a ela os
# eventos do Gosu.
class MainWindow < Gosu::Window
  WIDTH = 1_408
  HEIGHT = 768
  TITLE = "Batalha Naval"

  def initialize
    super(WIDTH, HEIGHT)
    self.caption = TITLE

    @menu_controller = MenuController.new(self)
    navigate_to(:menu)
  end

  def needs_cursor?
    true
  end

  def draw
    @active_view.draw
  end

  def update
    @active_view.update if @active_view.respond_to?(:update)
  end

  def button_down(id)
    @active_view.button_down(id, mouse_x, mouse_y)
  end

  def navigate_to(screen, **options)
    self.caption = TITLE

    @active_view = case screen
                   when :menu
                     MenuView.new(self, @menu_controller)
                   when :map_menu
                     MenuView.new(self, @menu_controller, screen: :map_menu)
                   when :game
                     build_game_view(options.fetch(:map_type))
                   when :name
                     pending_view("Identificação do jogador", "A entrada do nome será implementada na etapa 3.")
                   when :ranking
                     pending_view("Ranking", "A tela de ranking será integrada pela Pessoa 4.")
                   when :instructions
                     pending_view("Instruções", "A tela completa de instruções será implementada depois do menu.")
                   else
                     raise ArgumentError, "Tela inválida: #{screen.inspect}"
                   end
  end

  private

  def build_game_view(map_type)
    map_config = MapConfig.new(map_type)

    player_board = build_board(map_config)
    enemy_board = build_board(map_config)

    game = Game.new(
      player_board: player_board,
      enemy_board: enemy_board,
      map_type: map_config.map_type
    )

    controller = GameController.new(game)

    self.caption = "#{TITLE} - #{map_config.name}"

    GameView.new(
      self,
      controller,
      map_type: map_config.map_type
    )
  end

  def build_board(map_config)
    board = map_config.create_board
    fleet = map_config.create_fleet

    board.auto_place_ships(fleet)

    board
  end

  def pending_view(title, message)
    PlaceholderView.new(self, title, message)
  end
end
