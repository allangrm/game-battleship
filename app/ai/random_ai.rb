# frozen_string_literal: true

require_relative "../weapons/basic_shot"
require_relative "special_weapon_targeting"

# Estratégia de IA fácil e classe-base das demais dificuldades.
#
# RandomAI escolhe aleatoriamente uma origem ainda não atacada e sempre usa
# BasicShot. Ela recebe o inventário para manter o mesmo contrato polimórfico
# das subclasses, mas deliberadamente preserva as armas especiais no nível
# introdutório da Poça.
#
# A classe também concentra utilitários protegidos reutilizados por HuntTargetAI
# e StrategicAI. O Board permanece como fonte de verdade do histórico, e a IA
# apenas lê estados já visíveis.
#
# @author Júlio Pedro
# @version 1.3
class RandomAI
  include SpecialWeaponTargeting

  # Erro defensivo para um tabuleiro sem nenhuma origem disponível.
  class NoAvailableCoordinateError < StandardError; end

  # Intenção imutável produzida pela IA e consumida por Game#computer_attack.
  # A IA escolhe, mas não executa a arma nem consome sua carga.
  Decision = Struct.new(:row, :col, :weapon, :options, keyword_init: true)

  # @param random [Random] fonte injetável para escolhas reproduzíveis em testes
  def initialize(random: Random.new)
    @random = random
  end

  # Escolhe um tiro básico aleatório entre as origens disponíveis.
  #
  # @param board [Board] tabuleiro-alvo observado somente por estado visível
  # @param inventory [WeaponInventory, nil] aceito por compatibilidade polimórfica
  # @return [Decision] origem e BasicShot prontos para Game
  # @raise [NoAvailableCoordinateError] se todas as células foram atacadas
  def choose_attack(board, inventory: nil)
    cells = available_cells(board)
    ensure_available_coordinate!(cells)

    decision_for(random_cell(cells))
  end

  protected

  # Disponibilizado às subclasses e ao módulo de armas especiais para que todas
  # as escolhas aleatórias usem a mesma fonte injetada.
  attr_reader :random

  # @param board [Board]
  # @return [Array<Cell>] células que ainda podem ser usadas como origem
  def available_cells(board)
    board.grid.flatten.reject(&:attacked?)
  end

  # @raise [NoAvailableCoordinateError] quando a lista está vazia
  def ensure_available_coordinate!(cells)
    return unless cells.empty?

    raise NoAvailableCoordinateError, "Não existem coordenadas disponíveis"
  end

  # Escolhe um candidato usando a fonte Random da instância.
  #
  # @param cells [Array<Cell>]
  # @return [Cell, nil]
  def random_cell(cells)
    cells.sample(random: random)
  end

  # Constrói a fronteira estável entre a escolha da IA e a execução por Game.
  #
  # @param cell [Cell] origem ainda não atacada
  # @param weapon [Weapon] arma escolhida
  # @param options [Hash] opções específicas da arma
  # @return [Decision] decisão e opções congeladas
  def decision_for(cell, weapon: BasicShot.new, options: {})
    Decision.new(
      row: cell.row,
      col: cell.col,
      weapon: weapon,
      options: options.freeze
    ).freeze
  end
end
