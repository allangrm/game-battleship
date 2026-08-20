# Divisão Atualizada do Projeto

Este documento consolida a divisão revisada entre quatro pessoas e atribui os itens compartilhados que estavam implícitos ou sem responsável. A referência de escopo é `Requisitos_do_Projeto.md`.

Prazo informado: **21 de agosto de 2026**.

## P1 - Models, Pontuação, Banco de Dados e Bootstrap

Responsável principal: **Allan**.

### Escopo funcional

- **RF02:** implementar `MapConfig` e as configurações de Poça, Lago e Oceano.
- **RF03:** implementar `Board` e a matriz bidimensional de `Cell`.
- **RF04:** implementar `Cell`, `Ship`, posicionamento manual e posicionamento automático.
- **RF10:** implementar e documentar o cálculo de pontuação usando acertos, navios sobreviventes, integridade e tempo.
- **RF11:** implementar o modelo do jogador e a persistência do nome associado à partida.
- **RF12/RNF01:** criar o schema SQLite, gravar partidas e consultar o ranking por mapa.
- Incluir `duration_seconds` na partida e ordenar empates por menor duração.

### Escopo técnico compartilhado atribuído a P1

- Criar e manter o `Gemfile` e o carregamento básico das dependências.
- Definir a estrutura MVC, os contratos entre camadas e as convenções de nomes.
- Garantir que arquivos e métodos usem `snake_case`, enquanto classes e módulos usem `CamelCase`, conforme a convenção Ruby.
- Manter o schema e a inicialização do banco.
- Fornecer contratos estáveis de `Board`, `Ship`, `Player`, `ScoreCalculator` e `Database` para as demais frentes.
- Criar testes unitários dos models, pontuação e persistência.

### Entregáveis

- `app/models/`
- Serviço ou utilitário de pontuação.
- Camada simples de acesso SQLite com SQL puro.
- `database/schema.sql`.
- `Gemfile` e instruções técnicas necessárias ao bootstrap.
- Testes da frente P1.

## P2 - Game, Regras, Turnos, IA e Armas

### Escopo funcional

- **RF06:** implementar o ataque básico integrado ao ciclo da partida.
- **RF07:** validar limite e repetição das jogadas.
- **RF09:** implementar vitória e derrota.
- Implementar o oponente/IA sem repetir coordenadas, com dificuldades fácil, média e difícil selecionadas conforme o mapa.
- Implementar os dois modos de turno:
  - um tiro por vez;
  - tiro adicional em caso de acerto.
- Implementar Míssil 2x2 e Avião em linha/coluna por um contrato polimórfico comum.

### Escopo técnico compartilhado atribuído a P2

- Ser dono da classe `Game`, incluindo dois tabuleiros, turno atual, estado e encerramento.
- Ser dono de `GameController` e `AttackHandler` como camada de orquestração de regras.
- Manter `Board` como fonte de verdade para alterações de `Cell` e `Ship`; controllers não devem duplicar dano, hit, miss ou sunk.
- Definir o resultado de ataque consumido pela interface.
- Definir o comportamento de armas de área com células já atacadas e do modo sequencial quando uma arma produz resultados mistos.
- Criar testes unitários e de integração da lógica de jogo.

### Entregáveis

- `app/game.rb`
- `app/controllers/game_controller.rb`
- `app/controllers/attack_handler.rb`
- `app/weapons/`
- Estratégias de turno.
- IA do computador.
- Testes da frente P2.

### Dependências

- Consome os contratos dos models de P1.
- Expõe eventos/resultados estáveis para P3 e P4.

## P3 - Interface Pré-Partida e Navegação

### Escopo funcional

- **RF01:** criar Menu com Iniciar, Ranking, Instruções e Sair.
- Criar a tela de instruções (`InstructionsView`), que estava sem responsável explícito.
- **RF02:** criar a seleção de Poça, Lago e Oceano.
- **RF04/RF05:** criar o posicionamento manual por clique e o botão de posicionamento automático.
- **RF11:** criar a entrada e validação visual do nome do jogador.
- Criar a seleção/configuração do modo de turno.

### Escopo técnico compartilhado atribuído a P3

- Ser dono de `MainWindow`, `main.rb`, `MenuController` e do roteamento de telas.
- Coordenar o contrato de transição entre setup e partida com P2/P4.
- Converter cliques de tela em coordenadas de tabuleiro sem alterar models diretamente.
- Criar testes possíveis da navegação e checklist manual da frente.

### Entregáveis

- `main.rb`
- `app/views/main_window.rb`
- `app/views/menu_view.rb`
- `app/views/name_view.rb`
- `app/views/setup_view.rb`
- `app/views/instructions_view.rb`
- `app/controllers/menu_controller.rb`
- Testes/checklist da frente P3.

### Dependências

- Consome `MapConfig`, `Board`, `Player` e contratos de `Game`.
- Entrega a view ativa de partida para P4 por meio do roteamento comum.

## P4 - Interface de Partida, Pós-Partida e Integração Final

### Escopo funcional

- **RF03:** renderizar tabuleiro aliado e inimigo e atualizar após cada jogada.
- **RF05:** capturar cliques de ataque.
- **RF06/RF07:** exibir feedback de água, acerto, navio afundado, coordenada inválida e repetição.
- Criar controles de seleção de arma e orientação do Avião.
- **RF09/RF10:** criar a tela final com vitória/derrota, pontuação e duração.
- **RF12:** criar o ranking filtrado por mapa e apresentar o desempate por menor duração.

### Escopo técnico compartilhado atribuído a P4

- Integrar `GameView` com `GameController` sem alterar models diretamente.
- Integrar a tela final ao `ScoreCalculator` e à gravação via `Database`.
- Ser responsável pelo teste manual ponta a ponta e pela consolidação dos defeitos de integração.
- Consolidar o `README.md` com instalação, execução, controles e arquitetura; cada integrante fornece sua seção.
- Consolidar o roteiro de demonstração e coordenar o ensaio final com o grupo.

### Entregáveis

- `app/views/game_view.rb`
- `app/views/game_over_view.rb`
- `app/views/ranking_view.rb`
- Feedback visual da partida.
- Checklist e evidências dos testes ponta a ponta.
- `README.md` consolidado e roteiro da apresentação.

### Dependências

- Consome resultados de P2 e dados de pontuação/ranking de P1.
- Usa o `MainWindow` e o roteamento mantidos por P3.

## Contratos de Integração

### Ataque

1. P4 captura o clique e escolhe arma/orientação.
2. P4 chama `GameController`, pertencente a P2.
3. O controller usa a arma para calcular as coordenadas-alvo.
4. Para cada coordenada, o controller delega a alteração de estado a `Board`, pertencente a P1.
5. P2 devolve resultados estáveis para P4 renderizar.

### Encerramento, pontuação e banco

1. P2 detecta vitória ou derrota e fornece as estatísticas finais.
2. P1 calcula a pontuação e persiste jogador, partida e duração.
3. P4 apresenta o resultado e o ranking.

### Setup

1. P3 coleta mapa, modo de turno e posicionamento antes da partida; o nome é solicitado somente após uma vitória humana.
2. P1 fornece mapa, frota e operações de `Board`.
3. P2 cria o `Game` com os dois tabuleiros.
4. P3 transfere a navegação para a `GameView` de P4.

## Responsabilidades de Todos

- Testar e documentar a própria frente.
- Não alterar contratos compartilhados sem avisar os consumidores.
- Manter commits pequenos e temáticos.
- Executar a suite completa antes de integrar.
- Participar da revisão e da apresentação.

## Substituição em Caso de Ausência

Se uma pessoa não entregar, P1 pode assumir a frente nesta ordem:

1. Concluir P1 e estabilizar models/banco.
2. Assumir P2 para obter uma partida completa sem interface.
3. Criar com P3 uma fatia mínima Menu -> Setup automático -> Jogo.
4. Assumir P4 para completar telas, ranking, integração e documentação.

## Itens Opcionais

Implementar somente depois do escopo obrigatório:

- sons de água/acerto;
- tremor de tela;
- histórico lateral de jogadas;
- assets e animações adicionais.
