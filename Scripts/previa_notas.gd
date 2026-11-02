extends Control
## Prévia das quatro notas (Don, Kon, Ka e Ra) no estilo escolhido na tela Configurações, desenhada com a mesma função da nota real.

const NotaScript := preload("res://Scripts/nota.gd")


func _amostras() -> Array:
	return [
		{"tecla": "J", "nome": "Don (centro) - mão direita", "mao": "R", "raio": NotaScript.RAIO_CENTRO, "cor": Color.RED},
		{"tecla": "F", "nome": "Kon (centro) - mão esquerda", "mao": "L", "raio": NotaScript.RAIO_CENTRO, "cor": Color.RED},
		{"tecla": "U", "nome": "Ka (borda) - mão direita", "mao": "R", "raio": NotaScript.RAIO_BORDA, "cor": Color.BLUE},
		{"tecla": "R", "nome": "Ra (borda) - mão esquerda", "mao": "L", "raio": NotaScript.RAIO_BORDA, "cor": Color.BLUE},
	]


func _draw() -> void:
	var fonte := ThemeDB.fallback_font
	var amostras := _amostras()
	var largura := size.x / amostras.size()
	for i in amostras.size():
		var a: Dictionary = amostras[i]
		var centro_x := largura * (i + 0.5)
		draw_set_transform(Vector2(centro_x, 48.0), 0.0, Vector2.ONE)
		NotaScript.desenhar(self, a["raio"], a["cor"], a["mao"], GameManager.estilo_mao)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(fonte, Vector2(centro_x - largura / 2.0, 114.0), "Tecla " + a["tecla"], HORIZONTAL_ALIGNMENT_CENTER, largura, 22)
		draw_string(fonte, Vector2(centro_x - largura / 2.0, 140.0), a["nome"], HORIZONTAL_ALIGNMENT_CENTER, largura, 15, Color(0.8, 0.8, 0.85))
