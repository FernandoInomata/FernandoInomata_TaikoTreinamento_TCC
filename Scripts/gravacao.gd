extends Node2D
## Tela de Gravação
## Fluxo: importar um áudio (.mp3/.ogg), tocar e gravar os toques em tempo real, depois nomear e salvar como música nova.

@onready var botao_importar: Button = $BotaoImportar
@onready var label_arquivo: Label = $LabelArquivoAudio
@onready var botao_gravar: Button = $BotaoGravar
@onready var botao_parar: Button = $BotaoParar
@onready var label_status: Label = $LabelStatus
@onready var campo_nome: LineEdit = $CampoNome
@onready var botao_salvar: Button = $BotaoSalvar
@onready var botao_voltar: Button = $BotaoVoltar
@onready var dialogo_arquivo: FileDialog = $DialogoArquivo
@onready var som_contagem: AudioStreamPlayer = $SomContagem

const SEGUNDOS_CONTAGEM: int = 3

var caminho_audio_importado: String = ""
var gravando: bool = false
var em_contagem: bool = false


func _ready() -> void:
	som_contagem.bus = AudioManager.BUS_BATIDAS
	botao_gravar.disabled = true
	botao_parar.disabled = true
	botao_salvar.disabled = true

	botao_importar.pressed.connect(_on_importar_pressionado)
	botao_gravar.pressed.connect(_on_gravar_pressionado)
	botao_parar.pressed.connect(_on_parar_pressionado)
	botao_salvar.pressed.connect(_on_salvar_pressionado)
	botao_voltar.pressed.connect(_on_voltar_pressionado)
	dialogo_arquivo.file_selected.connect(_on_arquivo_selecionado)
	InputManager.batida_capturada.connect(_on_batida_capturada)


func _on_importar_pressionado() -> void:
	dialogo_arquivo.popup_centered(Vector2i(700, 500))


func _on_arquivo_selecionado(caminho: String) -> void:
	if not AudioManager.carregar_stream_dinamico(caminho):
		label_status.text = "Falha ao carregar o audio (formato suportado: .mp3, .ogg)."
		return

	caminho_audio_importado = caminho
	label_arquivo.text = "Audio: " + caminho.get_file()
	GameManager.gravacao_atual.clear()
	botao_gravar.disabled = false
	botao_salvar.disabled = true
	label_status.text = "Pronto para gravar."


## Toca um aviso sonoro e espera a contagem antes de iniciar o áudio e a captura de toques.
func _on_gravar_pressionado() -> void:
	em_contagem = true
	botao_importar.disabled = true
	botao_gravar.disabled = true
	botao_parar.disabled = true
	botao_salvar.disabled = true

	for restante in range(SEGUNDOS_CONTAGEM, 0, -1):
		label_status.text = "Prepare-se... comeca em %d" % restante
		som_contagem.play()
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return

	em_contagem = false
	GameManager.iniciar_gravacao()
	gravando = true
	botao_parar.disabled = false
	label_status.text = "Gravando... toques capturados: 0"


func _on_batida_capturada(tipo: String, tempo: float) -> void:
	if em_contagem:
		label_status.text = "Toque ignorado -- ainda em contagem, espere comecar."
		return
	if not gravando:
		return
	GameManager.registrar_batida(tipo, tempo)
	label_status.text = "Gravando... toques capturados: %d" % GameManager.gravacao_atual.size()


func _on_parar_pressionado() -> void:
	GameManager.parar_gravacao()
	gravando = false
	botao_importar.disabled = false
	botao_parar.disabled = true
	botao_gravar.disabled = false
	botao_salvar.disabled = GameManager.gravacao_atual.is_empty()
	label_status.text = "Parado. %d toques capturados." % GameManager.gravacao_atual.size()


func _on_salvar_pressionado() -> void:
	var nome := campo_nome.text.strip_edges()
	if nome == "":
		label_status.text = "Digite um nome antes de salvar."
		return

	if GameManager.salvar_gravacao(nome, caminho_audio_importado):
		label_status.text = "Musica salva! Voltando ao menu..."
		get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")
	else:
		label_status.text = "Erro ao salvar -- confira o console para detalhes."


func _on_voltar_pressionado() -> void:
	em_contagem = false
	GameManager.parar_gravacao()
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")
