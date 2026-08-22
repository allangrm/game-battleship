# Contrato de Integração — Pessoa 1

Este documento descreve a API oferecida pela frente de models, configuração de
mapas, posicionamento, pontuação e persistência. As demais frentes podem
consultar esses objetos e acionar suas operações públicas, mas não devem alterar
diretamente `Board#grid`, `Cell#status`, `Cell#ship`, `Ship#cells` ou
`Ship#hits`.

`Board` é a fonte de verdade para posicionamento e ataques. `MapConfig` é a
fonte de verdade para dimensões e frotas, enquanto `Database` concentra a
inicialização do SQLite, a gravação das partidas e a consulta do ranking.

## Criação de mapa, tabuleiro e frota

O setup seleciona um mapa e solicita objetos novos à configuração:

```ruby
map_config = MapConfig.new(:poca)

player_board = map_config.create_board
player_fleet = map_config.create_fleet

enemy_board = map_config.create_board
enemy_fleet = map_config.create_fleet
```

Mapas aceitos:

| Identificador | Nome | Tabuleiro | Tamanhos da frota |
| --- | --- | ---: | --- |
| `:poca` | Poça | 5x5 | 2, 3 e 4 |
| `:lago` | Lago | 8x8 | 2, 3, 3, 4 e 5 |
| `:oceano` | Oceano | 10x10 | 2, 2, 3, 3, 4, 4 e 5 |

Consultas disponíveis:

```ruby
MapConfig.available_maps          # => [:poca, :lago, :oceano]
map_config.map_type               # => :poca
map_config.name                   # => "Poça"
map_config.board_size             # => 5
map_config.expected_fleet_sizes   # => [2, 3, 4]
```

Cada chamada de `create_board` ou `create_fleet` produz objetos independentes.
O tabuleiro e a frota do jogador nunca devem compartilhar células ou navios com
os objetos do computador.

## Coordenadas e posicionamento manual

As coordenadas usam índices iniciados em zero. Em um tabuleiro 5x5, por
exemplo, os valores válidos vão de `0` a `4` em cada eixo.

```ruby
ship = player_fleet.first
coordinates = player_board.generate_coordinates(
  row,
  col,
  ship.size,
  :horizontal
)

player_board.place_ship(ship, coordinates)
```

Orientações aceitas:

- `:horizontal`: mantém a linha e avança pelas colunas;
- `:vertical`: mantém a coluna e avança pelas linhas.

`generate_coordinates` retorna as coordenadas consecutivas ou `nil` quando a
orientação é desconhecida ou alguma posição ultrapassa os limites. A colocação
definitiva é feita por `place_ship`, que valida novamente todas as regras antes
de alterar o estado.

Uma posição é válida somente quando:

- a quantidade de coordenadas corresponde ao tamanho do navio;
- todas as coordenadas pertencem ao tabuleiro;
- todas as células estão livres;
- as células formam uma única linha ou coluna;
- não existem lacunas nem coordenadas duplicadas.

Não há um estado separado chamado `blocked` em `Cell`. Durante o setup, uma
célula é considerada bloqueada para outro navio quando `Cell#occupied?` é
verdadeiro. `Board#valid_placement?` detecta essa ocupação e `Board#place_ship`
rejeita a operação antes de modificar qualquer célula.

`place_ship` devolve o próprio `Ship` em caso de sucesso e levanta
`ArgumentError` se o navio já estiver posicionado ou se a posição for inválida.

## Posicionamento automático e reinício

```ruby
player_board.auto_place_ships(player_fleet)
```

O posicionamento automático escolhe orientação e origem aleatórias, sempre
passando pelas mesmas validações do posicionamento manual. Para testes ou
simulações reproduzíveis, o gerador e o limite de tentativas podem ser
injetados:

```ruby
player_board.auto_place_ships(
  player_fleet,
  random: Random.new(123),
  max_attempts_per_ship: 1_000
)
```

Se um navio não puder ser posicionado, `Board::AutoPlacementError` é levantado
e os navios adicionados por aquela chamada são removidos. Posicionamentos que
já existiam antes da chamada não participam desse rollback.

Não existe `Board#clear_ships`. Para recomeçar, trocar de mapa ou substituir um
setup manual parcial pelo automático, o contrato recomendado é recriar o
tabuleiro e a frota:

```ruby
player_board = map_config.create_board
player_fleet = map_config.create_fleet
player_board.auto_place_ships(player_fleet)
```

Esse comportamento já é encapsulado por `SetupController#reset_placement` e
`SetupController#auto_place`.

## Remoção e reposicionamento

Durante o setup, um navio pode ser removido ou movido:

```ruby
player_board.remove_ship(ship)
player_board.reposition_ship(ship, new_coordinates)
```

`remove_ship` libera as células e remove o navio de `Board#ships`. A operação é
rejeitada se o navio não pertence ao tabuleiro ou se qualquer ataque já
aconteceu.

`reposition_ship` remove e coloca novamente o mesmo objeto sem duplicá-lo na
lista. Se a nova posição for inválida, a posição anterior é restaurada antes de
o erro ser propagado.

## Ataques e estados das células

Controllers e armas escolhem alvos, mas somente `Board#receive_attack` deve
aplicar um ataque a uma célula:

```ruby
status = board.receive_attack(row, col)
```

Retornos possíveis:

| Retorno | Efeito |
| --- | --- |
| `:invalid` | Coordenada fora do tabuleiro; nenhum estado é alterado. |
| `:already_attacked` | Célula já resolvida; dano não é repetido. |
| `:miss` | A célula não possui navio e passa para o estado `:miss`. |
| `:hit` | O segmento e o contador de acertos do navio são atualizados. |
| `:sunk` | O último segmento foi atingido e todas as células do navio passam para `:sunk`. |

Estados observáveis de uma `Cell`:

- `:unknown`: ainda não atacada;
- `:miss`: ataque na água;
- `:hit`: segmento atingido de um navio ainda ativo;
- `:sunk`: segmento de um navio totalmente afundado.

Consultas úteis para as outras camadas:

```ruby
board.valid_coordinate?(row, col)
board.cell_at(row, col)       # Cell ou nil
board.all_ships_sunk?         # false para uma frota vazia
board.ships_remaining         # quantidade de navios não afundados

cell.occupied?
cell.attacked?

ship.placed?
ship.sunk?
ship.remaining_cells
```

Embora `Cell` exponha escritores para uso interno do domínio, views,
controllers e armas não devem atribuir diretamente `cell.status` ou
`cell.ship`. Isso evitaria as validações de repetição, dano e afundamento
mantidas por `Board`.

## Validação do setup para a partida

Antes de criar `Game`, os tabuleiros podem ser verificados contra o mapa:

```ruby
map_config.valid_board?(player_board)     # => true ou false
map_config.validate_board!(player_board)  # => true ou ArgumentError
```

Um tabuleiro compatível precisa:

- ser uma instância de `Board`;
- possuir a dimensão configurada para o mapa;
- conter a assinatura completa de tamanhos da frota;
- ter todos os navios efetivamente posicionados.

A ordem dos navios não interfere na validação. `Game` utiliza esse contrato
para impedir, por exemplo, uma partida declarada como Oceano com tabuleiro ou
frota de Poça.

## Jogador

`Player` representa somente a identidade e a pontuação do jogador humano:

```ruby
player = Player.new("  Allan  ")
player.name       # => "Allan"
player.score      # => 0
player.score = 2_500
```

O nome é convertido para texto, tem os espaços externos removidos e não pode
ficar vazio. `Player` não possui `board`: durante a partida, a única referência
ao tabuleiro aliado é `Game#player_board`.

## Cálculo da pontuação

O pós-jogo entrega diretamente as estatísticas finais de `Game`:

```ruby
statistics = game.final_statistics
score = ScoreCalculator.calculate(**statistics)
player.score = score
```

O hash deve conter quatro inteiros não negativos:

| Campo | Significado |
| --- | --- |
| `hits` | Segmentos atingidos na frota inimiga. |
| `surviving_ships` | Navios aliados que não foram afundados. |
| `remaining_ship_cells` | Soma dos segmentos aliados ainda intactos. |
| `duration_seconds` | Segundos completos decorridos na partida. |

Fórmula vigente:

```text
(hits × 100)
+ (surviving_ships × 500)
+ (remaining_ship_cells × 50)
- duration_seconds
```

O resultado nunca é menor que zero. `ScoreCalculator` é um serviço puro: não
consulta `Game`, não altera `Player` e não acessa o banco. Dados negativos,
fracionários ou de outro tipo produzem `ArgumentError`.

## Inicialização e ciclo de vida do banco

Não é necessário um botão para iniciar o banco. A criação de `Database`
estabelece a conexão, cria o diretório quando necessário e aplica
automaticamente o schema idempotente de `database/schema.sql`.

```ruby
database = Database.new

begin
  # gravação ou consulta
ensure
  database.close
end
```

O caminho padrão é `database/battleship.sqlite3`. Testes devem usar
`Database.new(path: ":memory:")` ou um arquivo temporário para não alterar os
dados reais.

O schema possui:

- `players`: identidade única por nome, sem diferenciar maiúsculas de
  minúsculas;
- `matches`: mapa, resultado, pontuação, duração e data de cada partida;
- chave estrangeira de `matches.player_id` para `players.id`;
- índice que atende à ordenação do ranking.

## Gravação de partida

```ruby
match_id = database.save_match(
  player_name: player.name,
  map_type: game.map_type,
  result: game.result,
  score: score,
  duration_seconds: game.duration_seconds
)
```

Valores aceitos:

- `map_type`: `:poca`, `:lago`, `:oceano` ou strings equivalentes;
- `result`: `:vitoria`, `:derrota` ou strings equivalentes;
- `score` e `duration_seconds`: inteiros não negativos;
- `player_name`: texto não vazio depois da normalização.

Jogadores com o mesmo nome, desconsiderando maiúsculas e minúsculas, reutilizam
o mesmo registro em `players`. Cada chamada cria uma nova linha em `matches` e
devolve seu identificador. Jogador e partida são persistidos na mesma transação.

O serviço aceita vitórias e derrotas. O fluxo visual vigente escolhe salvar
somente vitórias, pois o nome é solicitado apenas quando o jogador vence; essa
é uma decisão do pós-jogo, não uma limitação do banco.

## Consulta do ranking

```ruby
entries = database.top_scores(:poca)
entries = database.top_scores(:oceano, limit: 5)
```

A consulta é segmentada por mapa e usa limite padrão de 10, aceitando valores
entre 1 e 100. A ordem é:

1. maior pontuação;
2. menor duração em caso de empate;
3. partida mais antiga;
4. menor identificador.

Cada entrada é um hash com estas chaves:

```ruby
{
  id: 1,
  player_id: 1,
  name: "Allan",
  map_type: "poca",
  result: "vitoria",
  score: 2_500,
  duration_seconds: 75,
  played_at: "2026-08-21 12:00:00"
}
```

Não existe tabela ou model `Ranking`: a listagem é derivada de `matches` por
uma consulta ordenada. Caso derrotas sejam persistidas por outro fluxo, elas
também aparecerão, pois `top_scores` não filtra por resultado.

## Responsabilidades nas integrações

### Setup e navegação — P3

- criar mapa, tabuleiro e frota por `MapConfig`;
- usar as operações públicas de `Board` por meio de `SetupController`;
- recriar tabuleiro e frota ao limpar ou substituir o posicionamento;
- não alterar células ou a lista de navios diretamente.

### Partida, regras e IA — P2

- usar `Board#receive_attack` como operação final para cada célula-alvo;
- consultar estados públicos sem descobrir posições ocultas da frota;
- fornecer `Game#final_statistics`, `Game#result`, `Game#map_type` e
  `Game#duration_seconds` ao pós-jogo;
- não duplicar dano, repetição, hit, miss ou sunk fora de `Board`.

### Pós-partida e ranking — P4

- calcular a pontuação com `ScoreCalculator.calculate(**game.final_statistics)`;
- atribuir o resultado a `Player#score` quando existir jogador;
- gravar cada partida no máximo uma vez;
- consultar o ranking com `Database#top_scores`;
- fechar toda instância de `Database`, inclusive quando ocorrer erro.

## Erros que os consumidores devem tratar

- `ArgumentError`: mapa, nome, frota, posição, pontuação ou dado de persistência
  inválido;
- `Board::AutoPlacementError`: frota não pôde ser posicionada automaticamente
  dentro do limite;
- `IOError`: tentativa de consultar ou gravar depois que o banco foi fechado;
- `SQLite3::Exception` e erros de arquivo: falha ao abrir, inicializar ou operar
  a persistência.

Operações de consulta booleana, como `valid_coordinate?`, `valid_placement?` e
`valid_board?`, devem ser preferidas quando a interface só precisa apresentar
uma pré-validação. As operações com `!` ou que efetivamente alteram estado
podem levantar exceções e devem ser tratadas na fronteira do controller.

## Cobertura automatizada

Os principais pontos deste contrato são exercitados por:

- `test/board_test.rb`: matriz, posicionamento, bloqueio por ocupação, ataques,
  remoção, reposicionamento e rollback automático;
- `test/model_support_test.rb`: mapas, frotas, validação de setup e jogador;
- `test/score_calculator_test.rb`: fórmula, fatores, duração e piso zero;
- `test/database_test.rb`: schema, persistência, validações, ranking e desempate;
- `test/game_services_integration_test.rb`: fluxo completo entre mapas, modos de
  turno, pontuação e banco.
