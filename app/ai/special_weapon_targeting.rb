# frozen_string_literal: true

require_relative "../weapons/missile"
require_relative "../weapons/airplane"

# Mixin que compartilha os cálculos de alvo das armas especiais entre as IAs.
#
# O módulo separa mecanismo de política:
#
# - este módulo sabe encontrar boas origens para Missile e Airplane;
# - HuntTargetAI e StrategicAI decidem em que ordem tentar essas opções;
# - Game continua responsável por validar, executar e consumir a arma.
#
# Todos os escores usam somente cobertura ainda não atacada e estados :hit já
# visíveis. Nenhum método consulta navios ou células ocupadas ocultas, evitando
# que o aumento de dificuldade se transforme em informação privilegiada.
#
# @author Júlio Pedro
# @version 1.0
module SpecialWeaponTargeting
  protected

  # Escolhe Airplane quando há ao menos dois hits na mesma linha/coluna.
  #
  # @param board [Board]
  # @param inventory [WeaponInventory, nil]
  # @return [RandomAI::Decision, nil] nil permite o próximo fallback da IA
  def airplane_decision_for_aligned_hits(board, inventory)
    return unless special_available?(inventory, :airplane)

    lines = visible_hit_lines(board, minimum_hits: 2)
    build_airplane_decision(lines)
  end

  # Escolhe a melhor linha/coluna que contenha ao menos um hit visível.
  # Usado pela IA difícil quando Missile não resolveu a prioridade anterior.
  #
  # @return [RandomAI::Decision, nil]
  def airplane_decision_for_visible_hit(board, inventory)
    return unless special_available?(inventory, :airplane)

    lines = visible_hit_lines(board, minimum_hits: 1)
    build_airplane_decision(lines)
  end

  # Escolhe proativamente a linha/coluna com maior número de células livres.
  #
  # @return [RandomAI::Decision, nil]
  def best_airplane_decision(board, inventory)
    return unless special_available?(inventory, :airplane)

    build_airplane_decision(all_lines(board))
  end

  # Procura blocos 2x2 que incluam um hit ainda não resolvido.
  #
  # Os deslocamentos -1/0 representam as quatro posições em que um hit pode
  # aparecer dentro de um bloco cujo clique indica o canto superior esquerdo.
  # Origens fora do Board ou já atacadas são removidas posteriormente.
  #
  # @return [RandomAI::Decision, nil]
  def missile_decision_near_visible_hit(board, inventory)
    return unless special_available?(inventory, :missile)

    origins = unresolved_hits(board).flat_map do |hit_cell|
      [-1, 0].product([-1, 0]).map do |row_offset, col_offset|
        [hit_cell.row + row_offset, hit_cell.col + col_offset]
      end
    end

    build_missile_decision(board, origins)
  end

  # Escolhe proativamente o bloco 2x2 com maior cobertura ainda não atacada.
  #
  # @return [RandomAI::Decision, nil]
  def best_missile_decision(board, inventory)
    return unless special_available?(inventory, :missile)

    origins = available_cells(board).map { |cell| [cell.row, cell.col] }
    build_missile_decision(board, origins)
  end

  # Seleciona apenas :hit. Células :sunk pertencem a navios já resolvidos e não
  # devem continuar guiando a perseguição.
  #
  # @param board [Board]
  # @return [Array<Cell>]
  def unresolved_hits(board)
    board.grid.flatten.select { |cell| cell.status == :hit }
  end

  private

  # Consulta a carga sem modificar o inventário.
  #
  # @return [Boolean, nil] nil quando nenhum inventário foi fornecido
  # @api private
  def special_available?(inventory, identifier)
    inventory && inventory.available?(identifier)
  end

  # Pontua linhas/colunas pela quantidade de células ainda não atacadas.
  #
  # A origem precisa ser livre porque AttackHandler rejeita uma origem repetida,
  # mesmo que existam outras células disponíveis dentro da linha/coluna. Em
  # empate de cobertura, random_maximum preserva variedade de partidas.
  #
  # @param lines [Array<Hash>] orientation e coleção de cells por candidato
  # @return [RandomAI::Decision, nil]
  # @api private
  def build_airplane_decision(lines)
    candidates = lines.filter_map do |line|
      available = line.fetch(:cells).reject(&:attacked?)
      next if available.empty?

      line.merge(available: available, score: available.length)
    end
    selected = random_maximum(candidates) { |candidate| candidate.fetch(:score) }
    return unless selected

    origin = random_cell(selected.fetch(:available))
    decision_for(
      origin,
      weapon: Airplane.new,
      options: { orientation: selected.fetch(:orientation) }
    )
  end

  # Pontua possíveis origens pela cobertura válida e ainda não atacada do 2x2.
  #
  # @param board [Board]
  # @param origins [Array<Array(Integer, Integer)>] cantos superiores esquerdos
  # @return [RandomAI::Decision, nil]
  # @api private
  def build_missile_decision(board, origins)
    missile = Missile.new
    candidates = origins.uniq.filter_map do |row, col|
      next unless board.valid_coordinate?(row, col)

      origin = board.cell_at(row, col)
      next if origin.attacked?

      targets = missile.target_cells(row, col, board)
      score = targets.count do |target_row, target_col|
        !board.cell_at(target_row, target_col).attacked?
      end
      { origin: origin, score: score }
    end
    selected = random_maximum(candidates) { |candidate| candidate.fetch(:score) }
    return unless selected

    decision_for(selected.fetch(:origin), weapon: missile)
  end

  # Constrói candidatos de linha/coluna que atendem a uma evidência mínima.
  #
  # @param board [Board]
  # @param minimum_hits [Integer] quantidade mínima de :hit na mesma direção
  # @return [Array<Hash>] linhas/colunas com orientation e cells
  # @api private
  def visible_hit_lines(board, minimum_hits:)
    hits = unresolved_hits(board)
    rows = hits.group_by(&:row).filter_map do |row, row_hits|
      next if row_hits.length < minimum_hits

      { orientation: :row, cells: board.grid.fetch(row) }
    end
    columns = hits.group_by(&:col).filter_map do |col, col_hits|
      next if col_hits.length < minimum_hits

      { orientation: :col, cells: board.grid.map { |row| row.fetch(col) } }
    end

    rows + columns
  end

  # Enumera todas as linhas e colunas para a busca proativa da IA difícil.
  #
  # @param board [Board]
  # @return [Array<Hash>] candidatos com orientation e cells
  # @api private
  def all_lines(board)
    rows = board.grid.map { |cells| { orientation: :row, cells: cells } }
    columns = (0...board.size).map do |col|
      { orientation: :col, cells: board.grid.map { |row| row.fetch(col) } }
    end

    rows + columns
  end

  # Seleciona aleatoriamente entre os candidatos de maior pontuação.
  #
  # @param candidates [Array<Object>]
  # @yieldparam candidate [Object]
  # @yieldreturn [Numeric] pontuação comparável
  # @return [Object, nil]
  # @api private
  def random_maximum(candidates)
    return if candidates.empty?

    maximum = candidates.map { |candidate| yield(candidate) }.max
    candidates.select { |candidate| yield(candidate) == maximum }.sample(random: random)
  end
end
