# Taiko: Treinamento Rítmico

Programa para computador (Windows) que ajuda a treinar o senso de tempo no *Taiko* usando apenas o teclado. Círculos coloridos entram pela direita da tela e andam até uma marca branca. Quando um círculo chega nela, o praticante aperta a tecla certa, e o programa compara o instante de cada batida com a partitura. Ao final de cada sessão, mostra a precisão, o erro absoluto médio, a tendência de adiantar ou atrasar e as teclas erradas.

O programa foi desenvolvido para o Trabalho de Conclusão de Curso **"Projeto e avaliação de um artefato computacional de baixa latência para o diagnóstico rítmico no treinamento individual de Taiko"**, do curso de Bacharelado em Ciência da Computação da UNIOESTE, campus de Cascavel (2026).

- **Autor:** Fernando Seiji Onoda Inomata
- **Orientador:** Prof. Clodis Boscarioli
- **Coorientador:** Prof. Jefferson Rodrigo Speck

## Baixar e usar

Baixe o arquivo `Taiko_TreinamentoRítmico.zip`. Ele contém o executável e o manual de instrução, e é a versão usada na avaliação com participantes (27 de outubro a 1.º de novembro de 2026).

1. Extraia o `.zip` em uma pasta, por exemplo `Documentos\Taiko`.
2. Dê dois cliques em `Taiko_TreinamentoRítmico.exe`. Na primeira vez, o programa cria a pasta `Dados` ao lado dele.
3. No menu principal, escolha **Selecionar Música e Iniciar Treinamento**, aperte ESPAÇO para começar e toque junto com a música. O botão **Como Jogar** abre o mesmo guia dentro do programa.

O executável não é assinado digitalmente, por isso o Windows pode mostrar o aviso "O Windows protegeu o seu computador". Clique em **Mais informações** e depois em **Executar assim mesmo**. Alguns antivírus também acusam, por engano, programas feitos na *Godot Engine*. O manual explica como adicionar a pasta às exclusões.

**Requisitos:** Windows (testado no Windows 11), teclado físico e placa de vídeo compatível com Vulkan ou DirectX 12. Prefira fone com fio ou o alto-falante do computador, porque fones *Bluetooth* atrasam o som.

## Teclas

| Tecla | Mão | Batida | Círculo |
|---|---|---|---|
| J | direita | Don (centro) | vermelho |
| F | esquerda | Kon (centro) | vermelho |
| U | direita | Ka (borda) | azul, maior |
| R | esquerda | Ra (borda) | azul, maior |

Durante a partida, **P** reinicia a música, **ESPAÇO** ou **ENTER** encerra e mostra o resultado, e **Esc** volta ao menu na tela inicial e na de resultado.

## Como funciona

- **Relógio de áudio.** O tempo da aplicação vem do servidor de áudio da *Godot*, e não da taxa de quadros: `T_atual = T_mix - L_saída`, em que `T_mix` é a posição de reprodução somada ao tempo desde a última mixagem, e `L_saída` é a latência de saída informada pelo sistema. As notas na tela e as batidas usam esse mesmo relógio.
- **Classificação.** O desvio `e = t_cli - t_esp` é classificado em Perfeito (até 30 ms), Bom (até 70 ms), Ruim (até 120 ms) ou Miss. A tecla também precisa ser a da nota (mão e região do tambor).
- **Diagnóstico.** O erro absoluto médio (MAE) mede a imprecisão. A tendência é a média com sinal dos desvios, e valores abaixo de -20 ms indicam que a pessoa adianta, e acima de +20 ms, que atrasa.
- **Limitações conhecidas.** O instante da batida é lido uma vez por quadro, então fica entre zero e um quadro antes do instante real (cerca de 8 ms em média a 60 quadros por segundo). A latência de saída depende do valor informado pelo sistema operacional, e o programa foi testado apenas em Windows.

## O que há neste repositório

| Pasta ou arquivo | Conteúdo |
|---|---|
| `Taiko_TreinamentoRítmico.zip` | Executável (Windows) e manual de instrução |
| `Autoloads/` | Scripts globais: `audio_manager.gd` (relógio de áudio e volumes), `game_manager.gd` (estados da sessão, avaliação, músicas e relatórios) e `input_manager.gd` (captura das teclas e *benchmark* de latência) |
| `Scripts/` | Telas e componentes: `ui_manager.gd` (tela da partida), `nota.gd`, `relatorio.gd`, `menu_principal.gd`, `selecao_musica.gd`, `gravacao.gd`, `configuracoes.gd`, `como_jogar.gd` e `previa_notas.gd` |
| `Scenes/` | Cenas do projeto. `camera_input.tscn` é a cena da partida, com o nome histórico |

O repositório reúne o **código-fonte e as cenas** da versão avaliada. Ele não inclui as configurações do projeto (`project.godot`), as fontes nem as músicas de exemplo. Para abrir os scripts no *Godot* (versão 4.7), são necessárias estas configurações:

- Ações de entrada: `Direita` (J), `Esquerda` (F), `Direita_Borda` (U), `Esquerda_Borda` (R) e `Reiniciar` (P).
- *Autoloads*: `AudioManager` (`Scenes/audio_manager.tscn`), `GameManager` (`Scenes/game_manager.tscn`) e `InputManager` (`Autoloads/input_manager.gd`).
- Cena principal: `Scenes/menu_principal.tscn`.

## Dados gerados

O programa grava tudo na pasta `Dados`, ao lado do executável.

- `Dados/musicas/`: uma pasta por música, com o áudio (`.mp3` ou `.ogg`), a partitura (`partitura.txt`) e os metadados (`metadata.json`).
- `Dados/relatorios/`: dois arquivos por sessão, com o mesmo nome-base. O `.txt` é a versão legível. O `.csv` (UTF-8, separador `;`) tem uma linha por evento, com o instante esperado, o instante da batida, o desvio em milissegundos e a classificação.

A estrutura completa desses arquivos está descrita no Apêndice B da monografia.

## Sobre o projeto

Este é um projeto acadêmico. A monografia descreve a arquitetura, o algoritmo de análise, a verificação técnica da latência (cerca de 17 ms no *pipeline* de entrada) e a avaliação de usabilidade com 48 participantes.
