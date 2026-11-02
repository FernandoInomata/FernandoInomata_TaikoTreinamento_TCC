extends Node2D
## UIManager
## Camada de Interface (UI): notas em movimento, retorno visual e diagnóstico.

@export var cena_nota: PackedScene = preload("res://Scenes/nota.tscn")

@onready var hit_indicador: ColorRect = $Hit
@onready var som_centro_dir: AudioStreamPlayer2D = $SomCentroDireito
@onready var som_centro_esq: AudioStreamPlayer2D = $SomCentroEsquerdo
@onready var som_borda_dir: AudioStreamPlayer2D = $SomBordaDireito
@onready var som_borda_esq: AudioStreamPlayer2D = $SomBordaEsquerdo
@onready var som_contagem: AudioStreamPlayer = $SomContagem
@onready var tela_diagnostico: ColorRect = $TelaDiagnostico
@onready var label_resultado: Label = $TelaDiagnostico/Resultado
@onready var grafico_contagens: Control = $TelaDiagnostico/GraficoContagens
@onready var barra_progresso: ProgressBar = $BarraProgresso
@onready var label_contagem: Label = $LabelContagem
@onready var label_combo: Label = $LabelCombo
@onready var tela_instrucoes: ColorRect = $TelaInstrucoes
@onready var label_titulo_instrucoes: Label = $TelaInstrucoes/Titulo
@onready var label_corpo_instrucoes: Label = $TelaInstrucoes/Corpo

const CATEGORIAS_PRINCIPAIS := ["Perfeito", "Bom", "Ruim", "Miss"]

const SEGUNDOS_CONTAGEM: int = 3
var em_contagem: bool = false

var contagem_classificacoes: Dictionary = {}
var combo_atual: int = 0
var maior_combo: int = 0

const CORES := {
	"Perfeito": Color.GOLD,
	"Bom": Color.GREEN,
	"Ruim": Color.DARK_RED,
	"Miss": Color.GRAY,
	"Miss (Omissao)": Color.GRAY,
	"Erro de Repeticao": Color.GRAY,
	"Batida Extra": Color.GRAY,
	"Tecla Errada": Color.ORANGE_RED,
}

const TEXTOS := {
	"Perfeito": "PERFEITO!",
	"Bom": "BOM!",
	"Ruim": "RUIM!",
	"Miss": "MISS!",
	"Miss (Omissao)": "MISS!",
	"Erro de Repeticao": "ERRO",
	"Batida Extra": "EXTRA",
	"Tecla Errada": "TECLA ERRADA",
}

const TEXTO_PRONTO := "Pressione ESPAÇO para começar\n\nEsc = voltar ao menu\n\nDúvidas? Veja \"Como Jogar\" no menu principal."

const TEXTO_INSTRUCOES_CALIBRACAO :="Esqueca o Don/Ka por enquanto -- e so um teste do sistema.\n\nVoce vai ouvir uma serie de cliques em um ritmo constante.\nAperte qualquer uma das 4 teclas (J, F, U ou R) exatamente\nno momento de cada clique, ate a serie terminar.\n\nO objetivo e medir o atraso do teclado, nao a sua precisao\nmusical -- va no seu ritmo natural, sem pressa.\n\nPressione Enter ou Espaco para comecar!"

const TEXTO_INSTRUCOES_BENCHMARK := "Este e um teste automatico do sistema -- ninguem precisa\napertar nenhuma tecla de jogo.\n\nO proprio software vai simular centenas de toques e medir\nquanto tempo o motor leva para processa-los, sem nenhum\nfator humano envolvido.\n\nDemora poucos segundos e o resultado aparece sozinho.\n\nPressione Enter ou Espaco para comecar o teste."


func _ready() -> void:
	for som in [som_centro_dir, som_centro_esq, som_borda_dir, som_borda_esq, som_contagem]:
		som.bus = AudioManager.BUS_BATIDAS
	InputManager.batida_capturada.connect(_on_batida_capturada)
	InputManager.finalizar_solicitado.connect(_on_finalizar_solicitado)
	GameManager.nota_deve_spawnar.connect(_on_nota_deve_spawnar)
	GameManager.nota_processada.connect(_on_nota_processada)
	GameManager.diagnostico_pronto.connect(_on_diagnostico_pronto)
	GameManager.fase_reiniciada.connect(_on_fase_reiniciada)
	GameManager.clique_calibracao.connect(_on_clique_calibracao)
	GameManager.benchmark_pronto.connect(_on_benchmark_pronto)
	InputManager.voltar_menu_solicitado.connect(_on_voltar_menu_solicitado)

	label_contagem.add_theme_font_size_override("font_size", 22)
	label_combo.add_theme_font_size_override("font_size", 22)
	match GameManager.modo_atual:
		GameManager.ModoJogo.CALIBRACAO:
			_usar_layout_texto_longo()
			label_titulo_instrucoes.text = "TESTE DE LATENCIA"
			label_corpo_instrucoes.text = TEXTO_INSTRUCOES_CALIBRACAO + "\nEsc = voltar ao menu"
		GameManager.ModoJogo.BENCHMARK:
			_usar_layout_texto_longo()
			label_titulo_instrucoes.text = "BENCHMARK AUTOMATICO"
			label_corpo_instrucoes.text = TEXTO_INSTRUCOES_BENCHMARK + "\nEsc = voltar ao menu"
		_:
			_configurar_tela_pronto()
	_atualizar_hud_contagem()


## Tela mostrada antes de cada partida de AVALIACAO: só o nome da musica e o convite para apertar ESPACO.
func _configurar_tela_pronto() -> void:
	var nome := GameManager.nome_musica_selecionada
	label_titulo_instrucoes.text = nome if nome != "" else "TREINO"
	label_corpo_instrucoes.text = TEXTO_PRONTO
	label_corpo_instrucoes.add_theme_font_size_override("font_size", 28)


## Calibracao e benchmark (modos de pesquisa) usam um bloco de texto longo, alinhado a esquerda.
func _usar_layout_texto_longo() -> void:
	label_titulo_instrucoes.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_titulo_instrucoes.position = Vector2(40, 30)
	label_corpo_instrucoes.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_corpo_instrucoes.position = Vector2(40, 100)
	label_corpo_instrucoes.add_theme_font_size_override("font_size", 24)


func _process(_delta: float) -> void:
	_atualizar_barra_progresso()


func _atualizar_barra_progresso() -> void:
	if AudioManager.stream == null:
		return
	var duracao := AudioManager.stream.get_length()
	if duracao <= 0.0:
		return
	barra_progresso.value = clampf(AudioManager.tempo_atual_musica / duracao, 0.0, 1.0)


func _on_batida_capturada(tipo: String, tempo: float) -> void:
	_tocar_som_da_batida(tipo)
	GameManager.registrar_batida(tipo, tempo)


## Modo CALIBRACAO: toca um clique audivel e pisca a zona de acerto, sem instanciar nota visual.
func _on_clique_calibracao(_tempo_esperado: float) -> void:
	som_centro_dir.play()
	hit_indicador.modulate = Color.YELLOW
	var tween := create_tween()
	tween.tween_property(hit_indicador, "modulate", Color.WHITE, 0.15)


## Centro do quadrado branco (nó "Hit"), em coordenadas da cena.
func _centro_zona_de_acerto() -> Vector2:
	return hit_indicador.position + hit_indicador.size / 2.0


func _on_nota_deve_spawnar(dados_nota: Dictionary) -> void:
	var nova_nota := cena_nota.instantiate()
	var centro_zona := _centro_zona_de_acerto()
	nova_nota.x_zona_de_acerto = centro_zona.x
	nova_nota.position = centro_zona
	nova_nota.configurar(dados_nota)
	nova_nota.add_to_group("notas_ativas")
	add_child(nova_nota)


func _on_nota_processada(resultado: Dictionary) -> void:
	var classificacao: String = resultado["classificacao"]
	_animar_feedback_visual(
		TEXTOS.get(classificacao, classificacao),
		CORES.get(classificacao, Color.WHITE)
	)
	_atualizar_combo_e_contagem(classificacao)


func _atualizar_combo_e_contagem(classificacao: String) -> void:
	var chave := "Miss" if classificacao == "Miss (Omissao)" else classificacao
	if chave in CATEGORIAS_PRINCIPAIS:
		contagem_classificacoes[chave] = contagem_classificacoes.get(chave, 0) + 1

	if classificacao in ["Perfeito", "Bom"]:
		combo_atual += 1
		maior_combo = max(maior_combo, combo_atual)
	elif classificacao in ["Ruim", "Miss", "Miss (Omissao)", "Tecla Errada"]:
		combo_atual = 0

	_atualizar_hud_contagem()


func _atualizar_hud_contagem() -> void:
	label_combo.text = "Sequencia: %d" % combo_atual
	label_contagem.text = "Perfeito: %d   Bom: %d   Ruim: %d   Miss: %d" % [
		contagem_classificacoes.get("Perfeito", 0),
		contagem_classificacoes.get("Bom", 0),
		contagem_classificacoes.get("Ruim", 0),
		contagem_classificacoes.get("Miss", 0),
	]


## O mesmo sinal de "confirmar" inicia o jogo (com contagem regressiva) na tela de instruções e encerra a sessão durante a partida.
func _on_finalizar_solicitado() -> void:
	if not GameManager.jogo_iniciado:
		if em_contagem:
			return
		_iniciar_com_contagem()
		return
	if GameManager.sessao_encerrada:
		return
	GameManager.finalizar_sessao()


## Toca um aviso sonoro e espera a contagem antes de iniciar a musica e a captura de toques.
func _iniciar_com_contagem() -> void:
	em_contagem = true
	GameManager.iniciar_pre_contagem(SEGUNDOS_CONTAGEM)
	for restante in range(SEGUNDOS_CONTAGEM, 0, -1):
		label_titulo_instrucoes.text = "PREPARE-SE"
		label_corpo_instrucoes.text = "Comeca em %d..." % restante
		som_contagem.play()
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return

	em_contagem = false
	tela_instrucoes.hide()
	GameManager.iniciar_jogo()


## Esc volta ao menu só na tela de instrucoes ou no diagnostico final, para um toque acidental nao encerrar uma sessao em andamento.
func _on_voltar_menu_solicitado() -> void:
	if not (tela_instrucoes.visible or tela_diagnostico.visible):
		return
	em_contagem = false
	GameManager.resetar_sessao()
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")


## Reage ao reinicio da fase (tecla P): limpa as notas em tela, zera o HUD e esconde o laudo.
func _on_fase_reiniciada() -> void:
	get_tree().call_group("notas_ativas", "queue_free")
	contagem_classificacoes.clear()
	combo_atual = 0
	maior_combo = 0
	_atualizar_hud_contagem()
	tela_diagnostico.hide()
	hit_indicador.visible = true


func _on_diagnostico_pronto(laudo: Dictionary) -> void:
	get_tree().call_group("notas_ativas", "queue_free")
	hit_indicador.visible = false

	var titulo := "TESTE DE LATÊNCIA" if GameManager.modo_atual == GameManager.ModoJogo.CALIBRACAO else "DIAGNOSTICO DO TREINO"
	var texto := titulo + "\n\n"
	var teclas_erradas := GameManager.contar_teclas_erradas()
	if laudo.is_empty():
		texto += "Nenhuma batida válida foi registrada.\n"
		if teclas_erradas > 0:
			texto += "Teclas Erradas: %d (confira a mão e o centro/borda de cada nota)\n" % teclas_erradas
		texto += "Toque as teclas no ritmo das notas para ver o seu diagnóstico."
	else:
		texto += "Precisão de Acertos: %.1f%%\n" % laudo["precisao"]
		texto += "Erro de Precisão: %d ms de distância do centro\n" % int(laudo["mae"])
		texto += "Maior Sequência de Acertos: %d\n" % maior_combo
		if GameManager.modo_atual != GameManager.ModoJogo.CALIBRACAO:
			texto += "Teclas Erradas: %d\n" % teclas_erradas

		var tendencia: float = laudo["tendencia"]
		if tendencia < -GameManager.LIMITE_TENDENCIA_MS:
			texto += "Tendência (%.1f ms): Você está ACELERANDO." % tendencia
		elif tendencia > GameManager.LIMITE_TENDENCIA_MS:
			texto += "Tendência (%.1f ms): Você está ATRASANDO." % tendencia
		else:
			texto += "Tendência (%.1f ms): Ótima consistência!" % tendencia

	label_resultado.text = texto
	_construir_grafico_classificacoes()
	tela_diagnostico.show()


## Resultado do benchmark automático (sem humano) de latência do pipeline de software.
func _on_benchmark_pronto(estatisticas: Dictionary) -> void:
	if estatisticas.is_empty():
		return

	var texto := "BENCHMARK DE LATÊNCIA DO SISTEMA\n\n"
	texto += "Amostras: %d\n" % estatisticas["amostras"]
	texto += "Media: %.2f ms\n" % estatisticas["media_ms"]
	texto += "Mediana: %.2f ms\n" % estatisticas["mediana_ms"]
	texto += "Minima: %.2f ms\n" % estatisticas["minima_ms"]
	texto += "Maxima: %.2f ms\n" % estatisticas["maxima_ms"]
	texto += "Desvio Padrao: %.2f ms\n" % estatisticas["desvio_padrao_ms"]

	label_resultado.text = texto
	tela_diagnostico.show()


## Grafico de barras simples com a contagem de cada classificacao, para leitura rapida do laudo.
func _construir_grafico_classificacoes() -> void:
	for filho in grafico_contagens.get_children():
		filho.queue_free()

	var maior := 1
	for categoria in CATEGORIAS_PRINCIPAIS:
		maior = max(maior, contagem_classificacoes.get(categoria, 0))

	var altura_max := 260.0
	var largura_barra := 120.0
	var espaco := 60.0
	var largura_total := CATEGORIAS_PRINCIPAIS.size() * largura_barra + (CATEGORIAS_PRINCIPAIS.size() - 1) * espaco
	var x := (grafico_contagens.size.x - largura_total) / 2.0

	for categoria in CATEGORIAS_PRINCIPAIS:
		var valor: int = contagem_classificacoes.get(categoria, 0)
		var altura: float = (valor / float(maior)) * altura_max

		var barra := ColorRect.new()
		barra.color = CORES.get(categoria, Color.WHITE)
		barra.size = Vector2(largura_barra, altura)
		barra.position = Vector2(x, altura_max - altura)
		grafico_contagens.add_child(barra)

		var label_valor := Label.new()
		label_valor.text = str(valor)
		label_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_valor.add_theme_font_size_override("font_size", 22)
		label_valor.position = Vector2(x, altura_max - altura - 30.0)
		label_valor.size = Vector2(largura_barra, 26.0)
		grafico_contagens.add_child(label_valor)

		var label_nome := Label.new()
		label_nome.text = categoria
		label_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_nome.add_theme_font_size_override("font_size", 20)
		label_nome.position = Vector2(x, altura_max + 6.0)
		label_nome.size = Vector2(largura_barra, 26.0)
		grafico_contagens.add_child(label_nome)

		x += largura_barra + espaco


func _tocar_som_da_batida(tipo: String) -> void:
	match tipo:
		"Direita":
			som_centro_dir.play()
		"Esquerda":
			som_centro_esq.play()
		"Dir_Borda":
			som_borda_dir.play()
		"Esquerda_Borda":
			som_borda_esq.play()


func _animar_feedback_visual(texto: String, cor: Color) -> void:
	var novo_label := Label.new()
	novo_label.text = texto
	novo_label.modulate = cor
	novo_label.add_theme_font_size_override("font_size", 40)

	var desvio_x := randf_range(-15.0, 15.0)
	var desvio_y := randf_range(-10.0, 10.0)
	novo_label.position = Vector2(220 + desvio_x, 150 + desvio_y)

	add_child(novo_label)

	var tween := create_tween()
	tween.tween_property(novo_label, "position", novo_label.position - Vector2(0, 50), 0.5)
	tween.parallel().tween_property(novo_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(novo_label.queue_free)
