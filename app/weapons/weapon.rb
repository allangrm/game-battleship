# frozen_string_literal: true

# Classe-base do contrato polimórfico de armas.
#
# Uma Weapon calcula somente a geometria de um ataque. Ela não consulta cargas,
# não controla turno e não altera Cell/Ship. AttackHandler recebe as coordenadas
# retornadas e delega o dano a Board, preservando uma única fonte de verdade.
#
# Para adicionar outra arma, a subclasse deve implementar #target_cells. O
# restante do pipeline de Game e AttackHandler não precisa conhecer sua classe
# concreta, demonstrando polimorfismo e o princípio aberto/fechado.
#
# @author Júlio Pedro
# @version 1.1
class Weapon
  # Produz o identificador estável usado por inventários e eventos.
  #
  # A conversão transforma nomes CamelCase em snake_case. Por exemplo,
  # BasicShot se torna :basic_shot.
  #
  # @return [Symbol]
  def identifier
    self.class.name
        .split("::")
        .last
        .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
        .downcase
        .to_sym
  end

  # Calcula as coordenadas atingidas pela arma.
  #
  # @param row [Integer] linha da origem
  # @param col [Integer] coluna da origem
  # @param board [Board] tabuleiro usado apenas para limites e dimensões
  # @param _opts [Hash] opções específicas da subclasse
  # @return [Array<Array(Integer, Integer)>] pares [linha, coluna]
  # @raise [NotImplementedError] quando a subclasse não implementa o contrato
  def target_cells(row, col, board, **_opts)
    raise NotImplementedError, "#{self.class} precisa implementar #target_cells"
  end

  private

  # Descarta alvos que ultrapassam os limites do Board.
  # Isso permite que armas de área sejam recortadas nas bordas.
  #
  # @param coordinates [Array<Array(Integer, Integer)>] candidatos brutos
  # @param board [Board]
  # @return [Array<Array(Integer, Integer)>] somente coordenadas válidas
  # @api private
  def valid_cells(coordinates, board)
    coordinates.select { |target_row, target_col| board.valid_coordinate?(target_row, target_col) }
  end
end
