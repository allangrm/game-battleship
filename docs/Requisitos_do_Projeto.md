# Requisitos do Projeto - Etapa 2

> Conversão textual de `Requisitos_do_Projeto_-_Etapa_2.docx` para facilitar consulta, versionamento e atualização. O DOCX original permanece como fonte normativa recebida. A conversão preserva os requisitos, observações e sugestões; apenas normaliza a hierarquia Markdown e a pontuação.

## Requisitos Funcionais Obrigatórios (RF)

### Menu

- **RF01 - Menu Inicial:** O sistema deve apresentar uma interface gráfica interativa com as opções: Iniciar Jogo, Ranking, Instruções e Sair.

### Preparação do Jogo e Tabuleiro

- **RF02 - Seleção de Mapa/Modo:** O sistema deve permitir que o usuário selecione o tamanho do tabuleiro antes de iniciar a partida.

> **Observação:** Os valores são sugestões. O aluno deve utilizar valores que façam sentido e equilíbrio na mecânica do seu jogo.
>
> Caso tenha alguma outra ideia, consultar. Rio? Praia?

Exemplos:

- Poça 5x5: 3 embarcações - 1 grande, 1 média e 1 pequena.
- Lago 8x8: 5 embarcações - 1 grande, 2 médias e 2 pequenas.
- Oceano 10x10: 7 embarcações - 2 grandes, 2 médias e 3 pequenas.
  - Embarcação grande: 5 casas.
  - Embarcação média: 3 ou 4 casas.
  - Embarcação pequena: 2 casas.

- **RF03 - Inicialização do Tabuleiro:** O sistema deve gerar uma matriz bidimensional para representar o tabuleiro de forma visual e atualizá-lo após cada jogada.

- **RF04 - Posicionamento de Embarcações:** O sistema deve permitir que o jogador posicione manualmente suas embarcações no tabuleiro aliado antes do início da partida.
  - **Posicionamento Aleatório (Opcional):** Adicionar um botão "Posicionar Automaticamente" para o jogador que não quiser colocar navio por navio manualmente.

### Jogabilidade e Regras

- **RF05 - Interação por Clique:** O sistema deve capturar as ações do jogador (tiros e posicionamento) por meio de cliques na interface gráfica.

- **RF06 - Ataques:** O jogador deve ser capaz de atacar uma das coordenadas selecionadas, sendo esse o ataque básico do jogo.

- **RF07 - Validação de Jogadas:** O sistema deve impedir que o jogador selecione coordenadas fora dos limites da matriz ou repita uma coordenada já atingida.

- **RF09 - Verificação de Fim de Jogo:** O sistema deve encerrar a partida e declarar vitória se todos os navios inimigos forem destruídos, ou derrota se todos os navios aliados forem afundados.

### Pontuação e Banco de Dados

- **RF10 - Cálculo de Pontuação:** O sistema deve calcular os pontos do jogador ao final da partida considerando acertos, navios sobreviventes, integridade das embarcações e o tempo total decorrido.
  - A mecânica e a quantidade de pontos distribuídos ficam a critério do aluno.

- **RF11 - Cadastro de Jogador:** O sistema deve solicitar e armazenar o nome do jogador associado à sua pontuação para fins de identificação no ranking.

- **RF12 - Exibição de Ranking:** O sistema deve exibir um ranking ordenado de forma decrescente por pontuação, utilizando o tempo de partida mais baixo como critério de desempate, segmentado por tipo de mapa.

## Requisitos Funcionais Adicionais (mínimo 2)

- **RF02 - Uso de Armas Especiais (mínimo 2 adicionais):** O sistema deve permitir o disparo de armas com padrões diferenciados.
  - Míssil: atinge uma área de 2x2.
  - Avião: ataca uma linha ou coluna inteira livremente.

- **RF03 - Modos de Ataque (mínimo 2 adicionais):** O sistema deve suportar pelo menos duas dinâmicas de turno.
  - Um tiro por vez.
  - Tiros sequenciais em caso de acerto.

## Requisitos Não Funcionais (RNF)

- **RNF01 - Persistência de Dados:** O sistema deve utilizar um Banco de Dados Relacional (SQLite, MySQL ou PostgreSQL) para garantir a persistência das tabelas de ranking.

- **RNF02 - Arquitetura de Código:** O código-fonte deve ser modular, escalável, aplicando a separação de responsabilidades (exemplo: padrão MVC - Model-View-Controller).

- **RNF03 - Qualidade de Código (Opcional):** O projeto deve conter testes de unidade para validar as principais regras de negócio, como validação de tiros e cálculo de pontos.

- **RNF04 - Tecnologias de Controle:** O fluxo do jogo deve ser gerenciado por estruturas de controle nativas da linguagem, como `if`/`else`, `for` e `while`.

## Sugestões de Novos Requisitos

- **RNF - Feedback Visual e Sonoro:** O sistema deve emitir sons diferentes para "Água" (Splash) e "Acerto" (Explosão), além de tremer a tela ligeiramente quando um navio grande for afundado, caso seja utilizado Gosu.

- **RF - Histórico de Jogadas (Log):** Uma barra lateral que exibe o texto das últimas ações. Exemplos: "Turno 3: Jogador acertou o Cruzador em B4" e "Turno 4: Computador errou em F2".

## Considerações de Arquitetura

- **Polimorfismo:** Todas as armas (Míssil, Torpedo e Avião, relacionadas ao requisito adicional RF02) implementam um método comum, como `fire(coordenadas, tabuleiro)`, para que quem dispara não precise saber qual arma está sendo utilizada.

- **Strategy:** Os modos de turno (um tiro por vez e sequencial, relacionados ao requisito adicional RF03) tornam-se estratégias intercambiáveis.

- **Composição:** `Game` tem um `Board`; `Board` tem vários `Ship`; `Ship` tem várias `Cell`.

## Interface

### Gosu

Gosu é uma biblioteca de jogos 2D que já oferece clique de mouse, desenho e som. É o caminho mais direto para um tabuleiro clicável de Batalha Naval.
