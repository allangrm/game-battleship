# frozen_string_literal: true

require_relative "cell"
require_relative "ship"

# Representa o tabuleiro e concentra as invariantes de posicionamento e ataque.
# Controllers podem escolher coordenadas, mas somente o Board altera Cell/Ship.
#
# Essa classe é a fonte de verdade do domínio para a matriz. A centralização
# garante que posicionamento manual, automático e ataques utilizem as mesmas
# regras, independentemente da tela ou do participante que iniciou a ação.
#
# @author Allan Guilherme
# @version 1.1
class Board
  class AutoPlacementError < StandardError; end

  ORIENTATIONS = %i[horizontal vertical].freeze
  DEFAULT_AUTO_PLACEMENT_ATTEMPTS = 1_000

  attr_reader :size, :grid, :ships

  # Cria uma matriz quadrada de células independentes.
  #
  # @param size [Integer] quantidade de linhas e colunas
  # @raise [ArgumentError] quando o tamanho não é um inteiro positivo
  def initialize(size)
    raise ArgumentError, "O tamanho do tabuleiro deve ser positivo" unless size.is_a?(Integer) && size.positive?

    @size = size
    @grid = Array.new(size) { |row| Array.new(size) { |col| Cell.new(row, col) } }
    @ships = []
  end

  # Verifica tipo e limites antes de qualquer acesso à matriz.
  #
  # A checagem explícita também impede que índices negativos, válidos para
  # arrays Ruby, sejam interpretados como coordenadas do jogo.
  #
  # @param row [Object]
  # @param col [Object]
  # @return [Boolean]
  def valid_coordinate?(row, col)
    row.is_a?(Integer) && col.is_a?(Integer) &&
      row.between?(0, size - 1) && col.between?(0, size - 1)
  end

  # Recupera uma célula somente quando a coordenada pertence ao tabuleiro.
  #
  # @return [Cell, nil]
  def cell_at(row, col)
    return nil unless valid_coordinate?(row, col)

    grid[row][col]
  end

  # Posiciona definitivamente um navio em células válidas e livres.
  #
  # A validação ocorre antes de qualquer mutação. Depois dela, Ship recebe os
  # objetos Cell e Board registra o navio exatamente uma vez.
  #
  # @param ship [Ship]
  # @param coordinates [Array<Array<Integer>>]
  # @return [Ship]
  # @raise [ArgumentError] para navio já posicionado ou posição inválida
  def place_ship(ship, coordinates)
    raise ArgumentError, "Navio já está posicionado" if ship.placed?
    raise ArgumentError, "Posição inválida para o navio" unless valid_placement?(ship, coordinates)

    cells = coordinates.map { |row, col| cell_at(row, col) }
    ship.place(cells)
    @ships << ship
    ship
  end

  # Remove um navio durante o setup e libera suas células.
  #
  # A verificação global de ataques impede que uma alteração de setup corrompa
  # uma partida que já começou.
  #
  # @param ship [Ship]
  # @return [Ship]
  # @raise [ArgumentError] se o navio não pertence ao Board ou já houve ataque
  def remove_ship(ship)
    unless @ships.include?(ship)
      raise ArgumentError, "Navio não pertence a este tabuleiro"
    end

    if grid.flatten.any?(&:attacked?)
      raise ArgumentError, "Não é possível remover um navio depois do início da partida"
    end

    @ships.delete(ship)
    ship.unplace
    ship
  end

  # Move um navio durante o setup. Se a nova posição for inválida, restaura a
  # posição anterior para não deixar o tabuleiro em um estado parcial.
  #
  # @param ship [Ship]
  # @param coordinates [Array<Array<Integer>>] nova posição desejada
  # @return [Ship]
  def reposition_ship(ship, coordinates)
    # As coordenadas são copiadas antes da remoção porque Ship#unplace esvazia
    # a lista de células do navio.
    previous_coordinates = ship.cells.map { |cell| [cell.row, cell.col] }

    remove_ship(ship)
    place_ship(ship, coordinates)
  rescue StandardError
    # O rollback só ocorre se havia posição anterior e o navio continua livre.
    place_ship(ship, previous_coordinates) if previous_coordinates&.any? && !ship.placed?
    raise
  end

  # Posiciona uma frota de forma aleatória e limitada. Em caso de falha, todos
  # os navios posicionados por esta chamada são removidos para manter o Board
  # consistente e permitir uma nova tentativa.
  #
  # O objeto Random é injetável para que testes utilizem sementes reproduzíveis.
  # O limite por navio evita um loop infinito quando a frota não cabe.
  #
  # @param fleet [Array<Ship>] navios ainda não posicionados
  # @param random [Random] gerador usado na escolha das posições
  # @param max_attempts_per_ship [Integer] limite individual de tentativas
  # @return [Array<Ship>] lista atual de navios do tabuleiro
  # @raise [AutoPlacementError] quando algum navio não encontra posição
  def auto_place_ships(
    fleet,
    random: Random.new,
    max_attempts_per_ship: DEFAULT_AUTO_PLACEMENT_ATTEMPTS
  )
    unless max_attempts_per_ship.is_a?(Integer) && max_attempts_per_ship.positive?
      raise ArgumentError, "O limite de tentativas deve ser positivo"
    end

    # Somente navios adicionados por esta operação participam do rollback; uma
    # frota anteriormente existente no Board permanece intacta.
    placed_in_this_call = []

    begin
      fleet.each do |ship|
        placed = try_auto_place_ship(ship, random, max_attempts_per_ship)
        raise AutoPlacementError, "Não foi possível posicionar o navio #{ship.name}" unless placed

        placed_in_this_call << ship
      end
    rescue StandardError
      rollback_auto_placements(placed_in_this_call)
      raise
    end

    ships
  end

  # Decide se um conjunto de coordenadas respeita todas as invariantes.
  #
  # A ordem das verificações é intencional: formato, quantidade e limites são
  # confirmados antes de acessar Cell. Depois são verificadas ocupação,
  # orientação e continuidade.
  #
  # @param ship [Ship]
  # @param coordinates [Object]
  # @return [Boolean]
  def valid_placement?(ship, coordinates)
    return false unless coordinates.is_a?(Array)
    return false unless coordinates.length == ship.size
    return false unless coordinates.all? { |row, col| valid_coordinate?(row, col) }
    return false if coordinates.any? { |row, col| cell_at(row, col).occupied? }

    rows = coordinates.map(&:first)
    cols = coordinates.map(&:last)
    horizontal = rows.uniq.length == 1
    vertical = cols.uniq.length == 1
    return false unless horizontal || vertical

    # Ordenar o eixo permite validar continuidade mesmo que as coordenadas
    # tenham sido recebidas em ordem inversa. Diferença diferente de 1 indica
    # lacuna ou coordenada duplicada.
    axis = horizontal ? cols.sort : rows.sort
    axis.each_cons(2).all? { |first, second| second - first == 1 }
  end

  # Fonte de verdade do ataque a uma célula.
  #
  # A validação de repetição acontece antes do dano, garantindo que Ship#hits
  # não seja incrementado duas vezes para o mesmo segmento.
  #
  # @param row [Object]
  # @param col [Object]
  # @return [Symbol] :hit, :miss, :sunk, :invalid ou :already_attacked
  def receive_attack(row, col)
    return :invalid unless valid_coordinate?(row, col)

    cell = cell_at(row, col)
    return :already_attacked if cell.attacked?

    if cell.occupied?
      resolve_hit(cell)
    else
      cell.status = :miss
      :miss
    end
  end

  # Gera uma sequência horizontal ou vertical a partir de uma origem.
  #
  # Este método é compartilhado pelo setup manual e pelo automático. Ele apenas
  # monta coordenadas e verifica limites; sobreposição e geometria final são
  # confirmadas novamente por #valid_placement?.
  #
  # @param row [Integer] linha inicial
  # @param col [Integer] coluna inicial
  # @param length [Integer] quantidade de segmentos
  # @param orientation [Symbol] :horizontal ou :vertical
  # @return [Array<Array<Integer>>, nil]
  def generate_coordinates(row, col, length, orientation)
    return nil unless ORIENTATIONS.include?(orientation)

    coordinates = (0...length).map do |offset|
      if orientation == :horizontal
        [row, col + offset]
      else
        [row + offset, col]
      end
    end

    return nil unless coordinates.all? { |candidate_row, candidate_col| valid_coordinate?(candidate_row, candidate_col) }

    coordinates
  end

  # Informa derrota somente quando existe uma frota e todos os navios afundaram.
  # Um Board vazio, portanto, nunca é tratado como frota destruída.
  #
  # @return [Boolean]
  def all_ships_sunk?
    ships.any? && ships.all?(&:sunk?)
  end

  # @return [Integer] navios cuja quantidade de acertos ainda é menor que o tamanho
  def ships_remaining
    ships.count { |ship| !ship.sunk? }
  end

  private

  # Procura uma posição aleatória válida para um único navio.
  #
  # @return [Boolean] true na primeira colocação válida; false após o limite
  def try_auto_place_ship(ship, random, max_attempts)
    max_attempts.times do
      orientation = ORIENTATIONS.sample(random: random)
      row = random.rand(size)
      col = random.rand(size)
      coordinates = generate_coordinates(row, col, ship.size, orientation)
      next unless coordinates && valid_placement?(ship, coordinates)

      place_ship(ship, coordinates)
      return true
    end

    false
  end

  # Desfaz em ordem inversa apenas os posicionamentos desta operação.
  def rollback_auto_placements(placed_ships)
    placed_ships.reverse_each { |ship| remove_ship(ship) }
  end

  # Aplica dano e promove todas as células para :sunk no último acerto.
  #
  # @return [Symbol] :hit ou :sunk
  def resolve_hit(cell)
    ship = cell.ship
    cell.status = :hit
    ship.register_hit

    return :hit unless ship.sunk?

    ship.cells.each { |ship_cell| ship_cell.status = :sunk }
    :sunk
  end
end
