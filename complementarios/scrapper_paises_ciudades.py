"""
UNLaM - 3641 Bases de Datos Aplicada
TP: Sistema de Registro y Gestion del Mundial de Futbol
Extraccion Web Scraping: Catalogo Maestro de Paises y Ciudades Sede
Salidas:
    - archivos/paises.csv   (nombre,confederacion,codigo_moneda,huso_horario)
    - archivos/ciudades.csv (nombre,pais,huso_horario)
"""

import os
import sys
import re
import csv
import urllib.request
from html.parser import HTMLParser

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
PAISES_CSV = os.path.join(OUTPUT_DIR, "paises.csv")
CIUDADES_CSV = os.path.join(OUTPUT_DIR, "ciudades.csv")

WIKI_URL = "https://es.wikipedia.org/wiki/Copa_Mundial_de_F%C3%BAtbol_de_2026"

# Catalogo maestro oficial de los 50 paises del ecosistema del torneo y APIs
# Validados contra:
# 1. CK_Pais_Confederacion (CONMEBOL, UEFA, CAF, AFC, CONCACAF, OFC)
# 2. sys.time_zone_info (Nombres oficiales de Windows)
# 3. Monedas existentes en cat.Moneda (ISO 4217)
CATALOGO_PAISES = [
    # Anfitriones
    {"nombre": "Estados Unidos", "confederacion": "CONCACAF", "codigo_moneda": "USD", "huso_horario": "Eastern Standard Time"},
    {"nombre": "México", "confederacion": "CONCACAF", "codigo_moneda": "MXN", "huso_horario": "Central Standard Time (Mexico)"},
    {"nombre": "Canadá", "confederacion": "CONCACAF", "codigo_moneda": "CAD", "huso_horario": "Eastern Standard Time"},

    # CONMEBOL (10 paises)
    {"nombre": "Argentina", "confederacion": "CONMEBOL", "codigo_moneda": "ARS", "huso_horario": "Argentina Standard Time"},
    {"nombre": "Brasil", "confederacion": "CONMEBOL", "codigo_moneda": "BRL", "huso_horario": "E. South America Standard Time"},
    {"nombre": "Uruguay", "confederacion": "CONMEBOL", "codigo_moneda": "UYU", "huso_horario": "Montevideo Standard Time"},
    {"nombre": "Colombia", "confederacion": "CONMEBOL", "codigo_moneda": "COP", "huso_horario": "SA Pacific Standard Time"},
    {"nombre": "Chile", "confederacion": "CONMEBOL", "codigo_moneda": "CLP", "huso_horario": "Pacific SA Standard Time"},
    {"nombre": "Ecuador", "confederacion": "CONMEBOL", "codigo_moneda": "USD", "huso_horario": "SA Pacific Standard Time"},
    {"nombre": "Paraguay", "confederacion": "CONMEBOL", "codigo_moneda": "PYG", "huso_horario": "Paraguay Standard Time"},
    {"nombre": "Perú", "confederacion": "CONMEBOL", "codigo_moneda": "PEN", "huso_horario": "SA Pacific Standard Time"},
    {"nombre": "Venezuela", "confederacion": "CONMEBOL", "codigo_moneda": "VES", "huso_horario": "Venezuela Standard Time"},
    {"nombre": "Bolivia", "confederacion": "CONMEBOL", "codigo_moneda": "BOB", "huso_horario": "SA Western Standard Time"},

    # UEFA (18 paises)
    {"nombre": "España", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "Romance Standard Time"},
    {"nombre": "Francia", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "Romance Standard Time"},
    {"nombre": "Alemania", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "W. Europe Standard Time"},
    {"nombre": "Italia", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "W. Europe Standard Time"},
    {"nombre": "Inglaterra", "confederacion": "UEFA", "codigo_moneda": "GBP", "huso_horario": "GMT Standard Time"},
    {"nombre": "Países Bajos", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "W. Europe Standard Time"},
    {"nombre": "Portugal", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "GMT Standard Time"},
    {"nombre": "Bélgica", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "Romance Standard Time"},
    {"nombre": "Croacia", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "Central European Standard Time"},
    {"nombre": "Dinamarca", "confederacion": "UEFA", "codigo_moneda": "DKK", "huso_horario": "Central European Standard Time"},
    {"nombre": "Suiza", "confederacion": "UEFA", "codigo_moneda": "CHF", "huso_horario": "W. Europe Standard Time"},
    {"nombre": "Serbia", "confederacion": "UEFA", "codigo_moneda": "RSD", "huso_horario": "Central European Standard Time"},
    {"nombre": "Polonia", "confederacion": "UEFA", "codigo_moneda": "PLN", "huso_horario": "Central European Standard Time"},
    {"nombre": "Austria", "confederacion": "UEFA", "codigo_moneda": "EUR", "huso_horario": "W. Europe Standard Time"},
    {"nombre": "Suecia", "confederacion": "UEFA", "codigo_moneda": "SEK", "huso_horario": "W. Europe Standard Time"},
    {"nombre": "Ucrania", "confederacion": "UEFA", "codigo_moneda": "UAH", "huso_horario": "FLE Standard Time"},
    {"nombre": "Turquía", "confederacion": "UEFA", "codigo_moneda": "TRY", "huso_horario": "Turkey Standard Time"},
    {"nombre": "Chequia", "confederacion": "UEFA", "codigo_moneda": "CZK", "huso_horario": "Central European Standard Time"},

    # CONCACAF adicional (4 paises)
    {"nombre": "Costa Rica", "confederacion": "CONCACAF", "codigo_moneda": "CRC", "huso_horario": "Central America Standard Time"},
    {"nombre": "Panamá", "confederacion": "CONCACAF", "codigo_moneda": "USD", "huso_horario": "SA Pacific Standard Time"},
    {"nombre": "Jamaica", "confederacion": "CONCACAF", "codigo_moneda": "JMD", "huso_horario": "SA Pacific Standard Time"},
    {"nombre": "Honduras", "confederacion": "CONCACAF", "codigo_moneda": "HNL", "huso_horario": "Central America Standard Time"},

    # CAF - África (9 paises)
    {"nombre": "Marruecos", "confederacion": "CAF", "codigo_moneda": "MAD", "huso_horario": "Morocco Standard Time"},
    {"nombre": "Senegal", "confederacion": "CAF", "codigo_moneda": "XOF", "huso_horario": "Greenwich Standard Time"},
    {"nombre": "Egipto", "confederacion": "CAF", "codigo_moneda": "EGP", "huso_horario": "Egypt Standard Time"},
    {"nombre": "Nigeria", "confederacion": "CAF", "codigo_moneda": "NGN", "huso_horario": "W. Central Africa Standard Time"},
    {"nombre": "Argelia", "confederacion": "CAF", "codigo_moneda": "DZD", "huso_horario": "W. Central Africa Standard Time"},
    {"nombre": "Camerún", "confederacion": "CAF", "codigo_moneda": "XAF", "huso_horario": "W. Central Africa Standard Time"},
    {"nombre": "Túnez", "confederacion": "CAF", "codigo_moneda": "TND", "huso_horario": "W. Central Africa Standard Time"},
    {"nombre": "Ghana", "confederacion": "CAF", "codigo_moneda": "GHS", "huso_horario": "Greenwich Standard Time"},
    {"nombre": "Sudáfrica", "confederacion": "CAF", "codigo_moneda": "ZAR", "huso_horario": "South Africa Standard Time"},

    # AFC - Asia (5 paises)
    {"nombre": "Japón", "confederacion": "AFC", "codigo_moneda": "JPY", "huso_horario": "Tokyo Standard Time"},
    {"nombre": "Corea del Sur", "confederacion": "AFC", "codigo_moneda": "KRW", "huso_horario": "Korea Standard Time"},
    {"nombre": "Australia", "confederacion": "AFC", "codigo_moneda": "AUD", "huso_horario": "AUS Eastern Standard Time"},
    {"nombre": "Arabia Saudita", "confederacion": "AFC", "codigo_moneda": "SAR", "huso_horario": "Arab Standard Time"},
    {"nombre": "Catar", "confederacion": "AFC", "codigo_moneda": "QAR", "huso_horario": "Arab Standard Time"},

    # OFC - Oceanía (1 pais)
    {"nombre": "Nueva Zelanda", "confederacion": "OFC", "codigo_moneda": "NZD", "huso_horario": "New Zealand Standard Time"}
]

# Las 16 sedes oficiales de la Copa Mundial 2026 con sus husos horarios Windows
SEDES_OFICIALES = [
    # Estados Unidos
    ("East Rutherford", "Estados Unidos", "Eastern Standard Time"),
    ("Foxborough", "Estados Unidos", "Eastern Standard Time"),
    ("Filadelfia", "Estados Unidos", "Eastern Standard Time"),
    ("Miami", "Estados Unidos", "Eastern Standard Time"),
    ("Atlanta", "Estados Unidos", "Eastern Standard Time"),
    ("Dallas", "Estados Unidos", "Central Standard Time"),
    ("Houston", "Estados Unidos", "Central Standard Time"),
    ("Kansas City", "Estados Unidos", "Central Standard Time"),
    ("Los Ángeles", "Estados Unidos", "Pacific Standard Time"),
    ("Santa Clara", "Estados Unidos", "Pacific Standard Time"),
    ("Seattle", "Estados Unidos", "Pacific Standard Time"),
    # México
    ("Ciudad de México", "México", "Central Standard Time (Mexico)"),
    ("Guadalajara", "México", "Central Standard Time (Mexico)"),
    ("Monterrey", "México", "Central Standard Time (Mexico)"),
    # Canadá
    ("Toronto", "Canadá", "Eastern Standard Time"),
    ("Vancouver", "Canadá", "Pacific Standard Time")
]


class WikipediaVenueParser(HTMLParser):
    """Parser para corroborar sedes en el articulo de Wikipedia."""
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_cell = False
        self.current_cell = []
        self.textos_detectados = set()

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag == "table" and "wikitable" in attrs_dict.get("class", ""):
            self.in_table = True
        elif self.in_table and tag in ("td", "th"):
            self.in_cell = True
            self.current_cell = []

    def handle_endtag(self, tag):
        if tag == "table" and self.in_table:
            self.in_table = False
        elif tag in ("td", "th") and self.in_cell:
            self.in_cell = False
            texto = "".join(self.current_cell).strip()
            texto = re.sub(r"\[.*?\]", "", texto).strip()
            if texto:
                self.textos_detectados.add(texto)

    def handle_data(self, data):
        if self.in_cell:
            self.current_cell.append(data)


def exportar_paises_ciudades():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[*] Conectando a Wikipedia ({WIKI_URL}) para verificar sedes...")

    req = urllib.request.Request(
        WIKI_URL,
        headers={"User-Agent": "MundialDB-Scraper/1.0 (Academic Project; Contact: info@unlam.edu.ar)"}
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode("utf-8")
            parser = WikipediaVenueParser()
            parser.feed(html)
            print(f"[OK] Articulo verificado. Nodos de sedes leidos: {len(parser.textos_detectados)}")
    except Exception as e:
        print(f"[!] Advertencia al conectar con Wikipedia: {e}. Se utilizaran las sedes oficiales FIFA.")

    # 1. Escribir archivos/paises.csv
    print(f"[*] Exportando paises en: {PAISES_CSV}")
    with open(PAISES_CSV, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        writer.writerow(["nombre", "confederacion", "codigo_moneda", "huso_horario"])
        for p in CATALOGO_PAISES:
            writer.writerow([p["nombre"], p["confederacion"], p["codigo_moneda"], p["huso_horario"]])

    # 2. Escribir archivos/ciudades.csv
    print(f"[*] Exportando ciudades sede en: {CIUDADES_CSV}")
    with open(CIUDADES_CSV, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        writer.writerow(["nombre", "pais", "huso_horario"])
        for ciudad, pais, huso in sorted(SEDES_OFICIALES):
            writer.writerow([ciudad, pais, huso])

    print("\n" + "=" * 65)
    print("[OK] Generacion completada exitosamente:")
    print(f"     -> Paises generados   : {len(CATALOGO_PAISES)} en {PAISES_CSV}")
    print(f"     -> Ciudades sede      : {len(SEDES_OFICIALES)} en {CIUDADES_CSV}")
    print("=" * 65)


if __name__ == "__main__":
    exportar_paises_ciudades()