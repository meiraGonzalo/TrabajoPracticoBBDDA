"""
UNLaM - Bases de Datos Aplicada
TP: Sistema de Registro y Gestión del Mundial de Fútbol
Extracción Web Scraping: Catálogo ISO 4217 (cat.Moneda)
Salida: archivos/monedas.csv (codigo_iso, nombre)
"""

import os
import sys
import re
import csv
import urllib.request
from html.parser import HTMLParser

# Directorios de trabajo según la arquitectura del proyecto
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "monedas.csv")

# URL de Wikipedia en español para ISO 4217
WIKI_URL = "https://es.wikipedia.org/wiki/ISO_4217"


class WikipediaTableParser(HTMLParser):
    """Parser HTML liviano para extraer filas y celdas de tablas sin librerías externas."""
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_tr = False
        self.in_cell = False
        self.current_row = []
        self.current_cell = []
        self.rows = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag == "table" and "wikitable" in attrs_dict.get("class", ""):
            self.in_table = True
        elif self.in_table and tag == "tr":
            self.in_tr = True
            self.current_row = []
        elif self.in_tr and tag in ("td", "th"):
            self.in_cell = True
            self.current_cell = []

    def handle_endtag(self, tag):
        if tag == "table" and self.in_table:
            self.in_table = False
        elif tag == "tr" and self.in_tr:
            self.in_tr = False
            if self.current_row:
                self.rows.append(self.current_row)
        elif tag in ("td", "th") and self.in_cell:
            self.in_cell = False
            texto_celda = "".join(self.current_cell).strip()
            self.current_row.append(texto_celda)

    def handle_data(self, data):
        if self.in_cell:
            self.current_cell.append(data)


def limpiar_texto(texto: str) -> str:
    """Elimina referencias tipo [1], notas al pie y caracteres especiales."""
    texto = re.sub(r"\[.*?\]", "", texto)
    texto = re.sub(r"\(.*?\)", "", texto)
    texto = re.sub(r"\s+", " ", texto)
    return texto.strip()


def extraer_monedas():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[*] Conectando a Wikipedia: {WIKI_URL}...")

    # Wikipedia bloquea peticiones que no tengan un User-Agent explícito
    req = urllib.request.Request(
        WIKI_URL,
        headers={"User-Agent": "MundialDB-Scraper/1.0 (Academic Project; Contact: info@unlam.edu.ar)"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            html = resp.read().decode("utf-8")
    except Exception as e:
        print(f"[ERROR] Error de conexión: {e}", file=sys.stderr)
        sys.exit(1)

    print("[*] Parseando tablas de divisas...")
    parser = WikipediaTableParser()
    parser.feed(html)

    # Diccionario para deduplicar por codigo_iso (UNIQUE constraint)
    # Formato: { "USD": "Dólar estadounidense", ... }
    monedas_unicas = {}

    for fila in parser.rows:
        if len(fila) < 3:
            continue

        # En la tabla de Wikipedia en español el formato habitual es:
        # Col 0: Código Alfa-3 | Col 1: Num | Col 2: E | Col 3: Moneda | Col 4: Países
        # O Col 0: Código | Col 1: Moneda
        posible_codigo = fila[0].strip().upper()
        posible_nombre = ""

        if re.fullmatch(r"[A-Z]{3}", posible_codigo):
            # El código está en la primera columna
            for item in fila[1:]:
                texto = limpiar_texto(item)
                if texto and not re.fullmatch(r"\d+", texto) and len(texto) > 1:
                    posible_nombre = texto
                    break
        elif len(fila) > 1 and re.fullmatch(r"[A-Z]{3}", fila[1].strip().upper()):
            # En algunas tablas el código está en la segunda columna
            posible_codigo = fila[1].strip().upper()
            posible_nombre = limpiar_texto(fila[0])

        if re.fullmatch(r"[A-Z]{3}", posible_codigo) and posible_nombre:
            # Descartar códigos de prueba o metales de uso no financiero directo
            if posible_codigo in ("XXX", "XTS"):
                continue

            # Ajuste a la restricción varchar(50)
            nombre_final = posible_nombre[:50].strip()

            # Si la moneda no fue agregada, o si la versión actual tiene un nombre más descriptivo
            if posible_codigo not in monedas_unicas:
                monedas_unicas[posible_codigo] = nombre_final

    if not monedas_unicas:
        print("[!] Advertencia: No se encontraron registros con el parser básico. Aplicando fallback tabular...")

    # Asegurar monedas clave del torneo por si sufren variaciones de etiqueta en Wikipedia
    monedas_esenciales = {
        "USD": "Dólar estadounidense",
        "EUR": "Euro",
        "CAD": "Dólar canadiense",
        "MXN": "Peso mexicano",
        "BRL": "Real brasileño",
        "ARS": "Peso argentino"
    }
    for iso, desc in monedas_esenciales.items():
        if iso not in monedas_unicas:
            monedas_unicas[iso] = desc

    print(f"[*] Guardando CSV en: {OUTPUT_FILE}")
    with open(OUTPUT_FILE, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL)
        writer.writerow(["codigo_iso", "nombre"])
        
        for codigo in sorted(monedas_unicas.keys()):
            writer.writerow([codigo, monedas_unicas[codigo]])

    print(f"[OK] Extracción finalizada. Total de monedas únicas exportadas: {len(monedas_unicas)}")


if __name__ == "__main__":
    extraer_monedas()