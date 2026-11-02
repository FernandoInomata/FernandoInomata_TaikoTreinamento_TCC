extends Control
## Menu Principal
## Ponto de entrada do aplicativo (run/main_scene).

@onready var botao_selecionar: Button = $BotaoSelecionar
@onready var botao_gravar: Button = $BotaoGravar
@onready var botao_como_jogar: Button = $BotaoComoJogar
@onready var botao_configuracoes: Button = $BotaoConfiguracoes
@onready var botao_pasta_dados: Button = $BotaoPastaDados
@onready var botao_sair: Button = $BotaoSair
@onready var label_pasta_dados: Label = $LabelPastaDados


func _ready() -> void:
	botao_selecionar.pressed.connect(_on_selecionar_pressionado)
	botao_gravar.pressed.connect(_on_gravar_pressionado)
	botao_como_jogar.pressed.connect(_on_como_jogar_pressionado)
	botao_configuracoes.pressed.connect(_on_configuracoes_pressionado)
	botao_pasta_dados.pressed.connect(_on_pasta_dados_pressionado)
	botao_sair.pressed.connect(_on_sair_pressionado)
	label_pasta_dados.text = "Musicas e relatorios ficam em: " + _pasta_dados_absoluta()


func _pasta_dados_absoluta() -> String:
	return ProjectSettings.globalize_path(GameManager.pasta_base_dados)


func _on_selecionar_pressionado() -> void:
	get_tree().change_scene_to_file("res://Scenes/selecao_musica.tscn")


func _on_gravar_pressionado() -> void:
	get_tree().change_scene_to_file("res://Scenes/gravacao.tscn")


func _on_como_jogar_pressionado() -> void:
	get_tree().change_scene_to_file("res://Scenes/como_jogar.tscn")


func _on_configuracoes_pressionado() -> void:
	get_tree().change_scene_to_file("res://Scenes/configuracoes.tscn")


## Encerra o programa.
func _on_sair_pressionado() -> void:
	get_tree().quit()


## Abre no Explorer a pasta que contém "musicas" e "relatorios", de onde os relatórios são recolhidos.
func _on_pasta_dados_pressionado() -> void:
	OS.shell_open(_preparar_pasta_dados())


## Garante que "musicas" e "relatorios" existem e devolve o caminho da pasta que as contém.
func _preparar_pasta_dados() -> String:
	DirAccess.make_dir_recursive_absolute(GameManager.pasta_musicas)
	DirAccess.make_dir_recursive_absolute(GameManager.pasta_relatorios)
	return _pasta_dados_absoluta()
