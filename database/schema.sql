PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS players (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  CHECK (length(trim(name)) > 0)
);

CREATE TABLE IF NOT EXISTS matches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  player_id INTEGER NOT NULL,
  map_type TEXT NOT NULL,
  result TEXT NOT NULL,
  score INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  played_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
  CHECK (map_type IN ('poca', 'lago', 'oceano')),
  CHECK (result IN ('vitoria', 'derrota')),
  CHECK (score >= 0),
  CHECK (duration_seconds >= 0)
);

CREATE INDEX IF NOT EXISTS index_matches_on_ranking
  ON matches (map_type, score DESC, duration_seconds ASC, played_at ASC);
