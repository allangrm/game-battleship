# frozen_string_literal: true

# Representa um navio posicionado no tabuleiro.
#
# Todas as embarcações compartilham o mesmo comportamento e variam por dados
# (`name` e `size`). Por isso Barco, Fragata, Corveta e Submarino não precisam
# de subclasses enquanto não possuírem habilidades próprias.
#
# @author Allan Guilherme
# @version 1.1
class Ship
  attr_reader :name, :size, :cells, :hits

  # Cria uma embarcação ainda não posicionada e sem danos.
  #
  # @param name [String] nome apresentado ao jogador
  # @param size [Integer] quantidade de células ocupadas
  # @raise [ArgumentError] quando o tamanho não é um inteiro positivo
  def initialize(name, size)
    raise ArgumentError, "O tamanho do navio deve ser positivo" unless size.is_a?(Integer) && size.positive?

    @name = name
    @size = size
    @cells = []
    @hits = 0
  end

  # Associa o navio às células previamente validadas pelo Board.
  #
  # A geometria e a sobreposição não são verificadas aqui porque Ship não
  # conhece a matriz completa. Board#place_ship possui o contexto necessário.
  #
  # @param cells [Array<Cell>] células consecutivas ocupadas pelo navio
  # @return [Ship] o próprio objeto, permitindo encadeamento
  # @raise [ArgumentError] se a quantidade for incorreta ou o navio já estiver
  #   posicionado
  def place(cells)
    raise ArgumentError, "Quantidade de células diferente do tamanho do navio" unless cells.length == size
    raise ArgumentError, "Navio já está posicionado" if placed?

    @cells = cells
    cells.each { |cell| cell.ship = self }
    self
  end

  # Registra dano em um único segmento.
  #
  # O limite impede que `hits` ultrapasse `size`. Ataques repetidos já são
  # bloqueados pelo Board, mas esta guarda mantém Ship consistente isoladamente.
  #
  # @return [Integer] quantidade atual de acertos
  def register_hit
    @hits += 1 unless sunk?
  end

  # @return [Boolean] true quando todos os segmentos foram atingidos
  def sunk?
    hits >= size
  end

  # Quantifica a integridade restante usada também no cálculo de pontuação.
  #
  # @return [Integer] quantidade de segmentos ainda intactos, nunca negativa
  def remaining_cells
    [size - hits, 0].max
  end

  # @return [Boolean] true quando o navio está associado a alguma célula
  def placed?
    !cells.empty?
  end

  # Desfaz o posicionamento durante o setup.
  #
  # É usado por Board#remove_ship e pelo rollback do posicionamento automático.
  # Cada referência é removida somente se ainda apontar para este objeto, o que
  # evita liberar acidentalmente uma célula que tenha sido reassociada.
  #
  # @return [Ship] o navio novamente livre e sem danos
  def unplace
    cells.each { |cell| cell.ship = nil if cell.ship.equal?(self) }
    @cells = []
    @hits = 0
    self
  end
end
