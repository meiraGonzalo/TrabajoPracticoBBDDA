"""
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Scraper de arbitros (modulo disc)
 Grupo 02 - Comision 02-5600

 Objetivo: obtener por scraping la nomina de arbitros del Mundial 2026 y
           generar el XML que consume imp.usp_ImportarArbitros (06_importacion_disciplina.sql).

 Fuente:   https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_officials
 Tecnica:  HTTP GET + parseo del HTML con BeautifulSoup (html.parser).
           Se toma la tabla "Referees and assistant referees" (cabecera
           "Confederation | Referees | ...").
             - La celda de confederacion usa rowspan: la primera fila de cada
               confederacion tiene 5 celdas y las demas 4. Se detecta por cantidad
               de celdas (no por el atributo rowspan: OFC tiene una sola fila y no lo trae).
             - La celda del arbitro tiene el formato "Nombre ( Pais )".
             - El nombre se separa en nombre/apellido (ultimo token = apellido, con
               particulas como de/da/al/van pegadas al apellido). Es cosmetico: la
               clave de negocio del import usa nombre + apellido + pais juntos.
             - El pais se traduce al espanol para coincidir con cat.Pais.

 Uso:
     python scraper_arbitros.py                       # descarga y genera arbitros.xml
     python scraper_arbitros.py --html officials.html # usa una copia local del HTML
     python scraper_arbitros.py --salida C:\\MundialDB\\arbitros.xml

 Requiere: pip install requests beautifulsoup4
=====================================================================
"""
import argparse
import re
import sys
import xml.etree.ElementTree as ET

from bs4 import BeautifulSoup

URL = "https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_officials"
USER_AGENT = "TP-UNLaM-BBDDA (scraping educativo)"   # Wikipedia rechaza pedidos sin User-Agent

# Particulas que forman parte del apellido (se pegan al apellido al separar)
PARTICULAS = {"de", "del", "la", "da", "dos", "das", "van", "von", "al", "bin", "ben", "el"}

# Pais en ingles (Wikipedia) -> nombre en espanol (como esta en cat.Pais)
PAISES = {
    "Algeria": "Argelia", "Argentina": "Argentina", "Australia": "Australia",
    "Brazil": "Brasil", "Canada": "Canadá", "Chile": "Chile", "China": "China",
    "Colombia": "Colombia", "Costa Rica": "Costa Rica", "Egypt": "Egipto",
    "El Salvador": "El Salvador", "England": "Inglaterra", "France": "Francia",
    "Gabon": "Gabón", "Germany": "Alemania", "Honduras": "Honduras", "Italy": "Italia",
    "Jamaica": "Jamaica", "Japan": "Japón", "Jordan": "Jordania", "Mauritania": "Mauritania",
    "Mexico": "México", "Morocco": "Marruecos", "Netherlands": "Países Bajos",
    "New Zealand": "Nueva Zelanda", "Norway": "Noruega", "Paraguay": "Paraguay",
    "Peru": "Perú", "Poland": "Polonia", "Portugal": "Portugal", "Qatar": "Qatar",
    "Romania": "Rumania", "Saudi Arabia": "Arabia Saudita", "Slovenia": "Eslovenia",
    "South Africa": "Sudáfrica", "Spain": "España", "Sweden": "Suecia",
    "Switzerland": "Suiza", "United Arab Emirates": "Emiratos Árabes Unidos",
    "United States": "Estados Unidos", "Uruguay": "Uruguay", "Uzbekistan": "Uzbekistán",
    "Venezuela": "Venezuela",
}

# "Nombre ( Pais )" -> grupos nombre y pais
RX_ARBITRO = re.compile(r"^(?P<nombre>.+?)\s*\(\s*(?P<pais>[^()]+?)\s*\)\s*$")


def obtener_html(ruta_local):
    """Devuelve el HTML: de un archivo local si se indica, o descargandolo de Wikipedia."""
    if ruta_local:
        with open(ruta_local, encoding="utf-8") as f:
            return f.read()
    import requests
    resp = requests.get(URL, headers={"User-Agent": USER_AGENT}, timeout=30)
    resp.raise_for_status()
    return resp.text


def encontrar_tabla(soup):
    """Tabla de arbitros: la wikitable cuya cabecera es 'Confederation | Referees | ...'."""
    for tabla in soup.find_all("table", class_="wikitable"):
        primera = tabla.find("tr")
        if not primera:
            continue
        cab = [c.get_text(" ", strip=True) for c in primera.find_all(["th", "td"])]
        if len(cab) >= 2 and cab[0] == "Confederation" and cab[1] == "Referees":
            return tabla
    raise RuntimeError("No se encontro la tabla de arbitros (cambio la estructura de la pagina?)")


def separar_nombre(completo):
    """Ultimo token = apellido; las particulas anteriores se pegan al apellido."""
    tokens = completo.split()
    if len(tokens) == 1:
        return "", tokens[0]            # sin nombre: el SP lo va a reportar como error de fila
    i = len(tokens) - 1                 # indice donde empieza el apellido
    while i > 1 and tokens[i - 1].lower() in PARTICULAS:
        i -= 1
    return " ".join(tokens[:i]), " ".join(tokens[i:])


def extraer_arbitros(tabla):
    """Lista de dicts {confederacion, nombre, apellido, pais} y lista de avisos."""
    arbitros, avisos = [], []
    confederacion = None
    for tr in tabla.find_all("tr")[1:]:               # [1:] salta la cabecera
        celdas = tr.find_all("td")
        if not celdas:
            continue
        if len(celdas) == 5:                          # fila que trae la celda de confederacion
            confederacion = celdas[0].get_text(strip=True)
            celda_arbitro = celdas[1]
        else:
            celda_arbitro = celdas[0]
        texto = celda_arbitro.get_text(" ", strip=True)
        m = RX_ARBITRO.match(texto)
        if not m:
            avisos.append(f"Fila ignorada, no tiene formato 'Nombre ( Pais )': {texto!r}")
            continue
        nombre, apellido = separar_nombre(m["nombre"])
        pais_en = m["pais"]
        if pais_en not in PAISES:
            avisos.append(f"Pais sin traduccion, se deja en ingles: {pais_en!r}")
        arbitros.append({
            "confederacion": confederacion,
            "nombre": nombre,
            "apellido": apellido,
            "pais": PAISES.get(pais_en, pais_en),
        })
    return arbitros, avisos


def escribir_xml(arbitros, ruta_salida):
    """Escribe el XML con el contrato de imp.usp_ImportarArbitros (elementos, UTF-8)."""
    raiz = ET.Element("Arbitros")
    for a in arbitros:
        nodo = ET.SubElement(raiz, "Arbitro")
        ET.SubElement(nodo, "nombre").text = a["nombre"]
        ET.SubElement(nodo, "apellido").text = a["apellido"]
        ET.SubElement(nodo, "pais").text = a["pais"]
        ET.SubElement(nodo, "categoria").text = "FIFA"   # los arbitros mundialistas son FIFA
    arbol = ET.ElementTree(raiz)
    ET.indent(arbol, space="  ")
    arbol.write(ruta_salida, encoding="utf-8", xml_declaration=True)


def main():
    ap = argparse.ArgumentParser(description="Scraper de arbitros del Mundial 2026 -> XML")
    ap.add_argument("--html", help="usar una copia local del HTML en vez de descargar")
    ap.add_argument("--salida", default="arbitros.xml", help="ruta del XML de salida")
    args = ap.parse_args()

    soup = BeautifulSoup(obtener_html(args.html), "html.parser")
    arbitros, avisos = extraer_arbitros(encontrar_tabla(soup))
    escribir_xml(arbitros, args.salida)

    for aviso in avisos:
        print("AVISO:", aviso, file=sys.stderr)
    print(f"{len(arbitros)} arbitros escritos en {args.salida}")


if __name__ == "__main__":
    main()
