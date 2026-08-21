# frozen_string_literal: true

# Representa uma casa/célula do tabuleiro.
#
# A célula armazena apenas estado: posição, possível embarcação e resultado do
# ataque. As regras que combinam várias células permanecem em Board.
#
# Estados utilizados durante a partida:
# - :unknown: ainda não atacada;
# - :miss: ataque na água;
# - :hit: segmento de navio atingido;
# - :sunk: segmento pertencente a um navio totalmente afundado.
#
# @author Allan Guilherme
# @version 1.1
class Cell
  attr_reader :row, :col
  attr_accessor :ship, :status

  # Cria uma posição inicialmente livre e ainda não atacada.
  #
  # @param row [Integer] índice da linha na matriz
  # @param col [Integer] índice da coluna na matriz
  def initialize(row, col)
    @row = row
    @col = col
    @ship = nil
    @status = :unknown
  end

  # Informa se a posição já pertence a uma embarcação.
  #
  # A ausência de `ship` representa uma célula livre; não é necessário manter
  # um segundo atributo booleano que poderia ficar dessincronizado.
  #
  # @return [Boolean]
  def occupied?
    !ship.nil?
  end

  # Informa se a célula já recebeu algum resultado de ataque.
  #
  # @return [Boolean] false somente enquanto o estado for :unknown
  def attacked?
    status != :unknown
  end
end
