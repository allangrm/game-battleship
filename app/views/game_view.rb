# frozen_string_literal: true

require "gosu"
require_relative "components/message_box"
require_relative "components/board_renderer"
require_relative "components/airplane_attack_effect"
require_relative "components/missile_attack_effect"
require_relative "../weapons/basic_shot"
require_relative "../weapons/missile"
require_relative "../weapons/airplane"

# Mostra a partida, os tabuleiros e os controles usados pelo jogador.
# Também apresenta as mensagens e os efeitos visuais de cada ataque.
#
# @author Raffael Wagner
# @version 1.3
class GameView
  ASSET_PATH = File.expand_path("../models/images", __dir__)
  SOUND_PATH = File.expand_path("../../shared/soundtrack", __dir__)

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

  # Cria a tela da partida e carrega imagens, sons e efeitos visuais.
  #
  # @param window [MainWindow] janela principal do jogo
  # @param controller [GameController] controller da partida atual
  # @param map_type [Symbol] mapa escolhido pelo jogador
  # @param on_game_over [#call, nil] ação executada no fim da partida
  # @return [GameView] tela criada
  def initialize(window, controller, map_type:, on_game_over: nil)
    if on_game_over && !on_game_over.respond_to?(:call)
      raise ArgumentError, "on_game_over precisa responder a #call"
    end

    @window = window
    @controller = controller
    @map_type = map_type
    @on_game_over = on_game_over
    @game_over_notified = false
    @pending_game_over = false

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
    @airplane_attack_effect = AirplaneAttackEffect.new(load_image("aviao.png"))
    @missile_attack_effect = MissileAttackEffect.new(load_image("missil.png"))
    @basic_shot_sound = load_sound("tiro.ogg")
    @special_shot_sound = load_sound("tiro_arma_especial.ogg")
    @special_title_font = Gosu::Font.new(17)
    @special_counter_font = Gosu::Font.new(16)
    @orientation_font = Gosu::Font.new(15)

    configure_special_weapon_buttons

    @message_box = MessageBox.new(window)
  end

  # Desenha os tabuleiros, controles, efeitos e mensagens da partida.
  #
  # @return [void]
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
    @airplane_attack_effect.draw
    @missile_attack_effect.draw
    draw_special_weapon_controls
    @message_box.draw
    draw_back_button
  end

  # Atualiza as animações e conclui um fim de jogo que estava aguardando efeito.
  #
  # @return [void]
  def update
    @airplane_attack_effect.update
    @missile_attack_effect.update
    notify_pending_game_over
  end

  # Trata teclado, botão Voltar, seleção de arma e clique de ataque.
  #
  # @param id [Integer] código da tecla ou botão pressionado
  # @param mouse_x [Numeric] posição horizontal do mouse
  # @param mouse_y [Numeric] posição vertical do mouse
  # @return [void]
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

    if attack_effect_active?
      @message_box.add("Aguarde a animação do ataque terminar.")
      return
    end

    handle_enemy_board_click(mouse_x, mouse_y)
  end

  private

  # Desenha a imagem usada para voltar à seleção de mapas.
  #
  # @return [void]
  def draw_back_button
    @back_image.draw(
      BACK_X,
      BACK_Y,
      5
    )
  end

  # Sai da partida atual e volta para a seleção de mapas.
  #
  # @return [void]
  def go_back
    @window.navigate_to(:map_menu)
  end

  # Verifica se o mouse está dentro do botão Voltar.
  #
  # @param mouse_x [Numeric] posição horizontal do mouse
  # @param mouse_y [Numeric] posição vertical do mouse
  # @return [Boolean] true quando o botão foi clicado
  def clicked_back_button?(mouse_x, mouse_y)
    mouse_x >= BACK_X &&
      mouse_x < BACK_X + @back_image.width &&
      mouse_y >= BACK_Y &&
      mouse_y < BACK_Y + @back_image.height
  end

  # Carrega a imagem de fundo correspondente ao mapa atual.
  #
  # @param map_type [Symbol] mapa escolhido
  # @return [Gosu::Image] imagem de fundo carregada
  # @raise [ArgumentError] quando o mapa não possui fundo
  def load_background(map_type)
    file_name = BACKGROUND_FILES.fetch(map_type) do
      raise ArgumentError, "Fundo não encontrado para o mapa: #{map_type}"
    end

    Gosu::Image.new(
      File.join(ASSET_PATH, file_name)
    )
  end

  # Ajusta o fundo para preencher toda a janela.
  #
  # @return [void]
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


  # Converte o clique no tabuleiro inimigo em um ataque.
  #
  # @param mouse_x [Numeric] posição horizontal do mouse
  # @param mouse_y [Numeric] posição vertical do mouse
  # @return [void]
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

  # Envia o ataque escolhido ao controller e processa seus eventos.
  #
  # @param row [Integer] linha atacada
  # @param col [Integer] coluna atacada
  # @return [void]
  def perform_player_attack(row, col)
    weapon = selected_weapon_instance
    options = selected_weapon_options

    events = @controller.handle_player_attack(
      row,
      col,
      weapon,
      **options
    )

    play_attack_sound(weapon)
    start_airplane_attack_effect(row, col) if weapon.is_a?(Airplane)
    start_missile_attack_effect(row, col) if weapon.is_a?(Missile)

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

  # Inicia a animação do Avião na linha ou coluna escolhida.
  #
  # @param row [Integer] linha selecionada
  # @param col [Integer] coluna selecionada
  # @return [void]
  def start_airplane_attack_effect(row, col)
    enemy_board = @controller.game.enemy_board
    _player_x, enemy_x = @board_renderer.origins(enemy_board.size)

    @airplane_attack_effect.start(
      board_size: enemy_board.size,
      board_x: enemy_x,
      row: row,
      col: col,
      orientation: @airplane_orientation
    )
  end

  # Inicia a queda do Míssil no centro da área atacada.
  #
  # @param row [Integer] linha usada como origem do ataque
  # @param col [Integer] coluna usada como origem do ataque
  # @return [void]
  def start_missile_attack_effect(row, col)
    enemy_board = @controller.game.enemy_board
    _player_x, enemy_x = @board_renderer.origins(enemy_board.size)
    target_cells = Missile.new.target_cells(row, col, enemy_board)

    @missile_attack_effect.start(
      board_size: enemy_board.size,
      board_x: enemy_x,
      target_cells: target_cells
    )
  end

  # Confere se o Avião ou o Míssil ainda estão sendo animados.
  #
  # @return [Boolean] true enquanto algum efeito estiver ativo
  def attack_effect_active?
    @airplane_attack_effect.active? || @missile_attack_effect.active?
  end

  # Transforma um evento de ataque em mensagens para o jogador.
  #
  # @param event [Game::AttackEvent] evento devolvido pelo jogo
  # @return [void]
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
  #
  # @param events [Array<Game::AttackEvent>] eventos da jogada atual
  # @return [void]
  def notify_game_over(events)
    return if @game_over_notified
    return unless events.any?(&:game_over?)

    if attack_effect_active?
      @pending_game_over = true
      return
    end

    complete_game_over_notification
  end

  # Finaliza a navegação quando uma animação do último ataque termina.
  #
  # @return [void]
  def notify_pending_game_over
    return unless @pending_game_over
    return if attack_effect_active?

    @pending_game_over = false
    complete_game_over_notification
  end

  # Executa o callback de encerramento uma única vez.
  #
  # @return [void]
  def complete_game_over_notification
    return if @game_over_notified

    @game_over_notified = true
    @on_game_over&.call(@controller.game)
  end

  # Converte linha e coluna para um texto como A1 ou C4.
  #
  # @param row [Integer] índice da linha
  # @param col [Integer] índice da coluna
  # @return [String] coordenada formatada
  def formatted_coordinate(row, col)
    letter = ("A".ord + col).chr

    "#{letter}#{row + 1}"
  end

  # Traduz o estado interno de uma célula para uma mensagem em português.
  #
  # @param status [Symbol] estado retornado pelo ataque
  # @return [String] descrição mostrada na tela
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

  # Calcula o tamanho e a posição dos botões laterais de armas.
  #
  # @return [Hash] limites dos botões preparados
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

  # Cria os dados de posição e escala de um botão com imagem.
  #
  # @param image [Gosu::Image] imagem usada no botão
  # @param y [Numeric] posição vertical do botão
  # @return [Hash] imagem, posição, tamanho e escala
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

  # Desenha o painel, os botões das armas e o controle de orientação.
  #
  # @return [void]
  def draw_special_weapon_controls
    draw_special_panel
    @weapon_buttons.each do |weapon, button|
      draw_special_weapon_button(weapon, button)
    end
    draw_orientation_button
  end

  # Desenha o fundo escuro e informa qual arma está selecionada.
  #
  # @return [void]
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

  # Carrega uma imagem da pasta de assets.
  #
  # @param name [String] nome do arquivo
  # @return [Gosu::Image] imagem carregada
  def load_image(name)
    Gosu::Image.new(File.join(ASSET_PATH, name))
  end

  # Carrega um efeito sonoro da pasta de trilhas.
  #
  # @param name [String] nome do arquivo de áudio
  # @return [Gosu::Sample] efeito sonoro carregado
  def load_sound(name)
    Gosu::Sample.new(File.join(SOUND_PATH, name))
  end

  # Toca o som do tiro básico ou das armas especiais.
  #
  # @param weapon [Weapon] arma usada no ataque
  # @return [void]
  def play_attack_sound(weapon)
    if weapon.is_a?(BasicShot)
      @basic_shot_sound.play(0.5)
    else
      @special_shot_sound.play(0.6)
    end
  end

  # Desenha a imagem de uma arma e seu estado habilitado ou desabilitado.
  #
  # @param weapon [Symbol] identificador da arma
  # @param button [Hash] dados visuais do botão
  # @return [void]
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

  # Desenha um brilho permanente ao redor da arma selecionada.
  #
  # @param button [Hash] dados visuais do botão
  # @return [void]
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

  # Desenha a quantidade restante sobre a imagem da arma.
  #
  # @param weapon [Symbol] :missile ou :airplane
  # @param button [Hash] dados visuais do botão
  # @return [void]
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

  # Desenha o botão que alterna o Avião entre linha e coluna.
  #
  # @return [void]
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

  # Monta o texto que informa a arma selecionada atualmente.
  #
  # @return [String] nome da arma selecionada
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

  # Descobre se o mouse está sobre alguma arma ou sobre a orientação.
  #
  # @param mouse_x [Numeric] posição horizontal do mouse
  # @param mouse_y [Numeric] posição vertical do mouse
  # @return [Symbol, nil] ação encontrada ou nil
  def weapon_action_at(mouse_x, mouse_y)
    return :orientation if inside_weapon_button?(@orientation_button, mouse_x, mouse_y)

    match = @weapon_buttons.find do |_action, button|
      inside_weapon_button?(button, mouse_x, mouse_y)
    end

    match&.first
  end

  # Verifica se o mouse está dentro dos limites de um botão.
  #
  # @param button [Hash] posição e tamanho do botão
  # @param mouse_x [Numeric] posição horizontal do mouse
  # @param mouse_y [Numeric] posição vertical do mouse
  # @return [Boolean] true quando o mouse está dentro
  def inside_weapon_button?(button, mouse_x, mouse_y)
    mouse_x >= button[:x] &&
      mouse_x < button[:x] + button[:width] &&
      mouse_y >= button[:y] &&
      mouse_y < button[:y] + button[:height]
  end

  # Seleciona uma arma, volta ao tiro básico ou altera a orientação.
  #
  # @param action [Symbol] ação escolhida pelo clique
  # @return [void]
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

  # Alterna a direção do Avião entre linha e coluna.
  #
  # @return [void]
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

  # Cria o objeto da arma selecionada para enviar ao controller.
  #
  # @return [BasicShot, Missile, Airplane] arma pronta para uso
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

  # Prepara as opções extras usadas pelo Avião.
  #
  # @return [Hash] orientação do Avião ou hash vazio
  def selected_weapon_options
    return {} unless @selected_weapon == :airplane

    { orientation: @airplane_orientation }
  end

  # Volta ao tiro básico quando todas as cargas da arma acabam.
  #
  # @return [void]
  def select_basic_shot_if_unavailable
    return if player_inventory.available?(@selected_weapon)

    @selected_weapon = :basic_shot
    @message_box.add("As cargas acabaram. Tiro básico selecionado.")
  end

  # Facilita o acesso ao inventário de armas do jogador.
  #
  # @return [WeaponInventory] inventário da partida atual
  def player_inventory
    @controller.game.player_inventory
  end

  # Traduz o identificador da arma para o nome mostrado na mensagem.
  #
  # @param action [Symbol] identificador da arma
  # @return [String] nome em português
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
