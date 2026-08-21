# frozen_string_literal: true

require_relative "../models/map_config"
require_relative "../services/database"

# Busca as pontuações salvas e permite filtrar o ranking pelo tipo de mapa.
# Mantém a consulta ao banco separada da parte visual da tela.
#
# @author Raffael Wagner
# @version 1.0
class RankingController
  attr_reader :map_type, :entries

  # Cria o controller e carrega o ranking do mapa informado.
  #
  # @param map_type [Symbol, nil] mapa inicial ou nil para usar Poça
  # @return [RankingController] controller criado
  def initialize(map_type: nil)
    @map_type = map_type || :poca
    validate_map!
    load_entries
  end

  # Troca o mapa selecionado e atualiza os resultados mostrados.
  #
  # @param map_type [Symbol] mapa escolhido pelo jogador
  # @return [Array<Hash>] novas entradas do ranking
  def select_map(map_type)
    @map_type = map_type
    validate_map!
    load_entries
  end

  # Busca no banco as melhores pontuações do mapa atual.
  #
  # @return [Array<Hash>] lista ordenada de resultados
  def load_entries
    database = Database.new
    @entries = database.top_scores(map_type)
  ensure
    database&.close
  end

  private

  # Verifica se o mapa atual existe nas configurações do jogo.
  #
  # @return [void]
  # @raise [ArgumentError] quando o mapa é inválido
  def validate_map!
    return if MapConfig.available_maps.include?(map_type)

    raise ArgumentError, "Mapa inválido para o ranking: #{map_type.inspect}"
  end
end
