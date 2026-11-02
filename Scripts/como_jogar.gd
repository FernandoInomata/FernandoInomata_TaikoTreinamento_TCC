extends Control
## Tela "Como Jogar": manual do participante, aberto pelo botão do menu principal.

const COR_DON := "#ff5555"
const COR_KA := "#6a8dff"
const COR_PERFEITO := "gold"
const COR_BOM := "green"
const COR_RUIM := "#d04040"
const COR_MISS := "gray"

const PASSO_ROLAGEM := 60.0

@onready var rolagem: ScrollContainer = $Rolagem
@onready var texto: RichTextLabel = $Rolagem/Texto
@onready var botao_voltar: Button = $BotaoVoltar


func _ready() -> void:
	texto.text = _montar_manual()
	botao_voltar.pressed.connect(_voltar_ao_menu)
	InputManager.voltar_menu_solicitado.connect(_voltar_ao_menu)


## Setas e PageUp/PageDown rolam o texto sem precisar do mouse.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down", true):
		rolagem.scroll_vertical += int(PASSO_ROLAGEM)
	elif event.is_action_pressed("ui_up", true):
		rolagem.scroll_vertical -= int(PASSO_ROLAGEM)
	elif event.is_action_pressed("ui_page_down", true):
		rolagem.scroll_vertical += int(rolagem.size.y * 0.9)
	elif event.is_action_pressed("ui_page_up", true):
		rolagem.scroll_vertical -= int(rolagem.size.y * 0.9)


func _voltar_ao_menu() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")


func _titulo(t: String) -> String:
	return "\n[font_size=26][b]%s[/b][/font_size]" % t


func _cor(cor: String, t: String) -> String:
	return "[color=%s]%s[/color]" % [cor, t]


## Os limites de tempo vêm das constantes do GameManager, para o manual nunca divergir do jogo.
func _montar_manual() -> String:
	var linhas: Array[String] = []

	linhas.append(_titulo("Objetivo"))
	linhas.append("O objetivo deste projeto é simular um tambor Taiko usando o teclado, com foco principal na noção de tempo. Círculos vêm da direita da tela e você aperta a tecla certa no instante exato em que cada nota chega. No final, o programa mostra um diagnóstico do seu ritmo.")

	linhas.append(_titulo("1. Para começar"))
	linhas.append("- No menu principal, clique em [b]Selecionar Música e Iniciar Treinamento[/b] e escolha uma música.")
	linhas.append("- Aperte [b]ESPAÇO[/b] para começar. Uma contagem de 3 segundos avisa quando a música vai tocar, e os primeiros círculos já aparecem durante ela.")
	linhas.append("- Deixe os dedos indicadores sobre [b]F[/b] (mão esquerda) e [b]J[/b] (mão direita). As teclas [b]R[/b] e [b]U[/b] ficam logo acima delas.")

	linhas.append(_titulo("2. As teclas"))
	linhas.append("[b]J[/b]  mão direita - [b]Don[/b] (centro) - círculo %s com a letra [b]R[/b]" % _cor(COR_DON, "vermelho"))
	linhas.append("[b]F[/b]  mão esquerda - [b]Kon[/b] (centro) - círculo %s com a letra [b]L[/b]" % _cor(COR_DON, "vermelho"))
	linhas.append("[b]U[/b]  mão direita - [b]Ka[/b] (borda) - círculo %s, maior, com a letra [b]R[/b]" % _cor(COR_KA, "azul"))
	linhas.append("[b]R[/b]  mão esquerda - [b]Ra[/b] (borda) - círculo %s, maior, com a letra [b]L[/b]" % _cor(COR_KA, "azul"))
	linhas.append("Atenção: a letra dentro do círculo indica a [b]mão[/b] (L = esquerda, R = direita), não a tecla. Um círculo azul com \"L\", por exemplo, pede a tecla [b]R[/b], da mão esquerda.")
	linhas.append("Se preferir, em [b]Configurações[/b] (no menu principal) dá para trocar as letras por círculos com a [b]metade pintada[/b]: metade esquerda pintada = mão esquerda; metade direita pintada = mão direita.")

	linhas.append(_titulo("3. Como acertar"))
	linhas.append("- Os círculos vêm da direita e andam até a [b]marca branca[/b] na tela.")
	linhas.append("- Aperte a tecla certa no exato momento em que o centro do círculo chegar no meio da marca branca (ou em sincronia com o áudio).")
	linhas.append("- Tente sentir o ritmo da música, e não só seguir o círculo com os olhos.")

	linhas.append(_titulo("4. Durante a música"))
	linhas.append("- No alto da tela: a barra de progresso da música, a contagem de %s, %s, %s e %s, e a [b]Sequência[/b] (acertos seguidos)." % [
		_cor(COR_PERFEITO, "Perfeito"), _cor(COR_BOM, "Bom"), _cor(COR_RUIM, "Ruim"), _cor(COR_MISS, "Miss")])
	linhas.append("- [b]P[/b]: recomeça a música do zero, a qualquer momento (também na tela de resultado).")
	linhas.append("- [b]ESPAÇO[/b] ou [b]ENTER[/b]: para a música, encerra a partida e mostra o resultado.")
	linhas.append("- [b]Esc[/b]: volta ao menu (na tela de começar ou na tela de resultado).")
	linhas.append("- O som de cada batida é só um retorno para você: o que conta é o momento em que você aperta.")
	linhas.append("- Em [b]Configurações[/b] (no menu principal) dá para ajustar o volume da música e o das batidas separadamente.")

	linhas.append(_titulo("5. Como você é avaliado"))
	linhas.append("Cada batida é comparada com o instante exato da nota:")
	linhas.append("- %s: até %d ms de diferença" % [_cor(COR_PERFEITO, "[b]Perfeito[/b]"), GameManager.LIMITE_PERFEITO_MS])
	linhas.append("- %s: até %d ms" % [_cor(COR_BOM, "[b]Bom[/b]"), GameManager.LIMITE_BOM_MS])
	linhas.append("- %s: até %d ms" % [_cor(COR_RUIM, "[b]Ruim[/b]"), GameManager.LIMITE_RUIM_MS])
	linhas.append("- %s: a nota passou sem ser tocada a tempo" % _cor(COR_MISS, "[b]Miss[/b]"))
	linhas.append("A tecla também precisa ser a da nota, com a mão e o círculo certos (centro ou borda). Se apertar outra, aparece [b]TECLA ERRADA[/b]: não conta como acerto e a nota continua esperando a tecla certa até passar.")
	linhas.append("Apertar uma tecla quando não há nota para tocar aparece como [b]ERRO[/b] ou [b]EXTRA[/b] e não conta como acerto.")

	linhas.append(_titulo("6. Lendo o resultado"))
	linhas.append("- [b]Precisão de Acertos[/b]: a porcentagem de notas Perfeito ou Bom.")
	linhas.append("- [b]Erro de Precisão[/b]: em média, quantos milissegundos você errou. Quanto menor, melhor.")
	linhas.append("- [b]Maior Sequência de Acertos[/b]: o maior número de acertos seguidos.")
	linhas.append("- [b]Teclas Erradas[/b]: quantas vezes você apertou uma tecla diferente da pedida pela nota.")
	linhas.append("- [b]Tendência[/b]: negativa quer dizer que você aperta antes da hora (acelerando); positiva, depois da hora (atrasando). Perto de zero (até %d ms) é ótima consistência." % int(GameManager.LIMITE_TENDENCIA_MS))

	linhas.append(_titulo("7. Gravando uma música nova"))
	linhas.append("Você também pode criar músicas novas para o treino, tocando junto com um áudio seu.")
	linhas.append("- No menu principal, clique em [b]Gravar Nova Música[/b].")
	linhas.append("- Clique em [b]Importar Audio...[/b] e escolha um arquivo [b].mp3[/b] ou [b].ogg[/b] do computador.")
	linhas.append("- Clique em [b]Gravar[/b]. Uma contagem de 3 segundos avisa quando o áudio vai começar. Toques durante a contagem são ignorados, e um aviso aparece na tela.")
	linhas.append("- Toque junto com o áudio, com as mesmas teclas do treino (J, F, U e R). Cada toque vira uma nota, e o contador na tela mostra quantos já foram capturados.")
	linhas.append("- Ao terminar, clique em [b]Parar[/b]. Se errou muito, clique em [b]Gravar[/b] de novo: a gravação anterior é descartada.")
	linhas.append("- Digite um nome no campo de nome e clique em [b]Salvar[/b]. A música passa a aparecer na lista de [b]Selecionar Música e Iniciar Treinamento[/b].")
	linhas.append("- [b]Voltar ao Menu[/b] descarta o que ainda não foi salvo.")

	linhas.append(_titulo("Dicas"))
	linhas.append("- Prefira fone com fio ou o alto-falante do computador: fones Bluetooth ou sem fio podem causar um atraso sonoro.")
	linhas.append("- Errou o começo? Aperte [b]P[/b] e tente de novo.")
	linhas.append("- O objetivo principal desse Projeto é treinar o ritmo, não fazer pontos.")

	return "\n".join(linhas)
