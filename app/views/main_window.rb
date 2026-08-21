# frozen_string_literal: true

require "gosu"
require_relative "../controllers/menu_controller"
require_relative "../controllers/setup_controller"
require_relative "../controllers/post_game_controller"
require_relative "../controllers/ranking_controller"

require_relative "menu_view"
require_relative "options_menu_view"
require_relative "ranking_view"
require_relative "game_view"
require_relative "setup_view"
require_relative "name_view"
require_relative "game_over_view"
require_relative "placeholder_view"

# Janela principal do jogo. Mantém apenas a view ativa e delega a ela os
# eventos do Gosu.
#
# @author Lívia Ferreira
# @version 1.1
class MainWindow < Gosu::Window
  WIDTH = 1_408
  HEIGHT = 768
  TITLE = "Batalha Naval"

  def initialize
    super(WIDTH, HEIGHT)
    self.caption = TITLE

    @menu_controller = MenuController.new(self)
    @post_game_controller = PostGameController.new(self)
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
    next_view = build_view(screen, **options)

    @active_view = next_view
    self.text_input = next_view.respond_to?(:text_input) ? next_view.text_input : nil
  end

  private

  def build_view(screen, **options)
    case screen
    when :menu
      MenuView.new(self, @menu_controller)
    when :map_menu
      MenuView.new(self, @menu_controller, screen: :map_menu)
    when :options_menu
      OptionsMenuView.new(self)
    when :setup
      setup_controller = SetupController.new(self, map_type: options.fetch(:map_type))
      SetupView.new(self, setup_controller)
    when :game
      self.caption = "#{TITLE} - #{options.fetch(:map_name)}"
      GameView.new(
        self,
        options.fetch(:game_controller),
        map_type: options.fetch(:map_type),
        on_game_over: @post_game_controller.method(:handle_game_over)
      )
    when :name
      NameView.new(
        self,
        game: options.fetch(:game),
        on_submit: options.fetch(:on_submit)
      )
    when :game_over
      GameOverView.new(
        self,
        game: options.fetch(:game),
        player: options[:player],
        score: options.fetch(:score),
        saved_match_id: options[:saved_match_id],
        persistence_error: options[:persistence_error]
      )
    when :ranking
      ranking_controller = RankingController.new(
        map_type: options[:map_type]
      )

      RankingView.new(self, ranking_controller)
    when :instructions
      pending_view("Instruções", "A tela completa de instruções será implementada depois do menu.")
    else
      raise ArgumentError, "Tela inválida: #{screen.inspect}"
    end
  end

  def pending_view(title, message)
    PlaceholderView.new(self, title, message)
  end
end
