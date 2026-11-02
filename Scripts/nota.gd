extends Node2D

const VELOCIDADE: float = 433.3
var x_zona_de_acerto: float = 275.0

const RAIO_CENTRO: float = 26.0
const RAIO_BORDA: float = 40.0
const COR_CONTORNO: Color = Color.WHITE
const COR_METADE_VAZIA: Color = Color(0.07058824, 0.07058824, 0.08627451, 1)

var tempo_alvo: float = 0.0
var cor: Color = Color.RED
var raio: float = RAIO_CENTRO
var letra: String = ""

func configurar(dados_nota: Dictionary) -> void:
	tempo_alvo = dados_nota["tempo"]
	var tipo = dados_nota["tipo"]

	if tipo == "Direita" or tipo == "Esquerda":
		cor = Color.RED
		raio = RAIO_CENTRO
	elif tipo == "Dir_Borda" or tipo == "Esquerda_Borda":
		cor = Color.BLUE
		raio = RAIO_BORDA

	if tipo == "Direita" or tipo == "Dir_Borda":
		letra = "R"
	elif tipo == "Esquerda" or tipo == "Esquerda_Borda":
		letra = "L"
	else:
		letra = ""

	_atualizar_posicao()
	queue_redraw()

func _process(_delta: float) -> void:
	_atualizar_posicao()

	if position.x < -100:
		queue_free()

## Deriva a posição X do relógio de áudio (o mesmo usado para julgar a batida), e não do acúmulo do delta de quadro.
func _atualizar_posicao() -> void:
	position.x = x_zona_de_acerto + (tempo_alvo - AudioManager.tempo_atual_musica) * VELOCIDADE

func _draw() -> void:
	desenhar(self, raio, cor, letra, GameManager.estilo_mao)


## Desenha uma nota centrada em (0,0), usada pela própria nota e pela prévia da tela Configurações.
static func desenhar(canvas: CanvasItem, raio_nota: float, cor_nota: Color, mao: String, estilo: int) -> void:
	canvas.draw_circle(Vector2.ZERO, raio_nota + 3.0, COR_CONTORNO)
	if estilo == GameManager.EstiloMao.METADE and mao != "":
		canvas.draw_circle(Vector2.ZERO, raio_nota, COR_METADE_VAZIA)
		_desenhar_metade(canvas, raio_nota, cor_nota, mao == "R")
		canvas.draw_line(Vector2(0, -raio_nota), Vector2(0, raio_nota), COR_CONTORNO, 2.0)
	else:
		canvas.draw_circle(Vector2.ZERO, raio_nota, cor_nota)
		_desenhar_letra(canvas, raio_nota, mao)


## Metade do disco: direita = de -90 a +90 graus; esquerda = de +90 a +270.
static func _desenhar_metade(canvas: CanvasItem, raio_nota: float, cor_nota: Color, direita: bool) -> void:
	var pontos := PackedVector2Array()
	var inicio := -PI / 2.0 if direita else PI / 2.0
	var passos := 32
	for i in range(passos + 1):
		var angulo := inicio + PI * float(i) / float(passos)
		pontos.append(Vector2(cos(angulo), sin(angulo)) * raio_nota)
	canvas.draw_colored_polygon(pontos, cor_nota)


## Escreve L/R no centro do circulo usando a fonte padrao do motor.
static func _desenhar_letra(canvas: CanvasItem, raio_nota: float, mao: String) -> void:
	if mao == "":
		return
	var fonte := ThemeDB.fallback_font
	var tamanho_fonte := int(raio_nota * 1.1)
	canvas.draw_string(
		fonte, Vector2(-raio_nota, tamanho_fonte * 0.35), mao,
		HORIZONTAL_ALIGNMENT_CENTER, raio_nota * 2.0, tamanho_fonte, COR_CONTORNO
	)
