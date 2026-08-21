# frozen_string_literal: true

require "gosu"

# Apresenta as regras e os controles do jogo usando o antigo fundo do menu
# secundário. A tela é acessada pela rota :instructions.
#
# @author Lívia Ferreira
# @version 1.0
class InstructionsView
  ASSET_PATH = File.expand_path("../models/images", __dir__)

  BACK_X = 23
  BACK_Y = 30
  PANEL_X = 150
  PANEL_Y = 110
  PANEL_WIDTH = 1_108
  PANEL_HEIGHT = 555
  LEFT_COLUMN_X = 195
  RIGHT_COLUMN_X = 735
  COLUMN_TOP = 145
  COLUMN_DIVIDER_X = 704

  PANEL_COLOR = Gosu::Color.rgba(20, 10, 5, 190)
  SECTION_COLOR = Gosu::Color::YELLOW
  TEXT_COLOR = Gosu::Color::WHITE
  MUTED_TEXT_COLOR = Gosu::Color.rgb(225, 215, 190)
  DIVIDER_COLOR = Gosu::Color.rgba(255, 230, 170, 120)
  HOVER_SCALE = 1.03
  HOVER_COLOR = Gosu::Color.rgba(255, 255, 190, 150)

  def initialize(window)
    @window = window
    @background = load_image("fundo_ranking.png")
    @back_image = load_image("botao_voltar_play.png")
    @back_button = { image: @back_image, x: BACK_X, y: BACK_Y }

    @title_font = Gosu::Font.new(38)
    @section_font = Gosu::Font.new(24)
    @text_font = Gosu::Font.new(18)
    @small_font = Gosu::Font.new(16)
  end

  def draw
    draw_background
    draw_panel
    draw_title
    draw_column_divider
    draw_preparation
    draw_controls
    draw_back_button
  end

  def button_down(id, mouse_x, mouse_y)
    return go_back if id == Gosu::KB_ESCAPE
    return unless id == Gosu::MS_LEFT

    go_back if clicked_back?(mouse_x, mouse_y)
  end

  private

  def draw_background
    scale_x = @window.width.to_f / @background.width
    scale_y = @window.height.to_f / @background.height
    @background.draw(0, 0, 0, scale_x, scale_y)
  end

  def draw_panel
    Gosu.draw_rect(
      PANEL_X,
      PANEL_Y,
      PANEL_WIDTH,
      PANEL_HEIGHT,
      PANEL_COLOR,
      1
    )
  end

  def draw_title
    text = "INSTRUÇÕES"
    x = (@window.width - @title_font.text_width(text)) / 2
    @title_font.draw_text(text, x, 55, 3, 1, 1, Gosu::Color.rgb(65, 30, 15))
  end

  def draw_column_divider
    Gosu.draw_line(
      COLUMN_DIVIDER_X,
      PANEL_Y + 25,
      DIVIDER_COLOR,
      COLUMN_DIVIDER_X,
      PANEL_Y + PANEL_HEIGHT - 25,
      DIVIDER_COLOR,
      2
    )
  end

  def draw_preparation
    draw_section("COMO JOGAR", LEFT_COLUMN_X, COLUMN_TOP)
    draw_lines(
      [
        "1. Clique em Play e escolha Poça, Lago ou Oceano.",
        "2. Escolha o modo de turno antes da partida.",
        "3. Posicione toda a frota no tabuleiro aliado.",
        "4. Use Espaço para alternar a orientação do navio.",
        "5. Clique em Iniciar batalha quando a frota estiver pronta.",
        "6. Ataque clicando em uma casa do tabuleiro inimigo."
      ],
      LEFT_COLUMN_X,
      COLUMN_TOP + 42
    )

    draw_section("OBJETIVO", LEFT_COLUMN_X, 400)
    draw_lines(
      [
        "Afunde todos os navios inimigos antes que a IA destrua",
        "a sua frota. Acertos, navios sobreviventes, integridade",
        "e menor duração aumentam a pontuação final."
      ],
      LEFT_COLUMN_X,
      442,
      color: MUTED_TEXT_COLOR
    )

    @small_font.draw_text(
      "Poça: fácil  |  Lago: média  |  Oceano: difícil",
      LEFT_COLUMN_X,
      550,
      3,
      1,
      1,
      SECTION_COLOR
    )
  end

  def draw_controls
    draw_section("CONTROLES", RIGHT_COLUMN_X, COLUMN_TOP)
    draw_lines(
      [
        "Mouse: selecionar botões, posicionar navios e atacar.",
        "Espaço: girar o próximo navio durante o setup.",
        "Esc ou Voltar: retornar à tela anterior."
      ],
      RIGHT_COLUMN_X,
      COLUMN_TOP + 42
    )

    draw_section("ARMAS ESPECIAIS", RIGHT_COLUMN_X, 285)
    draw_lines(
      [
        "Míssil: atinge uma área de 2x2.",
        "Avião: atinge uma linha ou coluna completa.",
        "Clique na arma para selecioná-la ou voltar ao tiro básico.",
        "No botão do Avião, alterne entre LINHA e COLUNA."
      ],
      RIGHT_COLUMN_X,
      327
    )

    draw_section("MODOS DE TURNO", RIGHT_COLUMN_X, 455)
    draw_lines(
      [
        "Um tiro: o turno muda depois de cada ataque.",
        "Tiro adicional: quem acerta continua jogando."
      ],
      RIGHT_COLUMN_X,
      497,
      color: MUTED_TEXT_COLOR
    )
  end

  def draw_section(text, x, y)
    @section_font.draw_text(text, x, y, 3, 1, 1, SECTION_COLOR)
  end

  def draw_lines(lines, x, y, color: TEXT_COLOR)
    lines.each_with_index do |line, index|
      @text_font.draw_text(line, x, y + (index * 30), 3, 1, 1, color)
    end
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

  def go_back
    @window.navigate_to(:menu)
  end

  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end
end
