# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"

class DatabaseTest < Minitest::Test
  def setup
    @database = Database.new(path: ":memory:")
  end

  def teardown
    @database.close
  end

  def test_saves_player_and_complete_match_data
    match_id = @database.save_match(
      player_name: "  Allan  ",
      map_type: :poca,
      result: :vitoria,
      score: 2_500,
      duration_seconds: 75
    )

    entry = @database.top_scores(:poca).first

    assert_operator match_id, :>, 0
    assert_equal match_id, entry[:id]
    assert_equal "Allan", entry[:name]
    assert_equal "poca", entry[:map_type]
    assert_equal "vitoria", entry[:result]
    assert_equal 2_500, entry[:score]
    assert_equal 75, entry[:duration_seconds]
    refute_nil entry[:played_at]
  end

  def test_ranking_filters_by_map_and_uses_duration_as_tiebreaker
    save_match("Pontuacao menor", :poca, score: 900, duration_seconds: 20)
    save_match("Empate lento", :poca, score: 1_000, duration_seconds: 80)
    save_match("Empate rapido", :poca, score: 1_000, duration_seconds: 40)
    save_match("Outro mapa", :lago, score: 9_999, duration_seconds: 1)

    ranking = @database.top_scores(:poca)

    assert_equal ["Empate rapido", "Empate lento", "Pontuacao menor"], ranking.map { |entry| entry[:name] }
    assert ranking.all? { |entry| entry[:map_type] == "poca" }
  end

  def test_ranking_respects_limit
    3.times do |index|
      save_match("Jogador #{index}", :oceano, score: index, duration_seconds: 10)
    end

    assert_equal 2, @database.top_scores(:oceano, limit: 2).length
  end

  def test_database_persists_data_after_reopening_file
    Dir.mktmpdir("battleship_database_test") do |directory|
      database_path = File.join(directory, "nested", "matches.sqlite3")
      database = Database.new(path: database_path)
      database.save_match(
        player_name: "Persistente",
        map_type: :lago,
        result: :derrota,
        score: 750,
        duration_seconds: 125
      )
      database.close

      reopened_database = Database.new(path: database_path)
      entry = reopened_database.top_scores(:lago).first

      assert_equal "Persistente", entry[:name]
      assert_equal "derrota", entry[:result]
      assert_equal 750, entry[:score]
      assert_equal 125, entry[:duration_seconds]
    ensure
      reopened_database&.close
      database&.close
    end
  end

  def test_reuses_player_record_for_the_same_normalized_name
    save_match("Allan", :poca, score: 100, duration_seconds: 30)
    save_match("  allan  ", :poca, score: 200, duration_seconds: 20)

    ranking = @database.top_scores(:poca)

    assert_equal 1, ranking.map { |entry| entry[:player_id] }.uniq.length
    assert_equal ["Allan", "Allan"], ranking.map { |entry| entry[:name] }
  end

  def test_rejects_invalid_match_data
    valid_attributes = {
      player_name: "Allan",
      map_type: :poca,
      result: :vitoria,
      score: 100,
      duration_seconds: 10
    }

    invalid_attributes = [
      { player_name: "   " },
      { map_type: :rio },
      { result: :abandono },
      { score: -1 },
      { duration_seconds: -1 }
    ]

    invalid_attributes.each do |attributes|
      assert_raises(ArgumentError) do
        @database.save_match(**valid_attributes.merge(attributes))
      end
    end
  end

  def test_rejects_invalid_ranking_limit
    assert_raises(ArgumentError) { @database.top_scores(:poca, limit: 0) }
    assert_raises(ArgumentError) { @database.top_scores(:poca, limit: 101) }
  end

  def test_rejects_operations_after_close
    @database.close

    assert_raises(IOError) { @database.top_scores(:poca) }
  end

  private

  def save_match(name, map_type, score:, duration_seconds:)
    @database.save_match(
      player_name: name,
      map_type: map_type,
      result: :vitoria,
      score: score,
      duration_seconds: duration_seconds
    )
  end
end
