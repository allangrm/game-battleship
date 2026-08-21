# frozen_string_literal: true

require_relative "../models/map_config"
require_relative "../services/database"

class RankingController
  attr_reader :map_type, :entries

  def initialize(map_type: nil)
    @map_type = map_type || :poca
    validate_map!
    load_entries
  end

  def select_map(map_type)
    @map_type = map_type
    validate_map!
    load_entries
  end

  def load_entries
    database = Database.new
    @entries = database.top_scores(map_type)
  ensure
    database&.close
  end

  private

  def validate_map!
    return if MapConfig.available_maps.include?(map_type)

    raise ArgumentError, "Mapa inválido para o ranking: #{map_type.inspect}"
  end
end