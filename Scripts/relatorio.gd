extends RefCounted
## Relatório de uma sessão de treino/calibração.
## Só MONTA texto a partir de dados puros; quem junta os dados e grava é o GameManager.

const LARGURA := 70

const TIPOS_NOTA := ["Direita", "Esquerda", "Dir_Borda", "Esquerda_Borda"]

const NOME_TECLA := {
	"Direita": "J (Don, direita)",
	"Esquerda": "F (Kon, esquerda)",
	"Dir_Borda": "U (Ka, direita)",
	"Esquerda_Borda": "R (Ra, esquerda)",
	"Clique": "qualquer tecla",
}

const NOME_RESULTADO := {
	"Perfeito": "Perfeito",
	"Bom": "Bom",
	"Ruim": "Ruim",
	"Miss": "Miss",
	"Miss (Omissao)": "Nota não tocada",
	"Tecla Errada": "Tecla errada",
	"Erro de Repeticao": "Cedo demais (repetição)",
	"Batida Extra": "Batida extra",
}

const CSV_RESULTADO := {
	"Perfeito": "Perfeito",
	"Bom": "Bom",
	"Ruim": "Ruim",
	"Miss": "Miss",
	"Miss (Omissao)": "Nao_tocada",
	"Tecla Errada": "Tecla_errada",
	"Erro de Repeticao": "Repeticao",
	"Batida Extra": "Extra",
}


## Contagens e estatísticas da sessão a partir do histórico.
static func calcular_resumo(historico: Array, total_notas: int) -> Dictionary:
	var r := {
		"perfeito": 0, "bom": 0, "ruim": 0, "miss": 0, "omitidas": 0,
		"teclas_erradas": 0, "repeticoes": 0, "extras": 0,
		"tocadas": 0, "avaliadas": 0, "total_notas": total_notas,
		"precisao": 0.0, "acerto_geral": 0.0,
		"mae": 0.0, "tendencia": 0.0, "desvio_padrao": 0.0,
		"maior_sequencia": 0, "por_tipo": {},
	}
	var por_tipo: Dictionary = r["por_tipo"]
	for tipo in TIPOS_NOTA:
		por_tipo[tipo] = {"avaliadas": 0, "acertos": 0, "tocadas": 0, "soma": 0.0, "soma_abs": 0.0}

	var desvios: Array = []
	var sequencia := 0
	for reg in historico:
		var c: String = reg["classificacao"]
		match c:
			"Perfeito": r["perfeito"] += 1
			"Bom": r["bom"] += 1
			"Ruim": r["ruim"] += 1
			"Miss": r["miss"] += 1
			"Miss (Omissao)": r["omitidas"] += 1
			"Tecla Errada": r["teclas_erradas"] += 1
			"Erro de Repeticao": r["repeticoes"] += 1
			"Batida Extra": r["extras"] += 1

		var acerto := c == "Perfeito" or c == "Bom"
		if acerto:
			sequencia += 1
			r["maior_sequencia"] = maxi(r["maior_sequencia"], sequencia)
		elif c in ["Ruim", "Miss", "Miss (Omissao)", "Tecla Errada"]:
			sequencia = 0

		if int(reg["ordem_nota"]) < 0:
			continue
		r["avaliadas"] += 1
		var tocada: bool = int(reg["desvio"]) != 999
		var tipo: String = reg.get("tipo_esperado", reg["tipo"])
		var pt: Dictionary = por_tipo.get(tipo, {})
		if not pt.is_empty():
			pt["avaliadas"] += 1
			if acerto:
				pt["acertos"] += 1
		if tocada:
			r["tocadas"] += 1
			var d := float(reg["desvio"])
			desvios.append(d)
			if not pt.is_empty():
				pt["tocadas"] += 1
				pt["soma"] += d
				pt["soma_abs"] += absf(d)

	if not desvios.is_empty():
		var soma := 0.0
		var soma_abs := 0.0
		for d in desvios:
			soma += d
			soma_abs += absf(d)
		var n := float(desvios.size())
		var media := soma / n
		var soma_q := 0.0
		for d in desvios:
			soma_q += (d - media) * (d - media)
		r["tendencia"] = media
		r["mae"] = soma_abs / n
		r["desvio_padrao"] = sqrt(soma_q / n)
		r["precisao"] = float(r["perfeito"] + r["bom"]) / n * 100.0
	if int(r["avaliadas"]) > 0:
		r["acerto_geral"] = float(r["perfeito"] + r["bom"]) / float(r["avaliadas"]) * 100.0
	return r


static func _virgula(s: String) -> String:
	return s.replace(".", ",")


static func _pct(x: float) -> String:
	return _virgula("%.1f" % x) + "%"


static func _ms(x: float) -> String:
	return "%d ms" % int(roundf(x))


static func _ms_sinal(x: float) -> String:
	return "%+d ms" % int(roundf(x))


static func _duracao(segundos: float) -> String:
	var total := int(roundf(maxf(segundos, 0.0)))
	return "%d min %02d s" % [int(total / 60.0), total % 60]


static func _data_br(d: Dictionary) -> String:
	return "%02d/%02d/%04d %02d:%02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"], d["second"]]


static func _data_iso(d: Dictionary) -> String:
	return "%04d-%02d-%02d %02d:%02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]


## "  Rótulo ........ valor" -- o valor sempre começa na mesma coluna.
static func _linha(rotulo: String, valor: String, extra: String = "") -> String:
	var pontos := maxi(3, 36 - rotulo.length())
	var s := "  " + rotulo + " " + ".".repeat(pontos) + " " + valor
	if extra != "":
		s += "   " + extra
	return s


static func _tecla(tipo: String) -> String:
	return NOME_TECLA.get(tipo, "-" if tipo == "" else tipo)


static func _interpretar_tendencia(t: float, limite: float) -> String:
	if t < -limite:
		return "adiantando (aperta antes da hora)"
	if t > limite:
		return "atrasando (aperta depois da hora)"
	return "consistente (dentro de ±%d ms)" % int(limite)


static func montar_texto(ctx: Dictionary) -> String:
	var res := calcular_resumo(ctx["historico"], int(ctx["total_notas"]))
	var lim: Dictionary = ctx["limites_ms"]
	var sis: Dictionary = ctx["sistema"]
	var cfg: Dictionary = ctx["config"]
	var barra := "=".repeat(LARGURA)
	var fino := "-".repeat(LARGURA)
	var L: Array[String] = []

	L.append("RELATÓRIO DE TREINO - TAIKO")
	L.append(barra)
	L.append("")
	L.append("SESSÃO")
	L.append(_linha("Música", ctx["musica_nome"]))
	L.append(_linha("Data e hora", _data_br(ctx["data"])))
	L.append(_linha("Modo", ctx["modo"]))
	L.append(_linha("Como terminou", ctx["motivo_fim"]))
	var duracao: float = ctx["duracao_musica_s"]
	var tocado: float = ctx["tempo_tocado_s"]
	if duracao > 0.0:
		L.append(_linha("Música tocada", "%s de %s" % [_duracao(tocado), _duracao(duracao)], "(%d%%)" % int(roundf(clampf(tocado / duracao, 0.0, 1.0) * 100.0))))
	L.append(_linha("Notas na partitura", str(res["total_notas"]), "(avaliadas: %d)" % res["avaliadas"]))
	L.append("")

	L.append("RESULTADO")
	L.append(fino)
	if int(res["tocadas"]) == 0:
		L.append("  Nenhuma batida válida foi registrada, então não há resumo estatístico.")
		if int(res["teclas_erradas"]) > 0:
			L.append("  Teclas erradas: %d (confira a mão e o centro/borda de cada nota)." % res["teclas_erradas"])
	else:
		L.append(_linha("Precisão de acertos", _pct(res["precisao"]), "Perfeito + Bom entre as notas tocadas (%d de %d)" % [res["perfeito"] + res["bom"], res["tocadas"]]))
		L.append(_linha("Acerto geral", _pct(res["acerto_geral"]), "Perfeito + Bom entre todas as avaliadas (%d de %d)" % [res["perfeito"] + res["bom"], res["avaliadas"]]))
		L.append(_linha("Erro de precisão", _ms(res["mae"]), "média da distância ao instante certo"))
		L.append(_linha("Tendência", _ms_sinal(res["tendencia"]), _interpretar_tendencia(res["tendencia"], float(lim["tendencia"]))))
		L.append(_linha("Desvio padrão", _ms(res["desvio_padrao"]), "quanto o erro varia de uma nota para outra"))
		L.append(_linha("Maior sequência de acertos", str(res["maior_sequencia"])))
	L.append("")

	L.append("CLASSIFICAÇÃO")
	L.append(fino)
	var av: int = maxi(int(res["avaliadas"]), 1)
	var miss_total: int = int(res["miss"]) + int(res["omitidas"])
	L.append(_linha("Perfeito (até %d ms)" % lim["perfeito"], "%4d" % res["perfeito"], _pct(res["perfeito"] * 100.0 / av)))
	L.append(_linha("Bom (até %d ms)" % lim["bom"], "%4d" % res["bom"], _pct(res["bom"] * 100.0 / av)))
	L.append(_linha("Ruim (até %d ms)" % lim["ruim"], "%4d" % res["ruim"], _pct(res["ruim"] * 100.0 / av)))
	L.append(_linha("Miss (nota não tocada)", "%4d" % miss_total, _pct(miss_total * 100.0 / av)))
	L.append(_linha("Tecla errada", "%4d" % res["teclas_erradas"], "tecla diferente da pedida pela nota"))
	L.append(_linha("Cedo demais / batida extra", "%4d" % (int(res["repeticoes"]) + int(res["extras"])), "apertou sem ter nota para tocar"))
	L.append("")

	if ctx["modo"] != "Calibração":
		L.append("POR TIPO DE NOTA")
		L.append(fino)
		L.append("  " + "Tecla".rpad(20) + "Notas".lpad(7) + "Acertos".lpad(9) + "Erro médio".lpad(13) + "Tendência".lpad(12))
		for tipo in TIPOS_NOTA:
			var pt: Dictionary = res["por_tipo"][tipo]
			var erro := "-"
			var tend := "-"
			if int(pt["tocadas"]) > 0:
				erro = _ms(float(pt["soma_abs"]) / float(pt["tocadas"]))
				tend = _ms_sinal(float(pt["soma"]) / float(pt["tocadas"]))
			L.append("  " + _tecla(tipo).rpad(20) + str(pt["avaliadas"]).lpad(7) + str(pt["acertos"]).lpad(9) + erro.lpad(13) + tend.lpad(12))
		L.append("")

	L.append("SISTEMA")
	L.append(fino)
	L.append(_linha("Sistema operacional", sis["so"]))
	L.append(_linha("Motor", sis["motor"]))
	L.append(_linha("Dispositivo de áudio", sis["dispositivo_audio"]))
	L.append(_linha("Taxa de amostragem", "%d Hz" % int(sis["taxa_amostragem"])))
	L.append(_linha("Latência de saída de áudio", _virgula("%.1f" % sis["latencia_saida_ms"]) + " ms", "informada pelo sistema; descontada do relógio"))
	L.append(_linha("Quadros por segundo", str(int(sis["fps"]))))
	L.append(_linha("Volume música / batidas", "%d%% / %d%%" % [int(cfg["volume_musica"]), int(cfg["volume_batidas"])]))
	L.append(_linha("Mão nas notas", cfg["estilo_mao"]))
	L.append("")

	L.append("DETALHE POR EVENTO")
	L.append(fino)
	L.append("  " + "Ev".lpad(4) + "Nota".lpad(6) + "Esperado".lpad(11) + "Batida".lpad(10) + "  " + "Tecla esperada".rpad(19) + "Tecla tocada".rpad(19) + "Desvio".lpad(9) + "  Resultado")
	var n := 0
	for reg in ctx["historico"]:
		n += 1
		var ordem := int(reg["ordem_nota"])
		var esp: float = reg.get("esperado_s", -1.0)
		var bat: float = reg.get("batida_s", -1.0)
		var desvio_txt := "-"
		if int(reg["desvio"]) != 999 and reg["classificacao"] != "Batida Extra":
			desvio_txt = "%+d ms" % int(reg["desvio"])
		var nota_txt := str(ordem + 1) if ordem >= 0 else "-"
		L.append("  " + str(n).lpad(4) + nota_txt.lpad(6)
			+ (_virgula("%.3f" % esp) + " s" if esp >= 0.0 else "-").lpad(11)
			+ (_virgula("%.3f" % bat) + " s" if bat >= 0.0 else "-").lpad(10)
			+ "  " + _tecla(reg.get("tipo_esperado", "")).rpad(19) + _tecla(reg.get("tipo_tocado", "")).rpad(19)
			+ desvio_txt.lpad(9) + "  " + NOME_RESULTADO.get(reg["classificacao"], reg["classificacao"]))
	L.append("")
	L.append("Como ler: desvio negativo = a batida veio ANTES do instante certo; positivo =")
	L.append("DEPOIS. Tecla errada, cedo demais e batida extra não contam como acerto e não")
	L.append("entram no erro de precisão nem na tendência.")
	return "\n".join(L) + "\n"


static func _csv_ms(segundos: float) -> String:
	return "" if segundos < 0.0 else str(int(roundf(segundos * 1000.0)))


static func _csv_campo(s: String) -> String:
	return s.replace(";", ",").replace("\n", " ")


## Uma linha por evento, separador ";" (abre direto no Excel em português) e tempos em milissegundos inteiros.
static func montar_csv(ctx: Dictionary) -> String:
	var cab := ["sessao", "musica", "pasta_musica", "data_hora", "modo", "evento", "nota", "esperado_ms", "batida_ms", "tecla_esperada", "tecla_tocada", "desvio_ms", "resultado"]
	var L: Array[String] = [";".join(cab)]
	var n := 0
	for reg in ctx["historico"]:
		n += 1
		var ordem := int(reg["ordem_nota"])
		var desvio := ""
		if int(reg["desvio"]) != 999 and reg["classificacao"] != "Batida Extra":
			desvio = str(int(reg["desvio"]))
		var campos := [
			_csv_campo(ctx["sessao"]),
			_csv_campo(ctx["musica_nome"]),
			_csv_campo(ctx["musica_pasta"]),
			_data_iso(ctx["data"]),
			_csv_campo(ctx["modo"]),
			str(n),
			str(ordem + 1) if ordem >= 0 else "",
			_csv_ms(reg.get("esperado_s", -1.0)),
			_csv_ms(reg.get("batida_s", -1.0)),
			reg.get("tipo_esperado", ""),
			reg.get("tipo_tocado", ""),
			desvio,
			CSV_RESULTADO.get(reg["classificacao"], reg["classificacao"]),
		]
		L.append(";".join(campos))
	return "\n".join(L) + "\n"
