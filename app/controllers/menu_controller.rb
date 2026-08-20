# frozen_string_literal: true

# Recebe as ações do menu e solicita a navegação à janela principal.
#
# @author Lívia Ferreira
# @version 1.2

class MenuController
  def initialize(window)
    @window = window
  end

  def handle(action)
    case action
    when :start_game
      @window.navigate_to(:map_menu)
    when :show_ranking
      @window.navigate_to(:ranking)
    when :show_options_menu
      @window.navigate_to(:options_menu)
    when :show_instructions
      @window.navigate_to(:instructions)
    when :exit
      @window.close
    else
      raise ArgumentError, "Ação de menu inválida: #{action.inspect}"
    end
  end

  def select_map(map_type)
    @window.navigate_to(:setup, map_type: map_type)
  end
end
