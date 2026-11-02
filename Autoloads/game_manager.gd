extends Node
## GameManager (Autoload / Singleton)
## Camada de Gerenciamento (Core): máquina de estados, avaliação rítmica, biblioteca de músicas e relatórios.

signal nota_processada(resultado: Dictionary)
signal nota_deve_spawnar(dados_nota: Dictionary)
signal diagnostico_pronto(laudo: Dictionary)
signal fase_reiniciada
signal clique_calibracao(tempo_esperado: float)
signal benchmark_pronto(estatisticas: Dictionary)

enum ModoJogo { AVALIACAO, GRAVACAO, CALIBRACAO, BENCHMARK }

@export var modo_atual: ModoJogo = ModoJogo.AVALIACAO

const Relatorio := preload("res://Scripts/relatorio.gd")

const CAMINHO_PARTITURA :="res://Musics/MapeamentoBatidas/mapeamento_taiko.txt"
const TEMPO_ANTECIPACAO := 1.5

const PASTA_MUSICAS_PADRAO := "res://MusicasPadrao/"

var pasta_base_dados: String = ""
var pasta_musicas: String = ""
var pasta_relatorios: String = ""

enum EstiloMao { LETRAS, METADE }
const ARQUIVO_CONFIGURACOES := "configuracoes.cfg"
var estilo_mao: EstiloMao = EstiloMao.LETRAS
const VOLUME_MAXIMO_MUSICA := 1.0
const VOLUME_MAXIMO_BATIDAS := 2.0
var volume_musica: float = 1.0
var volume_batidas: float = 1.0

const INTERVALO_CALIBRACAO := 1.0
const QUANTIDADE_CLIQUES_CALIBRACAO := 30

const LIMITE_PERFEITO_MS := 30
const LIMITE_BOM_MS := 70
const LIMITE_RUIM_MS := 120
const LIMITE_REPETICAO_MS := -120
const LIMITE_TENDENCIA_MS := 20.0

var partitura: Array = []
var historico_partida: Array = []
var indice_nota_atual: int = 0
var indice_spawn: int = 0
var relatorio_salvo: bool = false
var em_pre_contagem: bool = false
var sessao_encerrada: bool = false
var caminho_relatorio_sessao: String = ""
var inicio_sessao: Dictionary = {}
var jogo_iniciado: bool = false

var pasta_musica_selecionada: String = ""
var nome_musica_selecionada: String = ""
var gravacao_atual: Array = []


func _init() -> void:
	_definir_pastas(_resolver_base_dados())


func _definir_pastas(base: String) -> void:
	pasta_base_dados = base
	pasta_musicas = base + "musicas/"
	pasta_relatorios = base + "relatorios/"


## Decide onde guardar musicas e relatorios: no editor usa user://, no executavel usa a pasta Dados ao lado dele (modo portatil).
func _resolver_base_dados(forcar_portatil: bool = false, dir_exe: String = "") -> String:
	if OS.has_feature("editor") and not forcar_portatil:
		return "user://"

	if dir_exe == "":
		dir_exe = OS.get_executable_path().get_base_dir()
	var base := dir_exe.path_join("Dados")
	DirAccess.make_dir_recursive_absolute(base)
	var sonda := base.path_join(".sonda_escrita")
	var arquivo := FileAccess.open(sonda, FileAccess.WRITE)
	if arquivo == null:
		return "user://"
	arquivo.close()
	DirAccess.remove_absolute(sonda)
	return base + "/"


func _carregar_configuracoes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(pasta_base_dados + ARQUIVO_CONFIGURACOES) != OK:
		return
	var valor := int(cfg.get_value("exibicao", "estilo_mao", EstiloMao.LETRAS))
	estilo_mao = valor if valor in EstiloMao.values() else EstiloMao.LETRAS
	volume_musica = _ler_volume(cfg, "volume_musica", 1.0, VOLUME_MAXIMO_MUSICA)
	volume_batidas = _ler_volume(cfg, "volume_batidas", 1.0, VOLUME_MAXIMO_BATIDAS)


func _ler_volume(cfg: ConfigFile, chave: String, padrao: float, maximo: float) -> float:
	var valor = cfg.get_value("audio", chave, padrao)
	if typeof(valor) != TYPE_FLOAT and typeof(valor) != TYPE_INT:
		return padrao
	return clampf(float(valor), 0.0, maximo)


## Grava todas as preferencias em configuracoes.cfg.
func salvar_configuracoes() -> void:
	DirAccess.make_dir_recursive_absolute(pasta_base_dados)
	var caminho := pasta_base_dados + ARQUIVO_CONFIGURACOES
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	cfg.set_value("exibicao", "estilo_mao", int(estilo_mao))
	cfg.set_value("audio", "volume_musica", volume_musica)
	cfg.set_value("audio", "volume_batidas", volume_batidas)
	if cfg.save(caminho) != OK:
		push_warning("Nao foi possivel salvar as configuracoes em: " + caminho)


## Muda como a mao de cada nota e mostrada e ja salva a escolha.
func definir_estilo_mao(estilo: EstiloMao) -> void:
	estilo_mao = estilo
	salvar_configuracoes()


## Muda o volume da musica na hora.
func definir_volume_musica(linear: float) -> void:
	volume_musica = clampf(linear, 0.0, VOLUME_MAXIMO_MUSICA)
	AudioManager.definir_volume_musica(volume_musica)


## Idem para os sons de batida (e o bipe da contagem).
func definir_volume_batidas(linear: float) -> void:
	volume_batidas = clampf(linear, 0.0, VOLUME_MAXIMO_BATIDAS)
	AudioManager.definir_volume_batidas(volume_batidas)


func _ready() -> void:
	_carregar_configuracoes()
	AudioManager.definir_volume_musica(volume_musica)
	AudioManager.definir_volume_batidas(volume_batidas)
	match modo_atual:
		ModoJogo.AVALIACAO:
			_carregar_partitura()
		ModoJogo.CALIBRACAO:
			_gerar_partitura_calibracao()
		ModoJogo.GRAVACAO, ModoJogo.BENCHMARK:
			pass
	InputManager.reiniciar_solicitado.connect(reiniciar_fase)
	InputManager.benchmark_concluido.connect(_on_benchmark_concluido)


## Salva o relatorio automaticamente se a janela for fechada no meio de uma sessao, evitando perda silenciosa de dados.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if modo_atual != ModoJogo.GRAVACAO and not historico_partida.is_empty() and not relatorio_salvo:
			_gerar_relatorio("Janela fechada antes de encerrar")
		get_tree().quit()


## Chamado pela UI quando a contagem regressiva comeca: as notas ja surgem na tela antes da musica tocar (ver AudioManager.iniciar_pre_contagem).
func iniciar_pre_contagem(segundos: float) -> void:
	if modo_atual != ModoJogo.AVALIACAO:
		return
	em_pre_contagem = true
	AudioManager.iniciar_pre_contagem(segundos)


## Chamado pelo UIManager quando o participante confirma a tela de instruções.
func iniciar_jogo() -> void:
	if jogo_iniciado:
		return
	em_pre_contagem = false
	sessao_encerrada = false
	inicio_sessao = Time.get_datetime_dict_from_system()
	AudioManager.encerrar_pre_contagem()
	jogo_iniciado = true
	match modo_atual:
		ModoJogo.CALIBRACAO:
			AudioManager.volume_db = -40.0
			AudioManager.play()
		ModoJogo.BENCHMARK:
			InputManager.rodar_benchmark_latencia()
		_:
			AudioManager.play()


func _process(_delta: float) -> void:
	if em_pre_contagem:
		_processar_spawn_notas(AudioManager.tempo_atual_musica)
		return

	if modo_atual in [ModoJogo.GRAVACAO, ModoJogo.BENCHMARK] or not jogo_iniciado or sessao_encerrada:
		return

	var tempo_atual: float = AudioManager.tempo_atual_musica

	if modo_atual == ModoJogo.CALIBRACAO:
		_processar_calibracao(tempo_atual)
	else:
		_processar_spawn_notas(tempo_atual)

	_verificar_nota_perdida(tempo_atual)


func _processar_spawn_notas(tempo_atual: float) -> void:
	while indice_spawn < partitura.size():
		var nota_futura: Dictionary = partitura[indice_spawn]
		if tempo_atual >= (nota_futura["tempo"] - TEMPO_ANTECIPACAO):
			nota_deve_spawnar.emit(nota_futura)
			indice_spawn += 1
		else:
			break


## Dispara os cliques de calibração no instante exato, sem antecipação (não há nota visual viajando).
func _processar_calibracao(tempo_atual: float) -> void:
	while indice_spawn < partitura.size():
		var clique_futuro: Dictionary = partitura[indice_spawn]
		if tempo_atual >= clique_futuro["tempo"]:
			clique_calibracao.emit(clique_futuro["tempo"])
			indice_spawn += 1
		else:
			break


## Ponto de entrada chamado pelo InputManager quando uma tecla é capturada.
func registrar_batida(tipo: String, tempo: float) -> void:
	if not jogo_iniciado or sessao_encerrada:
		return
	match modo_atual:
		ModoJogo.AVALIACAO, ModoJogo.CALIBRACAO:
			_avaliar_precisao_ritmica(tipo, tempo)
		ModoJogo.GRAVACAO:
			_gravar_batida(tipo, tempo)


## Chamado pelo InputManager quando o usuário pede para encerrar a sessão.
func finalizar_sessao() -> void:
	if modo_atual == ModoJogo.GRAVACAO or modo_atual == ModoJogo.BENCHMARK:
		return
	if sessao_encerrada:
		return
	sessao_encerrada = true
	AudioManager.stop()
	_gerar_relatorio("Encerrada pelo participante (ESPAÇO/ENTER)")
	diagnostico_pronto.emit(_calcular_diagnostico())


## Chamado pelo InputManager quando o usuário pede para reiniciar a fase (tecla P).
func reiniciar_fase() -> void:
	if modo_atual == ModoJogo.GRAVACAO or modo_atual == ModoJogo.BENCHMARK or not jogo_iniciado:
		return
	indice_nota_atual = 0
	indice_spawn = 0
	historico_partida.clear()
	relatorio_salvo = false
	caminho_relatorio_sessao = ""
	sessao_encerrada = false
	inicio_sessao = Time.get_datetime_dict_from_system()
	AudioManager.reiniciar()
	fase_reiniciada.emit()


## Limpa o estado da sessao em andamento, para a proxima musica comecar do zero.
func resetar_sessao() -> void:
	AudioManager.stop()
	AudioManager.encerrar_pre_contagem()
	AudioManager.volume_db = 0.0
	em_pre_contagem = false
	sessao_encerrada = false
	jogo_iniciado = false
	indice_nota_atual = 0
	indice_spawn = 0
	historico_partida.clear()
	relatorio_salvo = false
	caminho_relatorio_sessao = ""


func _verificar_nota_perdida(tempo_atual: float) -> void:
	if indice_nota_atual >= partitura.size():
		return

	var nota_alvo: Dictionary = partitura[indice_nota_atual]
	var limite_ruim: float = nota_alvo["tempo"] + (LIMITE_RUIM_MS / 1000.0)

	if tempo_atual > limite_ruim:
		_registrar_omissao()


## Monta um registro do historico.
func _registro(ordem: int, tipo: String, desvio: int, classificacao: String, nota_ref: Dictionary, tipo_tocado: String, tempo_batida: float) -> Dictionary:
	return {
		"ordem_nota": ordem,
		"tipo": tipo,
		"desvio": desvio,
		"classificacao": classificacao,
		"esperado_s": nota_ref.get("tempo", -1.0),
		"batida_s": tempo_batida,
		"tipo_esperado": nota_ref.get("tipo", ""),
		"tipo_tocado": tipo_tocado,
	}


## Marca a nota atual como "nao tocada" e avanca para a proxima.
func _registrar_omissao() -> void:
	var nota_alvo: Dictionary = partitura[indice_nota_atual]
	var registro := _registro(indice_nota_atual, nota_alvo["tipo"], 999, "Miss (Omissao)", nota_alvo, "", -1.0)
	historico_partida.append(registro)
	nota_processada.emit(registro)
	indice_nota_atual += 1


## Procura qual nota a batida realmente acerta, olhando a nota atual e as seguintes.
func _encontrar_nota_da_batida(tipo_batida: String, tempo_batida: float) -> int:
	for j in range(indice_nota_atual, partitura.size()):
		var nota: Dictionary = partitura[j]
		var dt_ms: float = (tempo_batida - nota["tempo"]) * 1000.0
		var limite_ms: float = LIMITE_RUIM_MS if j == indice_nota_atual else LIMITE_BOM_MS
		if dt_ms < -limite_ms:
			break
		if absf(dt_ms) <= limite_ms and nota["tipo"] == tipo_batida:
			return j
	return -1


## Quantas vezes, na partida atual, a tecla apertada nao era a da nota.
func contar_teclas_erradas() -> int:
	var total := 0
	for registro in historico_partida:
		if registro["classificacao"] == "Tecla Errada":
			total += 1
	return total


## Calcula o desvio e = t_cli - t_esp e o classifica nas janelas de tolerância (Perfeito, Bom, Ruim e Miss).
func _avaliar_precisao_ritmica(tipo_batida: String, tempo_batida: float) -> void:
	if indice_nota_atual >= partitura.size():
		var registro_extra := _registro(-1, tipo_batida, 0, "Batida Extra", {}, tipo_batida, tempo_batida)
		historico_partida.append(registro_extra)
		nota_processada.emit(registro_extra)
		return

	var nota_esperada: Dictionary = partitura[indice_nota_atual]
	## e = t_cli − t_esp
	var erro_temporal: float = tempo_batida - nota_esperada["tempo"]
	var erro_ms: int = int(erro_temporal * 1000.0)
	var abs_erro_ms: int = abs(erro_ms)

	if erro_ms < LIMITE_REPETICAO_MS:
		var registro_spam := _registro(-1, tipo_batida, erro_ms, "Erro de Repeticao", nota_esperada, tipo_batida, tempo_batida)
		historico_partida.append(registro_spam)
		nota_processada.emit(registro_spam)
		return

	var alvo := indice_nota_atual
	if modo_atual != ModoJogo.CALIBRACAO:
		alvo = _encontrar_nota_da_batida(tipo_batida, tempo_batida)
		if alvo == -1:
			var registro_errado := _registro(-1, tipo_batida, erro_ms, "Tecla Errada", nota_esperada, tipo_batida, tempo_batida)
			historico_partida.append(registro_errado)
			nota_processada.emit(registro_errado)
			return

		while indice_nota_atual < alvo:
			_registrar_omissao()
		nota_esperada = partitura[indice_nota_atual]
		erro_ms = int((tempo_batida - nota_esperada["tempo"]) * 1000.0)
		abs_erro_ms = abs(erro_ms)

	var classificacao := _classificar_desvio(abs_erro_ms)

	var registro := _registro(indice_nota_atual, nota_esperada["tipo"], erro_ms, classificacao, nota_esperada, tipo_batida, tempo_batida)
	indice_nota_atual += 1
	historico_partida.append(registro)
	nota_processada.emit(registro)


func _classificar_desvio(abs_erro_ms: int) -> String:
	if abs_erro_ms <= LIMITE_PERFEITO_MS:
		return "Perfeito"
	elif abs_erro_ms <= LIMITE_BOM_MS:
		return "Bom"
	elif abs_erro_ms <= LIMITE_RUIM_MS:
		return "Ruim"
	return "Miss"


## Acumula a batida em memória (gravacao_atual); só é gravada em disco quando salvar_gravacao() é chamado.
func _gravar_batida(tipo_batida: String, tempo_batida: float) -> void:
	gravacao_atual.append({"tempo": tempo_batida, "tipo": tipo_batida})


func _carregar_partitura() -> void:
	partitura.clear()
	var caminho := CAMINHO_PARTITURA
	if pasta_musica_selecionada != "":
		caminho = pasta_musica_selecionada.path_join("partitura.txt")

	if not FileAccess.file_exists(caminho):
		push_warning("Partitura nao encontrada em: " + caminho)
		return

	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	while not arquivo.eof_reached():
		var linha := arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		if linha.ends_with(","):
			linha = linha.substr(0, linha.length() - 1)
		var dados = JSON.parse_string(linha)
		if typeof(dados) == TYPE_DICTIONARY:
			partitura.append(dados)
	arquivo.close()

	partitura.sort_custom(func(a, b): return a["tempo"] < b["tempo"])
	print("Partitura carregada. Total de notas: ", partitura.size())


## Gera uma partitura sintética com cliques igualmente espaçados, usada no modo CALIBRACAO.
func _gerar_partitura_calibracao() -> void:
	partitura.clear()
	for i in QUANTIDADE_CLIQUES_CALIBRACAO:
		partitura.append({
			"tempo": TEMPO_ANTECIPACAO + i * INTERVALO_CALIBRACAO,
			"tipo": "Clique"
		})


## Lê metadata.json de uma pasta de música.
func _ler_metadata(pasta: String) -> Dictionary:
	var caminho := pasta.path_join("metadata.json")
	if not FileAccess.file_exists(caminho):
		return {}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	var conteudo := arquivo.get_as_text()
	arquivo.close()
	var dados = JSON.parse_string(conteudo)
	if typeof(dados) == TYPE_DICTIONARY:
		return dados
	return {}


## Converte um texto livre num identificador seguro para nome de arquivo ou pasta.
func _sanitizar_slug(texto: String) -> String:
	var bruto := texto.to_lower().strip_edges().replace(" ", "_")
	var slug := ""
	for c in bruto:
		if c in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			slug += c
	if slug == "":
		slug = "musica"
	return slug


## Gera o identificador de uma música nova, acrescentando um sufixo numérico se a pasta já existir.
func _gerar_slug(nome: String) -> String:
	var slug := _sanitizar_slug(nome)
	var candidato := slug
	var contador := 2
	while DirAccess.dir_exists_absolute(pasta_musicas.path_join(candidato)) or DirAccess.dir_exists_absolute(PASTA_MUSICAS_PADRAO.path_join(candidato)):
		candidato = "%s_%d" % [slug, contador]
		contador += 1
	return candidato


## Varre as músicas gravadas e as de exemplo embutidas no .pck, e devolve os metadados de cada uma.
func listar_musicas_salvas() -> Array:
	var lista: Array = []
	_listar_musicas_em(PASTA_MUSICAS_PADRAO, lista)
	_listar_musicas_em(pasta_musicas, lista)
	return lista


func _listar_musicas_em(pasta_base: String, lista: Array) -> void:
	var dir := DirAccess.open(pasta_base)
	if dir == null:
		return

	dir.list_dir_begin()
	var nome_pasta := dir.get_next()
	while nome_pasta != "":
		if dir.current_is_dir() and not nome_pasta.begins_with("."):
			var caminho_completo := pasta_base.path_join(nome_pasta)
			var meta := _ler_metadata(caminho_completo)
			if not meta.is_empty():
				lista.append({
					"pasta": caminho_completo,
					"nome": meta.get("nome", nome_pasta),
					"criado_em": meta.get("criado_em", ""),
				})
		nome_pasta = dir.get_next()
	dir.list_dir_end()


## Chamado pela tela de seleção quando o pesquisador escolhe uma música da biblioteca.
func selecionar_musica(pasta: String) -> bool:
	var meta := _ler_metadata(pasta)
	if meta.is_empty():
		push_error("Metadados nao encontrados/invalidos em: " + pasta)
		return false

	var nome_arquivo_audio: String = meta.get("audio_arquivo", "audio.mp3")
	var caminho_audio: String = pasta.path_join(nome_arquivo_audio)
	if not AudioManager.carregar_stream_dinamico(caminho_audio):
		return false

	pasta_musica_selecionada = pasta
	nome_musica_selecionada = meta.get("nome", "")
	modo_atual = ModoJogo.AVALIACAO
	jogo_iniciado = false
	sessao_encerrada = false
	indice_nota_atual = 0
	indice_spawn = 0
	historico_partida.clear()
	relatorio_salvo = false
	caminho_relatorio_sessao = ""
	_carregar_partitura()
	return true


## Chamado pela tela de gravação ao apertar "Gravar".
func iniciar_gravacao() -> void:
	modo_atual = ModoJogo.GRAVACAO
	gravacao_atual.clear()
	jogo_iniciado = true
	AudioManager.play()


## Para a gravação sem descartar o que foi capturado; a tela de gravação decide se salva ou descarta.
func parar_gravacao() -> void:
	jogo_iniciado = false
	AudioManager.stop()


## Salva a gravação atual como música nova: copia o áudio, escreve a partitura e um metadata.json com o nome escolhido.
func salvar_gravacao(nome: String, caminho_audio_origem: String) -> bool:
	if gravacao_atual.is_empty():
		push_error("Nao ha batidas gravadas para salvar.")
		return false
	if not FileAccess.file_exists(caminho_audio_origem):
		push_error("Arquivo de audio original nao encontrado: " + caminho_audio_origem)
		return false

	var slug := _gerar_slug(nome)
	var pasta := pasta_musicas.path_join(slug)
	DirAccess.make_dir_recursive_absolute(pasta)

	var audio_origem := FileAccess.open(caminho_audio_origem, FileAccess.READ)
	if not audio_origem:
		push_error("Nao foi possivel abrir o audio original: " + caminho_audio_origem)
		return false
	var bytes := audio_origem.get_buffer(audio_origem.get_length())
	audio_origem.close()

	var extensao := caminho_audio_origem.get_extension().to_lower()
	var nome_arquivo_audio := "audio." + extensao
	var audio_destino := FileAccess.open(pasta.path_join(nome_arquivo_audio), FileAccess.WRITE)
	if not audio_destino:
		push_error("Nao foi possivel salvar o audio em: " + pasta)
		return false
	audio_destino.store_buffer(bytes)
	audio_destino.close()

	var batidas_ordenadas: Array = gravacao_atual.duplicate()
	batidas_ordenadas.sort_custom(func(a, b): return a["tempo"] < b["tempo"])
	var partitura_arquivo := FileAccess.open(pasta.path_join("partitura.txt"), FileAccess.WRITE)
	for batida in batidas_ordenadas:
		partitura_arquivo.store_line('\t{"tempo": %f, "tipo": "%s"},' % [batida["tempo"], batida["tipo"]])
	partitura_arquivo.close()

	var metadata := {
		"nome": nome,
		"criado_em": Time.get_datetime_string_from_system(),
		"audio_arquivo": nome_arquivo_audio,
	}
	var metadata_arquivo := FileAccess.open(pasta.path_join("metadata.json"), FileAccess.WRITE)
	metadata_arquivo.store_string(JSON.stringify(metadata, "\t"))
	metadata_arquivo.close()

	print("Musica salva em: ", ProjectSettings.globalize_path(pasta))
	return true


func _on_benchmark_concluido(latencias_us: Array) -> void:
	var estatisticas := _calcular_estatisticas_benchmark(latencias_us)
	_gerar_relatorio_benchmark(latencias_us, estatisticas)
	benchmark_pronto.emit(estatisticas)


func _calcular_estatisticas_benchmark(latencias_us: Array) -> Dictionary:
	if latencias_us.is_empty():
		return {}

	var soma := 0
	var minimo: int = latencias_us[0]
	var maximo: int = latencias_us[0]
	for valor in latencias_us:
		soma += valor
		minimo = min(minimo, valor)
		maximo = max(maximo, valor)
	var media_us: float = soma / float(latencias_us.size())

	var ordenados: Array = latencias_us.duplicate()
	ordenados.sort()
	var mediana_us: float = ordenados[ordenados.size() / 2]

	var soma_quadrados := 0.0
	for valor in latencias_us:
		soma_quadrados += pow(valor - media_us, 2)
	var desvio_padrao_us: float = sqrt(soma_quadrados / latencias_us.size())

	return {
		"amostras": latencias_us.size(),
		"media_ms": media_us / 1000.0,
		"mediana_ms": mediana_us / 1000.0,
		"minima_ms": minimo / 1000.0,
		"maxima_ms": maximo / 1000.0,
		"desvio_padrao_ms": desvio_padrao_us / 1000.0,
	}


func _gerar_relatorio_benchmark(latencias_us: Array, estatisticas: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(pasta_relatorios)
	var carimbo := Time.get_datetime_string_from_system().replace(":", "-")
	var caminho := pasta_relatorios + "benchmark_latencia_%s.txt" % carimbo
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if not arquivo:
		push_error("Nao foi possivel salvar o benchmark em: " + caminho)
		return

	arquivo.store_line("Amostra,Latencia (ms)")
	for i in latencias_us.size():
		arquivo.store_line("%d,%.3f" % [i + 1, latencias_us[i] / 1000.0])

	if not estatisticas.is_empty():
		arquivo.store_line("")
		arquivo.store_line("Media (ms),%.3f" % estatisticas["media_ms"])
		arquivo.store_line("Mediana (ms),%.3f" % estatisticas["mediana_ms"])
		arquivo.store_line("Minima (ms),%.3f" % estatisticas["minima_ms"])
		arquivo.store_line("Maxima (ms),%.3f" % estatisticas["maxima_ms"])
		arquivo.store_line("Desvio Padrao (ms),%.3f" % estatisticas["desvio_padrao_ms"])

	arquivo.close()
	print("Benchmark salvo em: ", ProjectSettings.globalize_path(caminho))


## Grava os dois arquivos do relatorio da sessao: um .txt para ler e um .csv para analisar, com o mesmo nome-base.
func _gerar_relatorio(motivo_fim: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta_relatorios)
	var data: Dictionary = inicio_sessao if not inicio_sessao.is_empty() else Time.get_datetime_dict_from_system()
	if caminho_relatorio_sessao == "":
		var carimbo := "%04d-%02d-%02d_%02d-%02d-%02d" % [data["year"], data["month"], data["day"], data["hour"], data["minute"], data["second"]]
		var base := "relatorio_calibracao" if modo_atual == ModoJogo.CALIBRACAO else "relatorio"
		if modo_atual == ModoJogo.AVALIACAO and pasta_musica_selecionada != "":
			base += "_" + _sanitizar_slug(pasta_musica_selecionada.trim_suffix("/").get_file())
		caminho_relatorio_sessao = pasta_relatorios + "%s_%s" % [base, carimbo]
	var contexto := _montar_contexto_relatorio(motivo_fim, data)
	var gravou_txt := _gravar_texto_utf8(caminho_relatorio_sessao + ".txt", Relatorio.montar_texto(contexto))
	var gravou_csv := _gravar_texto_utf8(caminho_relatorio_sessao + ".csv", Relatorio.montar_csv(contexto))
	if gravou_txt or gravou_csv:
		relatorio_salvo = true
		print("Relatorio salvo em: ", ProjectSettings.globalize_path(caminho_relatorio_sessao), ".txt / .csv")


## Junta o que o relatorio precisa saber (sessao, sistema de audio, preferencias) num dicionario; o Relatorio so formata.
func _montar_contexto_relatorio(motivo_fim: String, data: Dictionary) -> Dictionary:
	var calibracao := modo_atual == ModoJogo.CALIBRACAO
	var nome_musica := "Teste de latência (cliques)"
	var pasta_musica := ""
	var duracao := 0.0
	if not calibracao:
		nome_musica = nome_musica_selecionada if nome_musica_selecionada != "" else "(música padrão)"
		pasta_musica = pasta_musica_selecionada.trim_suffix("/").get_file()
		if AudioManager.stream != null:
			duracao = AudioManager.stream.get_length()
	return {
		"sessao": caminho_relatorio_sessao.get_file(),
		"modo": "Calibração" if calibracao else "Avaliação",
		"musica_nome": nome_musica,
		"musica_pasta": pasta_musica,
		"data": data,
		"motivo_fim": motivo_fim,
		"duracao_musica_s": duracao,
		"tempo_tocado_s": maxf(AudioManager.tempo_atual_musica, 0.0),
		"total_notas": partitura.size(),
		"historico": historico_partida,
		"limites_ms": {
			"perfeito": LIMITE_PERFEITO_MS, "bom": LIMITE_BOM_MS,
			"ruim": LIMITE_RUIM_MS, "tendencia": LIMITE_TENDENCIA_MS,
		},
		"sistema": {
			"so": OS.get_name() + " " + OS.get_version_alias(),
			"motor": "Godot " + str(Engine.get_version_info()["string"]),
			"dispositivo_audio": AudioServer.output_device,
			"taxa_amostragem": AudioServer.get_mix_rate(),
			"latencia_saida_ms": AudioServer.get_output_latency() * 1000.0,
			"fps": Engine.get_frames_per_second(),
		},
		"config": {
			"volume_musica": volume_musica * 100.0,
			"volume_batidas": volume_batidas * 100.0,
			"estilo_mao": "Metade pintada" if estilo_mao == EstiloMao.METADE else "Letras (L/R)",
		},
	}


## Grava texto em UTF-8 com BOM, para o Bloco de Notas e o Excel reconhecerem os acentos.
func _gravar_texto_utf8(caminho: String, texto: String) -> bool:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if not arquivo:
		push_error("Nao foi possivel salvar o relatorio em: " + caminho)
		return false
	arquivo.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	arquivo.store_string(texto)
	arquivo.close()
	return true


## Calcula o MAE e a tendência motora (média com sinal dos desvios).
func _calcular_diagnostico() -> Dictionary:
	var total_notas := 0
	var soma_com_sinal := 0
	var soma_absoluta := 0
	var acertos_validos := 0

	for dado in historico_partida:
		if dado["ordem_nota"] != -1 and dado["desvio"] != 999:
			total_notas += 1
			soma_com_sinal += dado["desvio"]
			soma_absoluta += abs(dado["desvio"])
			if dado["classificacao"] in ["Perfeito", "Bom"]:
				acertos_validos += 1

	if total_notas == 0:
		return {}

	return {
		"precisao": (acertos_validos / float(total_notas)) * 100.0,
		"mae": soma_absoluta / float(total_notas),
		"tendencia": soma_com_sinal / float(total_notas)
	}
