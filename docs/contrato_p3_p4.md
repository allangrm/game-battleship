# Contrato de integração — Pessoas 3 e 4

Este contrato permite que a interface de partida e de pós-partida evolua sem
devolver responsabilidades de domínio para a `MainWindow`.

## Entrada na GameView

`SetupController` entrega a rota `:game` com:

- `game_controller`: instância pronta de `GameController`;
- `map_type`: `:poca`, `:lago` ou `:oceano`;
- `map_name`: nome exibido no título da janela.

`GameView` recebe também o callback opcional `on_game_over`. Quando qualquer
evento devolvido pelo `GameController` encerrar a partida, a view chama esse
callback uma única vez com o objeto `Game` terminado.

```ruby
GameView.new(
  window,
  game_controller,
  map_type: map_type,
  on_game_over: post_game_controller.method(:handle_game_over)
)
```

## Saída da GameView

`PostGameController` aplica a decisão já acordada:

- vitória humana: abre `NameView` e solicita o nome do vencedor;
- vitória do computador: abre diretamente `GameOverView`, sem criar `Player`.

Após o nome válido, a rota `:game_over` recebe:

- `game`: partida terminada, com `final_statistics`, `result`, `map_type` e
  `duration_seconds` disponíveis;
- `player`: instância validada de `Player` na vitória, ou `nil` na derrota.

O construtor estável para a tela da Pessoa 4 é:

```ruby
GameOverView.new(window, game: game, player: player)
```

Depois de exibir o nome do vencedor e a duração, o botão Voltar e a tecla
`Esc` retornam à seleção de fases/mapas (`:map_menu`).

## Responsabilidades da Pessoa 4

A Pessoa 4 pode completar `GameOverView` sem alterar o fluxo anterior:

1. calcular `ScoreCalculator.calculate(**game.final_statistics)`;
2. persistir a vitória usando `Database#save_match` e `player.name`;
3. exibir resultado, pontuação e duração;
4. navegar para `:ranking`, preferencialmente passando `map_type: game.map_type`.

`RankingView` já aceita `map_type:` opcional no construtor. A Pessoa 4 continua
responsável por consultar o banco, filtrar o mapa e desenhar a listagem. A
Pessoa 3 mantém o fundo, o botão de retorno, a rota e o brilho do botão do menu.

## Limites do contrato

- `GameView` não cria jogador, não calcula pontuação e não acessa o banco.
- `MainWindow` não cria tabuleiro, frota, estratégia, `Game` ou
  `GameController`.
- `SetupView` não posiciona navios diretamente: usa `SetupController`.
- O nome não é solicitado antes da partida.
