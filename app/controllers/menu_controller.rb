# frozen_string_literal: true

# Recebe as ações do menu e solicita a navegação à janela principal.
# 
# @author Júlio Pedro
# @version 1.1
class MenuController
  def initialize(window)
    @window = window
  end

  def handle(action)
    case action
    when :start_game
      @window.navigate_to(:name)
    when :show_ranking
      @window.navigate_to(:ranking)
    when :show_instructions
      @window.navigate_to(:instructions)
    when :exit
      @window.close
    else
      raise ArgumentError, "Ação de menu inválida: #{action.inspect}"
    end
  end
end
