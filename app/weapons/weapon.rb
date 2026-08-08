# frozen_string_literal: true

# Classe abstrata, define o contrato geralpara todas a s armas do jogo
#
# @author Júlio Pedro
# @version 1.0
# @since 07-08-2026
class Weapon
  # row e col são as coordenadas clicadas
  # Board é o tabuleiro da partida 
  # Retorna uma lista de coordenadas [[row, col], ...] candidatas, já filtradas para dentro do tabuleiro.
  def target_cells(row, col, board, **opts)
    raise NotImplementedError, '{#self.class} PRECISA IMPLEMENTAR #target_cells'
  end

  private 

  # validação de coordenadas para as armas de área.
  def valid_cells(coordinates, board)
    coordinates.select { |(row, col)| board.valid_coordinate?(row, col)}
  end

end