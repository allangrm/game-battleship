# frozen_string_literal: true

require "gosu"
require_relative "board_renderer"

# Desenha o míssil viajando até a área atacada e mostra sua explosão.
# O efeito é apenas visual e não modifica o tabuleiro da partida.
#
# @author Raffael Wagner
# @version 1.0
class MissileAttackEffect
  TRAVEL_DURATION_MS = 600
  EXPLOSION_DURATION_MS = 350
  TOTAL_DURATION_MS = TRAVEL_DURATION_MS + EXPLOSION_DURATION_MS
  SPRITE_SIZE = 70
  START_OFFSET = 110
  TRAIL_LENGTH = 55

  TRAIL_COLOR = Gosu::Color.rgba(255, 225, 150, 170)

  Effect = Struct.new(
    :target_x,
    :target_y,
    :area_x,
    :area_y,
    :area_width,
    :area_height,
    :started_at,
    keyword_init: true
  )

  # Prepara o sprite, o relógio e as funções de desenho do efeito.
  #
  # @param image [Gosu::Image] sprite usado para representar o míssil
  # @param clock [#call] objeto que devolve o tempo em milissegundos
  # @param line_drawer [#call] função usada para desenhar os raios
  # @param rect_drawer [#call] função usada para desenhar o clarão
  # @return [MissileAttackEffect] efeito criado
  def initialize(
    image,
    clock: -> { Gosu.milliseconds },
    line_drawer: ->(*arguments) { Gosu.draw_line(*arguments) },
    rect_drawer: ->(*arguments) { Gosu.draw_rect(*arguments) }
  )
    @image = image
    @clock = clock
    @line_drawer = line_drawer
    @rect_drawer = rect_drawer
    @effect = nil
  end

  # Inicia a queda do míssil no centro das células atingidas.
  #
  # @param board_size [Integer] tamanho do tabuleiro inimigo
  # @param board_x [Numeric] posição horizontal inicial do tabuleiro
  # @param target_cells [Array<Array<Integer>>] coordenadas atingidas pelo míssil
  # @return [Effect] dados do efeito iniciado
  # @raise [ArgumentError] quando nenhuma célula é recebida
  def start(board_size:, board_x:, target_cells:)
    unless target_cells.is_a?(Array) && target_cells.any?
      raise ArgumentError, "O efeito do míssil precisa de células-alvo"
    end

    cell_size = BoardRenderer::CELL_SIZES.fetch(board_size)
    rows = target_cells.map(&:first)
    cols = target_cells.map(&:last)
    first_row, last_row = rows.minmax
    first_col, last_col = cols.minmax

    area_x = board_x + (first_col * cell_size)
    area_y = BoardRenderer::BOARD_TOP + (first_row * cell_size)
    area_width = (last_col - first_col + 1) * cell_size
    area_height = (last_row - first_row + 1) * cell_size

    @effect = Effect.new(
      target_x: area_x + (area_width / 2.0),
      target_y: area_y + (area_height / 2.0),
      area_x: area_x,
      area_y: area_y,
      area_width: area_width,
      area_height: area_height,
      started_at: @clock.call
    )
  end

  # Informa se o míssil ou a explosão ainda estão sendo mostrados.
  #
  # @return [Boolean] true enquanto o efeito estiver ativo
  def active?
    !@effect.nil?
  end

  # Encerra o efeito depois do tempo total da animação.
  #
  # @return [void]
  def update
    return unless active?

    @effect = nil if elapsed_ms >= TOTAL_DURATION_MS
  end

  # Desenha a queda do míssil ou a explosão, dependendo do tempo atual.
  #
  # @return [void]
  def draw
    return unless active?

    if elapsed_ms < TRAVEL_DURATION_MS
      draw_falling_missile
    else
      draw_explosion
    end
  end

  private

  # Calcula o tempo passado desde o começo do efeito.
  #
  # @return [Numeric] tempo decorrido em milissegundos
  def elapsed_ms
    @clock.call - @effect.started_at
  end

  # Calcula o progresso da parte em que o míssil está caindo.
  #
  # @return [Float] valor entre 0 e 1
  def travel_progress
    [[elapsed_ms.to_f / TRAVEL_DURATION_MS, 0.0].max, 1.0].min
  end

  # Calcula o progresso da explosão depois que o míssil chega ao alvo.
  #
  # @return [Float] valor entre 0 e 1
  def explosion_progress
    elapsed = elapsed_ms - TRAVEL_DURATION_MS
    [[elapsed.to_f / EXPLOSION_DURATION_MS, 0.0].max, 1.0].min
  end

  # Desenha o sprite descendo e uma linha clara atrás dele.
  #
  # @return [void]
  def draw_falling_missile
    start_y = BoardRenderer::BOARD_TOP - START_OFFSET
    progress = travel_progress**2
    y = start_y + ((@effect.target_y - start_y) * progress)

    @line_drawer.call(
      @effect.target_x,
      y - TRAIL_LENGTH,
      TRAIL_COLOR,
      @effect.target_x,
      y - 15,
      TRAIL_COLOR,
      7
    )

    scale = SPRITE_SIZE.to_f / [@image.width, @image.height].max
    @image.draw_rot(
      @effect.target_x,
      y,
      8,
      180,
      0.5,
      0.5,
      scale,
      scale,
      Gosu::Color::WHITE
    )
  end

  # Desenha o clarão e os raios que representam a explosão 2x2.
  #
  # @return [void]
  def draw_explosion
    progress = explosion_progress
    expansion = 8 + (progress * 28)
    alpha = ((1.0 - progress) * 220).round
    flash_color = Gosu::Color.rgba(255, 125, 20, alpha)
    ray_color = Gosu::Color.rgba(255, 225, 90, alpha)

    @rect_drawer.call(
      @effect.area_x - expansion,
      @effect.area_y - expansion,
      @effect.area_width + (expansion * 2),
      @effect.area_height + (expansion * 2),
      flash_color,
      8
    )

    radius = ([@effect.area_width, @effect.area_height].max / 2.0) + expansion
    @line_drawer.call(
      @effect.target_x - radius,
      @effect.target_y,
      ray_color,
      @effect.target_x + radius,
      @effect.target_y,
      ray_color,
      9
    )
    @line_drawer.call(
      @effect.target_x,
      @effect.target_y - radius,
      ray_color,
      @effect.target_x,
      @effect.target_y + radius,
      ray_color,
      9
    )
  end
end
