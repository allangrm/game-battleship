# frozen_string_literal: true

require_relative "../models/board"

# Sinaliza que a origem escolhida não pode iniciar um ataque.
# É tratada pela interface como erro recuperável de jogada.
#
# @author Júlio Pedro
# @version 1.0
class InvalidAttackError < StandardError; end

# Aplica uma arma a um Board sem conhecer o tipo concreto da arma.
#
# Sua responsabilidade é coordenar três contratos:
#
# - validar a coordenada usada como origem da ação;
# - pedir à Weapon a lista polimórfica de coordenadas-alvo;
# - delegar cada alteração de estado a Board#receive_attack.
#
# A origem fora dos limites ou já atacada invalida toda a ação. Em contrapartida,
# uma célula secundária já atacada dentro da área de Míssil/Avião é simplesmente
# ignorada. Isso evita dano e contagem duplicados sem desperdiçar uma ação cuja
# origem era válida.
#
# @author Júlio Pedro
# @version 1.1
class AttackHandler
  # Resultado interno que ainda referencia a Cell alterada pelo Board.
  # Game converte esse objeto em um CellResult imutável antes de expô-lo.
  AttackResult = Struct.new(:cell, :status) do
    # @return [Boolean] true quando o estado representa dano
    def hit?
      %i[hit sunk].include?(status)
    end

    # Compatibilidade com o contrato anterior, que expunha `hit` como booleano.
    alias hit hit?
  end

  # @param board [Board] tabuleiro que receberá o ataque
  def initialize(board)
    @board = board
  end

  # Executa uma ativação completa de arma.
  #
  # Retorna apenas resultados de células que realmente mudaram de estado. Em
  # armas de área, coordenadas inválidas já são removidas pela Weapon e células
  # secundárias repetidas são filtradas neste handler.
  #
  # @param row [Integer] linha da origem selecionada
  # @param col [Integer] coluna da origem selecionada
  # @param weapon [Weapon] objeto que calcula a área do ataque
  # @param opts [Hash] opções específicas da arma
  # @return [Array<AttackResult>] alterações produzidas pelo Board
  # @raise [InvalidAttackError] se a origem estiver fora do mapa ou repetida
  # @raise [ArgumentError] se uma opção da arma for inválida
  def attack(row, col, weapon, **opts)
    validate!(row, col)

    weapon.target_cells(row, col, @board, **opts).filter_map do |target_row, target_col|
      resolve_attack(target_row, target_col)
    end
  end

  private

  # Valida apenas a origem da ativação. As demais coordenadas são calculadas
  # pela arma e protegidas novamente por Board#receive_attack.
  #
  # @api private
  def validate!(row, col)
    unless @board.valid_coordinate?(row, col)
      raise InvalidAttackError, "Coordenada fora do tabuleiro: (#{row}, #{col})"
    end

    return unless @board.cell_at(row, col).attacked?

    raise InvalidAttackError, "Coordenada (#{row}, #{col}) já foi atacada"
  end

  # Converte a resposta simbólica de Board em AttackResult quando houve mudança.
  #
  # @return [AttackResult, nil]
  # @api private
  def resolve_attack(row, col)
    status = @board.receive_attack(row, col)
    return nil if %i[invalid already_attacked].include?(status)

    AttackResult.new(@board.cell_at(row, col), status)
  end
end
