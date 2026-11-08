"""
UNLaM - 3641 Bases de Datos Aplicada
TP: Sistema de Registro y Gestion del Mundial de Futbol
Extraccion Web Scraping: Catalogo ISO 639-1 (cat.Idioma)
Salida: archivos/idiomas.csv (codigo_iso, nombre)
"""

import os
import sys
import re
import csv
import urllib.request
from html.parser import HTMLParser

# Directorios de trabajo segun la arquitectura del proyecto
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "idiomas.csv")

# URL de Wikipedia en espanol para la norma ISO 639-1
WIKI_URL = "https://es.wikipedia.org/wiki/ISO_639-1"


class WikipediaTableParser(HTMLParser):
    """Parser liviano para extraer celdas de tablas HTML sin requerir librerias de terceros."""
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
    """Remueve notas al pie, texto entre parentesis y dobles espacios."""
    texto = re.sub(r"\[.*?\]", "", texto)
    texto = re.sub(r"\(.*?\)", "", texto)
    texto = re.sub(r"\s+", " ", texto)
    return texto.strip()


def extraer_idiomas():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[*] Conectando a Wikipedia: {WIKI_URL}...")

    req = urllib.request.Request(
        WIKI_URL,
        headers={"User-Agent": "MundialDB-Scraper/1.0 (Academic Project; Contact: info@unlam.edu.ar)"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            html = resp.read().decode("utf-8")
    except Exception as e:
        print(f"[ERROR] Error de conexion con Wikipedia: {e}", file=sys.stderr)
        sys.exit(1)

    print("[*] Parseando tablas de codigos ISO 639-1...")
    parser = WikipediaTableParser()
    parser.feed(html)

    # Diccionario para garantizar unicidad por codigo_iso (UNIQUE NOT NULL)
    idiomas_unicos = {}

    for fila in parser.rows:
        if len(fila) < 2:
            continue

        codigo_iso = None
        nombre_idioma = None

        # Evaluamos las celdas de la fila:
        # En la tabla de Wikipedia ISO 639-1 suele figurar:
        # Columna 639-1 (2 letras) y el nombre en castellano/espanol.
        for idx, celda in enumerate(fila):
            celda_limpia = limpiar_texto(celda)
            
            # Buscar el codigo ISO 639-1 de exactamente 2 caracteres alfabeticos
            if not codigo_iso and re.fullmatch(r"[A-Za-z]{2}", celda_limpia):
                codigo_iso = celda_limpia.upper()
                # Por lo general, el nombre del idioma suele ser la columna previa o la siguiente
                if idx > 0 and len(limpiar_texto(fila[idx - 1])) > 2:
                    nombre_idioma = limpiar_texto(fila[idx - 1])
                elif idx + 1 < len(fila) and len(limpiar_texto(fila[idx + 1])) > 2:
                    nombre_idioma = limpiar_texto(fila[idx + 1])
                break

        if codigo_iso and nombre_idioma:
            # Descartar si el nombre es un codigo de 3 letras (como el ISO 639-2)
            if re.fullmatch(r"[A-Za-z]{3}", nombre_idioma):
                continue

            # Ajuste a la restriccion varchar(50)
            nombre_final = nombre_idioma[:50].strip()

            if codigo_iso not in idiomas_unicos and len(nombre_final) > 1:
                idiomas_unicos[codigo_iso] = nombre_final

    # Idiomas base obligatorios para el torneo y campanias de marketing
    idiomas_esenciales = {
        "ES": "Español",
        "EN": "Inglés",
        "FR": "Francés",
        "DE": "Alemán",
        "PT": "Portugués",
        "IT": "Italiano",
        "NL": "Neerlandés",
        "AR": "Árabe",
        "JA": "Japonés",
        "KO": "Coreano"
    }
    for iso, nombre in idiomas_esenciales.items():
        if iso not in idiomas_unicos:
            idiomas_unicos[iso] = nombre

    print(f"[*] Escribiendo archivo CSV en: {OUTPUT_FILE}")
    # Se fuerza lineterminator='\n' para concordar con ROWTERMINATOR = '\n' del SP
    with open(OUTPUT_FILE, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        writer.writerow(["codigo_iso", "nombre"])
        
        for codigo in sorted(idiomas_unicos.keys()):
            writer.writerow([codigo, idiomas_unicos[codigo]])

    print(f"[OK] Extraccion finalizada exitosamente:")
    print(f"     -> Archivo generado : {OUTPUT_FILE}")
    print(f"     -> Idiomas unicos   : {len(idiomas_unicos)}")


if __name__ == "__main__":
    extraer_idiomas()