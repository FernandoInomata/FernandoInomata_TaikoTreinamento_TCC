extends AudioStreamPlayer2D
## AudioManager (Autoload / Singleton)
## Camada de Gerenciamento (Core): mantém o tempo da aplicação sincronizado com o relógio do servidor de áudio (T_atual = T_mix - L_saída).

var tempo_atual_musica: float = 0.0

const BUS_MUSICA := &"Musica"
const BUS_BATIDAS := &"Batidas"


func _ready() -> void:
	_garantir_bus(BUS_MUSICA)
	_garantir_bus(BUS_BATIDAS)
	bus = BUS_MUSICA


func _garantir_bus(nome: StringName) -> void:
	if AudioServer.get_bus_index(nome) != -1:
		return
	AudioServer.add_bus()
	var indice := AudioServer.bus_count - 1
	AudioServer.set_bus_name(indice, nome)
	AudioServer.set_bus_send(indice, &"Master")


## Volume da musica, de 0.0 (mudo) a 1.0 (padrao).
func definir_volume_musica(linear: float) -> void:
	_aplicar_volume(BUS_MUSICA, linear)


## Volume dos sons de batida e da contagem, de 0.0 (mudo) a 2.0; 1.0 e o padrao.
func definir_volume_batidas(linear: float) -> void:
	_aplicar_volume(BUS_BATIDAS, linear)


func _aplicar_volume(nome: StringName, linear: float) -> void:
	var indice := AudioServer.get_bus_index(nome)
	if indice == -1:
		return
	AudioServer.set_bus_mute(indice, linear <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(linear, 0.0001)))

var _em_pre_contagem: bool = false
var _duracao_pre_contagem: float = 0.0
var _tempo_pre_contagem_decorrido: float = 0.0


## Inicia o relogio da contagem regressiva: tempo_atual_musica anda de -segundos ate 0.0, para as notas ja aparecerem na tela antes da musica comecar.
func iniciar_pre_contagem(segundos: float) -> void:
	_em_pre_contagem = true
	_duracao_pre_contagem = segundos
	_tempo_pre_contagem_decorrido = 0.0
	tempo_atual_musica = -segundos


## Encerra o relogio da contagem regressiva, ao iniciar o jogo de verdade ou ao cancelar a sessao.
func encerrar_pre_contagem() -> void:
	_em_pre_contagem = false


## Reinicia a faixa do zero, usado ao resetar a fase (tecla P).
func reiniciar() -> void:
	play(0.0)
	tempo_atual_musica = 0.0


## Carrega um áudio (.mp3 ou .ogg) em tempo de execução e o define como stream do player.
## Caminhos res:// usam load(); os demais são lidos do disco com load_from_file().
func carregar_stream_dinamico(caminho: String) -> bool:
	var novo_stream: AudioStream

	if caminho.begins_with("res://"):
		var recurso = load(caminho)
		if recurso is AudioStream:
			novo_stream = recurso
		else:
			push_error("Nao foi possivel carregar o audio embutido: " + caminho)
			return false
	else:
		if not FileAccess.file_exists(caminho):
			push_error("Arquivo de audio nao encontrado: " + caminho)
			return false

		var extensao := caminho.get_extension().to_lower()
		match extensao:
			"mp3":
				novo_stream = AudioStreamMP3.load_from_file(caminho)
			"ogg":
				novo_stream = AudioStreamOggVorbis.load_from_file(caminho)
			_:
				push_error("Formato de audio nao suportado: ." + extensao)
				return false

		if novo_stream == null:
			push_error("Falha ao carregar o audio: " + caminho)
			return false

	stop()
	stream = novo_stream
	tempo_atual_musica = 0.0
	return true


func _process(delta: float) -> void:
	if _em_pre_contagem:
		_tempo_pre_contagem_decorrido += delta
		tempo_atual_musica = _tempo_pre_contagem_decorrido - _duracao_pre_contagem
		return

	if not playing:
		return
	## T_atual = T_mix − L_saíd
	var tempo_mix: float = get_playback_position() + AudioServer.get_time_since_last_mix()

	var latencia_saida: float = AudioServer.get_output_latency()

	tempo_atual_musica = tempo_mix - latencia_saida

