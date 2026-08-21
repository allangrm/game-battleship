# frozen_string_literal: true

require_relative "random_ai"

# Estratégia de IA média usada no mapa Lago.
#
# Implementa o comportamento Hunt/Target: durante a busca, utiliza a escolha
# aleatória herdada; depois de um :hit ainda não resolvido, investiga vizinhos
# ortogonais para encontrar a continuação do navio.
#
# Sua política de especiais é reativa. Usa Airplane quando existem ao menos dois
# acertos visíveis alinhados e Missile ao redor de um acerto isolado. Sem carga
# ou candidato válido, volta automaticamente ao tiro básico.
#
# A estratégia consulta apenas coordenadas, attacked? e status. Ela nunca acessa
# cell.ship ou cell.occupied?, portanto não conhece posições ocultas.
#
# @author Júlio Pedro
# @version 1.1
class HuntTargetAI < RandomAI
  # Deslocamentos ortogonais: cima, baixo, esquerda e direita.
  NEIGHBOR_OFFSETS = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1]
  ].freeze

  # Escolhe uma arma especial reativa ou um tiro Hunt/Target.
  #
  # A ordem dos operadores || também representa a prioridade da política:
  # Airplane alinhado, Missile próximo de hit, perseguição e busca aleatória.
  #
  # @param board [Board] tabuleiro-alvo observado por informações visíveis
  # @param inventory [WeaponInventory, nil] cargas pertencentes ao computador
  # @return [RandomAI::Decision]
  # @raise [RandomAI::NoAvailableCoordinateError] se não houver origem livre
  def choose_attack(board, inventory: nil)
    cells = available_cells(board)
    ensure_available_coordinate!(cells)

    special_decision = airplane_decision_for_aligned_hits(board, inventory) ||
                       missile_decision_near_visible_hit(board, inventory)
    return special_decision if special_decision

    target = random_cell(hunt_candidates(board)) || random_cell(cells)
    decision_for(target)
  end

  protected

  # Encontra vizinhos ortogonais ainda não atacados de todos os :hit ativos.
  # O uso de uniq impede que dois hits adjacentes gerem o mesmo candidato.
  #
  # @param board [Board]
  # @return [Array<Cell>] candidatos de perseguição
  def hunt_candidates(board)
    unresolved_hits(board).flat_map do |hit_cell|
      NEIGHBOR_OFFSETS.filter_map do |row_offset, col_offset|
        row = hit_cell.row + row_offset
        col = hit_cell.col + col_offset
        next unless board.valid_coordinate?(row, col)

        candidate = board.cell_at(row, col)
        candidate unless candidate.attacked?
      end
    end.uniq
  end
end
