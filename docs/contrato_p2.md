# Contrato de Integração — Pessoa 2

Este documento descreve a API oferecida pela lógica de partida para as frentes de setup, interface e pós-partida. `Board` continua sendo a fonte de verdade das células e dos navios; a interface não deve alterar esses objetos diretamente.

## Criação da partida

O setup deve fornecer dois tabuleiros diferentes e compatíveis com o
`MapConfig` selecionado. O `Game` valida o tamanho, exige todos os navios
posicionados e compara a composição completa da frota pelos tamanhos. Assim,
uma partida `:oceano`, por exemplo, não aceita um tabuleiro ou uma frota de
`:poca`.

```ruby
turn_strategy = TurnStrategyFactory.build(:extra_shot_on_hit)

game = Game.new(
  player_board: player_board,
  enemy_board: enemy_board,
  map_type: map_config.map_type,
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

## Inventários e limites

Jogador e computador recebem inventários separados com as mesmas cargas. O ataque básico é ilimitado.

| Mapa | Míssil | Avião |
| --- | ---: | ---: |
| Poça | 1 | 1 |
| Lago | 2 | 1 |
| Oceano | 3 | 1 |

Uma carga é consumida somente depois que o ataque passa pelas validações. Coordenada inválida ou origem repetida não consome a arma.

```ruby
game.player_inventory.remaining(:missile)
game.computer_inventory.available?(:airplane)
game.player_inventory.to_h
```

## Dificuldade da IA

Quando nenhuma IA é injetada explicitamente, `Game` seleciona a estratégia padrão conforme o mapa:

| Mapa | Dificuldade | Estratégia | Busca básica | Política de armas especiais |
| --- | --- | --- | --- | --- |
| Poça | Fácil | `RandomAI` | Escolhe aleatoriamente entre células ainda não atacadas | Usa somente `BasicShot`, preservando o nível introdutório |
| Lago | Média | `HuntTargetAI` | Prioriza células ortogonais próximas de um acerto ativo | Usa Míssil ao redor de um acerto visível e Avião quando existem ao menos dois acertos alinhados |
| Oceano | Difícil | `StrategicAI` | Prolonga acertos alinhados e procura novos alvos em padrão quadriculado | Além das regras da IA média, usa o Avião e o Míssil proativamente nas áreas com mais células ainda não atacadas |

### Prioridade de decisão das armas

A escolha retorna arma, origem e opções dentro da mesma `Decision` já consumida
por `Game#computer_attack`. A IA não remove cargas diretamente.

- **Fácil:** tiro básico em uma célula aleatória disponível.
- **Média:** Avião sobre dois ou mais acertos visíveis alinhados; na ausência
  dessa condição, Míssil em um bloco que inclua um acerto visível; caso não
  exista carga ou alvo válido, aplica a perseguição com tiro básico.
- **Difícil:** Avião sobre acertos alinhados; Míssil perto de qualquer acerto
  visível; Avião sobre a linha ou coluna de um acerto isolado; sem acertos,
  usa primeiro o Avião na linha/coluna com maior cobertura disponível e depois
  o Míssil no bloco 2x2 com mais células não atacadas; por fim, volta à busca
  estratégica com tiro básico.

As cargas são oportunidades, não ataques obrigatórios. Uma arma sem carga ou
sem origem válida é ignorada, permitindo o fallback seguinte. A origem sempre
é uma célula ainda não atacada, mas células já atingidas dentro da área são
ignoradas pelo `AttackHandler` conforme o contrato geral.

Todas as estratégias consultam somente estados visíveis (`:hit`, `:miss`,
`:sunk` e não atacado). Elas não acessam `cell.ship` nem `cell.occupied?` para
descobrir posições ocultas e nunca repetem a origem de um ataque.

Uma IA personalizada ainda pode ser fornecida com `ai:` ao criar `Game`, desde que implemente `choose_attack(board, inventory:)`.
`game.ai` expõe a estratégia selecionada de forma somente leitura.

## Evento de ataque

Cada `Game::AttackEvent` expõe:

| Campo | Conteúdo |
| --- | --- |
| `actor` | `:player` ou `:computer` |
| `weapon` | `:basic_shot`, `:missile` ou `:airplane` |
| `remaining_uses` | Cargas restantes após a ação; `nil` para ataque básico |
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
  map_type: game.map_type,
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
- `WeaponInventory::WeaponUnavailableError`: tentativa de usar uma arma sem cargas;
- `ArgumentError`: arma/orientação/modo de turno inválido ou setup inconsistente.
