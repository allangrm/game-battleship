# frozen_string_literal: true

require "fileutils"
require "sqlite3"

# Encapsula a persistencia SQLite usada pelo ranking (RF11, RF12 e RNF01).
# A classe usa SQL puro e inicializa o schema ao abrir a conexao.
#
# Não existe uma tabela separada de ranking: ele é derivado das partidas por
# uma consulta ordenada. Isso evita duplicação e inconsistência de dados.
#
# @author Allan Guilherme
# @version 1.0
class Database
  DEFAULT_PATH = File.expand_path("../../database/battleship.sqlite3", __dir__)
  DEFAULT_SCHEMA_PATH = File.expand_path("../../database/schema.sql", __dir__)
  MAP_TYPES = %w[poca lago oceano].freeze
  RESULTS = %w[vitoria derrota].freeze
  DEFAULT_RANKING_LIMIT = 10
  MAX_RANKING_LIMIT = 100

  attr_reader :path

  # Abre ou cria o banco e aplica o schema idempotente.
  #
  # O caminho pode ser substituído por `:memory:` ou arquivo temporário nos
  # testes. Chaves estrangeiras são ativadas explicitamente em cada conexão.
  #
  # @param path [String] caminho do SQLite ou :memory:
  # @param schema_path [String] arquivo SQL com tabelas, constraints e índice
  # @raise [StandardError] repassa falhas depois de liberar a conexão parcial
  def initialize(path: DEFAULT_PATH, schema_path: DEFAULT_SCHEMA_PATH)
    @path = normalize_path(path)
    prepare_parent_directory!
    @connection = SQLite3::Database.new(@path)
    @connection.busy_timeout(5_000)
    @connection.results_as_hash = true
    @connection.execute("PRAGMA foreign_keys = ON")
    initialize_schema!(schema_path)
  rescue StandardError
    close
    raise
  end

  # Salva o jogador e sua partida em uma unica transacao.
  #
  # A transação mantém jogador e partida como uma única operação lógica. Os
  # placeholders `?` enviam valores separadamente do SQL e evitam concatenação
  # de entradas fornecidas pelo usuário.
  #
  # @param player_name [String]
  # @param map_type [String, Symbol] poca, lago ou oceano
  # @param result [String, Symbol] vitoria ou derrota
  # @param score [Integer] pontuação não negativa
  # @param duration_seconds [Integer] duração não negativa
  # @return [Integer] id da partida criada
  # @raise [ArgumentError] quando algum dado não respeita o contrato
  def save_match(player_name:, map_type:, result:, score:, duration_seconds:)
    ensure_open!
    name = normalize_player_name(player_name)
    normalized_map_type = normalize_option(:map_type, map_type, MAP_TYPES)
    normalized_result = normalize_option(:result, result, RESULTS)
    validate_non_negative_integer!(:score, score)
    validate_non_negative_integer!(:duration_seconds, duration_seconds)

    match_id = nil
    @connection.transaction do
      # O mesmo jogador é reutilizado, mas cada execução sempre cria uma nova
      # linha em matches para preservar o histórico de partidas.
      player_id = find_or_create_player(name)
      @connection.execute(
        <<~SQL,
          INSERT INTO matches (player_id, map_type, result, score, duration_seconds)
          VALUES (?, ?, ?, ?, ?)
        SQL
        [player_id, normalized_map_type, normalized_result, score, duration_seconds]
      )
      match_id = @connection.last_insert_row_id
    end

    match_id
  end

  # Consulta o ranking de um mapa. Pontuacoes maiores aparecem primeiro e,
  # em caso de empate, vence a partida de menor duracao.
  #
  # Data e id são critérios adicionais somente para tornar determinística a
  # ordem quando pontuação e duração também forem idênticas.
  #
  # @param map_type [String, Symbol]
  # @param limit [Integer] quantidade entre 1 e MAX_RANKING_LIMIT
  # @return [Array<Hash>] entradas prontas para o controller/view
  def top_scores(map_type, limit: DEFAULT_RANKING_LIMIT)
    ensure_open!
    normalized_map_type = normalize_option(:map_type, map_type, MAP_TYPES)
    validate_limit!(limit)

    rows = @connection.execute(
      <<~SQL,
        SELECT
          matches.id,
          matches.player_id,
          players.name,
          matches.map_type,
          matches.result,
          matches.score,
          matches.duration_seconds,
          matches.played_at
        FROM matches
        INNER JOIN players ON players.id = matches.player_id
        WHERE matches.map_type = ?
        ORDER BY
          matches.score DESC,
          matches.duration_seconds ASC,
          matches.played_at ASC,
          matches.id ASC
        LIMIT ?
      SQL
      [normalized_map_type, limit]
    )

    rows.map { |row| ranking_entry(row) }
  end

  # Libera a conexão.
  #
  # @return [nil]
  def close
    return if @connection.nil?

    @connection.close
    @connection = nil
  end

  # @return [Boolean] true quando não existe mais conexão utilizável
  def closed?
    @connection.nil?
  end

  private

  # Impede que nil, vazio ou somente espaços sejam usados como caminho.
  def normalize_path(path)
    normalized_path = path.to_s.strip
    raise ArgumentError, "path nao pode ficar vazio" if normalized_path.empty?

    normalized_path
  end

  # Cria apenas o diretório pai; o arquivo é criado pelo próprio SQLite.
  def prepare_parent_directory!
    return if path == ":memory:"

    FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
  end

  # Executa o schema completo. CREATE IF NOT EXISTS permite reabrir o mesmo
  # banco sem apagar jogadores ou partidas já registrados.
  def initialize_schema!(schema_path)
    normalized_schema_path = schema_path.to_s
    raise ArgumentError, "schema_path nao pode ficar vazio" if normalized_schema_path.empty?
    raise ArgumentError, "Schema nao encontrado: #{normalized_schema_path}" unless File.file?(normalized_schema_path)

    @connection.execute_batch(File.read(normalized_schema_path, encoding: "UTF-8"))
  end

  # Reutiliza jogadores sem diferenciar maiúsculas de minúsculas.
  #
  # INSERT OR IGNORE atende tanto o primeiro cadastro quanto nomes existentes;
  # em seguida o SELECT recupera o id usado pela chave estrangeira da partida.
  def find_or_create_player(name)
    @connection.execute("INSERT OR IGNORE INTO players (name) VALUES (?)", [name])
    @connection.get_first_value(
      "SELECT id FROM players WHERE name = ? COLLATE NOCASE",
      [name]
    )
  end

  # Mantém a mesma normalização aplicada por Player na fronteira do banco.
  def normalize_player_name(player_name)
    name = player_name.to_s.strip
    raise ArgumentError, "player_name nao pode ficar vazio" if name.empty?

    name
  end

  # Aceita símbolos ou strings, mas armazena a representação textual validada.
  def normalize_option(name, value, allowed_values)
    normalized_value = value.to_s
    return normalized_value if allowed_values.include?(normalized_value)

    raise ArgumentError, "#{name} invalido: #{value.inspect}"
  end

  # Espelha no serviço as constraints numéricas existentes no schema.
  def validate_non_negative_integer!(name, value)
    return if value.is_a?(Integer) && value >= 0

    raise ArgumentError, "#{name} deve ser um numero inteiro nao negativo"
  end

  # Evita consultas sem resultado ou cargas excessivas acidentais.
  def validate_limit!(limit)
    return if limit.is_a?(Integer) && limit.between?(1, MAX_RANKING_LIMIT)

    raise ArgumentError, "limit deve estar entre 1 e #{MAX_RANKING_LIMIT}"
  end

  # Converte as chaves textuais do sqlite3 em um contrato simbólico estável
  # para controllers e views, sem expor o objeto de conexão.
  def ranking_entry(row)
    {
      id: row["id"],
      player_id: row["player_id"],
      name: row["name"],
      map_type: row["map_type"],
      result: row["result"],
      score: row["score"],
      duration_seconds: row["duration_seconds"],
      played_at: row["played_at"]
    }
  end

  # Falha de forma explícita em vez de operar silenciosamente após #close.
  def ensure_open!
    raise IOError, "Banco de dados fechado" if closed?
  end
end
