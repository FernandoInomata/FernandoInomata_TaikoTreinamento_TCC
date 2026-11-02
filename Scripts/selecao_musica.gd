extends Node2D
## Tela de Seleção de Música
## Lista as músicas já gravadas (biblioteca em user://musicas/) para o pesquisador escolher qual usar numa sessão de avaliação.

@onready var lista_musicas: VBoxContainer = $ListaMusicas
@onready var label_vazio: Label = $LabelListaVazia
@onready var botao_ir_gravar: Button = $BotaoIrGravar
@onready var botao_voltar: Button = $BotaoVoltar


func _ready() -> void:
	botao_voltar.pressed.connect(_on_voltar_pressionado)
	botao_ir_gravar.pressed.connect(_on_ir_gravar_pressionado)
	_popular_lista()


func _popular_lista() -> void:
	for filho in lista_musicas.get_children():
		filho.queue_free()

	var musicas := GameManager.listar_musicas_salvas()
	var vazio := musicas.is_empty()
	label_vazio.visible = vazio
	botao_ir_gravar.visible = vazio

	for musica in musicas:
		var botao := Button.new()
		botao.text = "%s   (%s)" % [musica["nome"], musica["criado_em"]]
		botao.custom_minimum_size = Vector2(0, 48)
		botao.pressed.connect(_on_musica_selecionada.bind(musica["pasta"]))
		lista_musicas.add_child(botao)


func _on_musica_selecionada(pasta: String) -> void:
	if GameManager.selecionar_musica(pasta):
		get_tree().change_scene_to_file("res://Scenes/camera_input.tscn")
	else:
		label_vazio.text = "Erro ao carregar essa musica -- veja o console."
		label_vazio.visible = true


func _on_voltar_pressionado() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")


func _on_ir_gravar_pressionado() -> void:
	get_tree().change_scene_to_file("res://Scenes/gravacao.tscn")
