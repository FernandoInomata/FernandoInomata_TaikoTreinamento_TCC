extends Control
## Tela Configurações (botão do menu principal).
## Áudio: volume da música (0 a 100%) e das batidas (0 a 200%; 100% é o som como sempre foi).

@onready var slider_musica: HSlider = $SliderMusica
@onready var slider_batidas: HSlider = $SliderBatidas
@onready var valor_musica: Label = $ValorMusica
@onready var valor_batidas: Label = $ValorBatidas
@onready var opcao_letras: CheckBox = $OpcaoLetras
@onready var opcao_metade: CheckBox = $OpcaoMetade
@onready var previa: Control = $Previa
@onready var botao_voltar: Button = $BotaoVoltar
@onready var tempo_salvar: Timer = $TempoSalvar
@onready var som_teste: AudioStreamPlayer = $SomTeste

var _salvar_pendente := false
var _amostra_pendente := false


func _ready() -> void:
	som_teste.bus = AudioManager.BUS_BATIDAS

	slider_musica.value = GameManager.volume_musica * 100.0
	slider_batidas.value = GameManager.volume_batidas * 100.0
	valor_musica.text = "%d%%" % int(slider_musica.value)
	valor_batidas.text = "%d%%" % int(slider_batidas.value)
	var metade := GameManager.estilo_mao == GameManager.EstiloMao.METADE
	opcao_metade.button_pressed = metade
	opcao_letras.button_pressed = not metade

	slider_musica.value_changed.connect(_on_musica_mudou)
	slider_batidas.value_changed.connect(_on_batidas_mudou)
	opcao_letras.toggled.connect(_on_letras_toggled)
	opcao_metade.toggled.connect(_on_metade_toggled)
	tempo_salvar.timeout.connect(_on_tempo_salvar)
	botao_voltar.pressed.connect(_voltar_ao_menu)
	InputManager.voltar_menu_solicitado.connect(_voltar_ao_menu)


func _on_musica_mudou(valor: float) -> void:
	GameManager.definir_volume_musica(valor / 100.0)
	valor_musica.text = "%d%%" % int(valor)
	_agendar_salvar(false)


func _on_batidas_mudou(valor: float) -> void:
	GameManager.definir_volume_batidas(valor / 100.0)
	valor_batidas.text = "%d%%" % int(valor)
	_agendar_salvar(true)


## Espera o controle parar de mexer (0,5 s) antes de gravar o arquivo e tocar a batida de amostra.
func _agendar_salvar(tocar_amostra: bool) -> void:
	_salvar_pendente = true
	if tocar_amostra:
		_amostra_pendente = true
	tempo_salvar.start()


func _on_tempo_salvar() -> void:
	GameManager.salvar_configuracoes()
	_salvar_pendente = false
	if _amostra_pendente:
		_amostra_pendente = false
		som_teste.play()


func _on_letras_toggled(ligado: bool) -> void:
	if ligado:
		_escolher_estilo(GameManager.EstiloMao.LETRAS)


func _on_metade_toggled(ligado: bool) -> void:
	if ligado:
		_escolher_estilo(GameManager.EstiloMao.METADE)


func _escolher_estilo(estilo: int) -> void:
	GameManager.definir_estilo_mao(estilo)
	previa.queue_redraw()


func _voltar_ao_menu() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")


## Saiu da tela antes do tempo de espera acabar: grava agora.
func _exit_tree() -> void:
	if _salvar_pendente:
		GameManager.salvar_configuracoes()
