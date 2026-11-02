extends Node
## InputManager (Autoload / Singleton)
## Camada de Captura (Input): recebe as teclas e registra o instante de cada batida.

signal batida_capturada(tipo: String, tempo: float)
signal finalizar_solicitado
signal reiniciar_solicitado
signal voltar_menu_solicitado
signal benchmark_concluido(latencias_us: Array)

const ACAO_BENCHMARK := "Direita"
const QUANTIDADE_AMOSTRAS_BENCHMARK := 200

var _benchmark_em_andamento: bool = false
var _t0_benchmark_us: int = 0
var _latencia_pendente_us: int = -1


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if _benchmark_em_andamento and event is InputEventAction and event.action == ACAO_BENCHMARK:
		_latencia_pendente_us = Time.get_ticks_usec() - _t0_benchmark_us
		return

	var tipo_batida := _mapear_acao(event)
	if tipo_batida != "":
		var tempo_batida: float = AudioManager.tempo_atual_musica
		batida_capturada.emit(tipo_batida, tempo_batida)

	if event.is_action_pressed("ui_accept"):
		finalizar_solicitado.emit()

	if event.is_action_pressed("Reiniciar"):
		reiniciar_solicitado.emit()

	if event.is_action_pressed("ui_cancel"):
		voltar_menu_solicitado.emit()


## Mapeia os fonemas do Kuchi-shoga (Don/Kon = centro, Ka/Ra = borda) para as ações de teclado configuradas no Input Map do projeto.
func _mapear_acao(event: InputEvent) -> String:
	if event.is_action("Direita"):
		return "Direita"
	elif event.is_action("Esquerda"):
		return "Esquerda"
	elif event.is_action("Direita_Borda"):
		return "Dir_Borda"
	elif event.is_action("Esquerda_Borda"):
		return "Esquerda_Borda"
	return ""


## Injeta eventos de teclado sintéticos e mede, em microssegundos, o tempo até cada um ser processado em _unhandled_input.
func rodar_benchmark_latencia() -> void:
	if _benchmark_em_andamento:
		return
	_benchmark_em_andamento = true
	var latencias_us: Array = []

	for i in QUANTIDADE_AMOSTRAS_BENCHMARK:
		await get_tree().process_frame
		_latencia_pendente_us = -1
		_t0_benchmark_us = Time.get_ticks_usec()

		var evento := InputEventAction.new()
		evento.action = ACAO_BENCHMARK
		evento.pressed = true
		Input.parse_input_event(evento)

		var tentativas := 0
		while _latencia_pendente_us < 0 and tentativas < 60:
			await get_tree().process_frame
			tentativas += 1

		if _latencia_pendente_us >= 0:
			latencias_us.append(_latencia_pendente_us)

	_benchmark_em_andamento = false
	benchmark_concluido.emit(latencias_us)
