# Contrato de Integração — Pessoa 2

Este documento descreve a API oferecida pela lógica de partida para as frentes de setup, interface e pós-partida. `Board` continua sendo a fonte de verdade das células e dos navios; a interface não deve alterar esses objetos diretamente.

## Criação da partida

O setup deve fornecer dois tabuleiros diferentes, do mesmo tamanho e com ao menos um navio posicionado em cada um.

```ruby
turn_strategy = TurnStrategyFactory.build(:extra_shot_on_hit)

game = Game.new(
  player_board: player_board,
  enemy_board: enemy_board,
  turn_strategy: turn_strategy
)

controller = GameController.new(game)
```

Modos aceitos pela factory:

- `:single_shot`: sempre alterna o turno depois de uma ação;
- `:extra_shot_on_hit`: mantém o turno se a ação produzir ao menos um `:hit` ou `:sunk`.

Uma arma de área concede no máximo uma continuação por ativação, mesmo que atinja vários navios.

## Ataque do jogador

```ruby
events = controller.handle_player_attack(row, col, weapon, **options)
```

O retorno é um array congelado de `Game::AttackEvent`. Ele contém primeiro o evento do jogador e, se o turno passar ao computador, todos os eventos da IA até o turno voltar ao jogador ou a partida terminar.

Armas e opções:

```ruby
controller.handle_player_attack(row, col) # BasicShot por padrão
controller.handle_player_attack(row, col, Missile.new)
controller.handle_player_attack(row, col, Airplane.new, orientation: :row)
controller.handle_player_attack(row, col, Airplane.new, orientation: :col)
```

No Míssil, a coordenada escolhida é o canto superior esquerdo do bloco 2x2. A origem já atacada invalida a ação. Outras células já atacadas dentro da área são ignoradas.

## Evento de ataque

Cada `Game::AttackEvent` expõe:

| Campo | Conteúdo |
| --- | --- |
| `actor` | `:player` ou `:computer` |
| `weapon` | `:basic_shot`, `:missile` ou `:airplane` |
| `cells` | Array congelado de resultados por coordenada |
| `turn_before` | Ator que iniciou a ação |
| `turn_after` | Ator que poderá realizar a próxima ação |
| `state` | `:playing`, `:victory` ou `:defeat` |
| `extra_turn` | Indica se a estratégia manteve o turno |
| `winner` | `nil`, `:player` ou `:computer` |

Cada item de `cells` possui `row`, `col`, `status` e `hit?`. Os estados possíveis são `:hit`, `:miss` e `:sunk`.

Métodos auxiliares do evento:

- `hit?`: houve ao menos um acerto;
- `game_over?`: a ação encerrou a partida.

## Turno inicial do computador

Caso `Game` seja criado com `first_turn: :computer`, a interface pode iniciar as ações automáticas com:

```ruby
events = controller.resolve_computer_turn
```

## Encerramento, pontuação e banco

```ruby
score = ScoreCalculator.calculate(**game.final_statistics)

database.save_match(
  player_name: player.name,
  map_type: map_config.map_type,
  result: game.result,
  score: score,
  duration_seconds: game.duration_seconds
)
```

`game.result` retorna `:vitoria`, `:derrota` ou `nil` enquanto a partida estiver em andamento.

## Erros que a interface deve tratar

- `InvalidAttackError`: coordenada inválida ou origem já atacada;
- `Game::InvalidTurnError`: ação solicitada para o ator errado;
- `Game::GameFinishedError`: tentativa de atacar depois do encerramento;
- `ArgumentError`: arma/orientação/modo de turno inválido ou setup inconsistente.
