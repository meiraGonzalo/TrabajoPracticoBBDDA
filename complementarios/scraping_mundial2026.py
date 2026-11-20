"""
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Scraping de Wikipedia (Partes 1 y 2)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 05/11/2026

 QUE HACE
   Lee paginas de Wikipedia del Mundial 2026 y genera TRES archivos CSV
   con el formato que esperan los SP de importacion:

 COMO SE USA
   1) Instalar Python 3 y las dos librerias (una sola vez):
          pip install requests beautifulsoup4
   2) Ejecutar (desde la carpeta donde esta este archivo):
          python scraping_mundial2026.py
      Por defecto deja los archivos en C:\\MundialDB\\ . Para otra carpeta:
          python scraping_mundial2026.py --salida "D:\\otra\\carpeta"
   3) Revisar lo que muestra en pantalla (cantidades y avisos) y despues
      ejecutar los SP de importacion en SSMS.

 PAISES Y CIUDADES
   - Los paises se escriben EN INGLES, tal como los muestra Wikipedia
     ("Qatar", "Czech Republic"...). La traduccion al nombre de cat.Pais
     ("Catar", "Chequia"...) la hace la base, en T-SQL, con imp.usp_BuscarPais
     y la tabla imp.EquivalenciaPais.
   - Las equivalencias NO estan escritas en el codigo: el programa le pregunta
     a Wikipedia como se llama cada pais en castellano (link entre idiomas de
     cada articulo) y genera equivalencias_paises_2026.csv, que se importa con
     imp.usp_Importar_EquivalenciasPais. Necesita archivos/paises.csv para
     elegir el nombre igual al de la base (--paises "ruta" si esta en otro lado).
   - Las ciudades de las sedes se escriben con el nombre de archivos/ciudades.csv
     ("Ciudad de México", "Los Ángeles"...), ver CIUDADES_SEDE.

 GOLES
   - Se leen de los mismos recuadros de partido (celdas .fhgoal y .fagoal):
     jugador, minuto (90+3 -> minuto 90, adicional 3) y tipo (Jugada, Penal
     o En contra). La tanda de penales no se toma. Resultado: goles_2026.csv,
     que se importa con imp.usp_Importar_Goles.
"""

import argparse
import csv
import os
import re
import sys
import time
from urllib.parse import unquote

import requests
from bs4 import BeautifulSoup

# ---------------------------------------------------------------------
# Paginas de origen
# ---------------------------------------------------------------------
WIKI = "https://en.wikipedia.org/wiki/"
PAGINAS = {
    "plantillas": WIKI + "2026_FIFA_World_Cup_squads",
    "sedes": WIKI + "2026_FIFA_World_Cup",
    "grupos": [WIKI + "2026_FIFA_World_Cup_Group_" + letra for letra in "ABCDEFGHIJKL"],
    "eliminatoria": WIKI + "2026_FIFA_World_Cup_knockout_stage",
}

# Wikipedia pide identificarse con un User-Agent propio
HEADERS = {"User-Agent": "TP-UNLaM-BasesDeDatosAplicada/1.0 (trabajo practico universitario)"}

# ---------------------------------------------------------------------
# Datos que NO estan en la pagina y los SP necesitan para crear la ciudad
# de cada sede: pais y huso horario (nombre de Windows, el que usa
# AT TIME ZONE). Son las 16 ciudades sede del Mundial 2026.
# Se busca por una palabra clave del nombre de la ciudad que muestra Wikipedia.
# El nombre de la ciudad (primera columna) es EL MISMO que en archivos/ciudades.csv,
# asi la importacion de sedes encuentra la ciudad que ya esta en cat.Ciudad y no
# crea otra. El nombre que usa Wikipedia queda en la ultima columna (alias).
# ---------------------------------------------------------------------
CIUDADES_SEDE = [
    # (ciudad,         pais en ingles,   huso horario de Windows,           otros nombres que usa Wikipedia)
    ("Ciudad de México", "Mexico",       "Central Standard Time (Mexico)",  ["Mexico City"]),
    ("Guadalajara",    "Mexico",         "Central Standard Time (Mexico)",  ["Zapopan"]),
    ("Monterrey",      "Mexico",         "Central Standard Time (Mexico)",  ["Guadalupe"]),
    ("Toronto",        "Canada",         "Eastern Standard Time",           []),
    ("Vancouver",      "Canada",         "Pacific Standard Time",           []),
    ("Atlanta",        "United States",  "Eastern Standard Time",           []),
    ("Foxborough",     "United States",  "Eastern Standard Time",           ["Boston", "Foxboro"]),
    ("Dallas",         "United States",  "Central Standard Time",           ["Arlington"]),
    ("Houston",        "United States",  "Central Standard Time",           []),
    ("Kansas City",    "United States",  "Central Standard Time",           []),
    ("Los Ángeles",    "United States",  "Pacific Standard Time",           ["Los Angeles", "Inglewood"]),
    ("Miami",          "United States",  "Eastern Standard Time",           ["Miami Gardens"]),
    ("East Rutherford", "United States", "Eastern Standard Time",           ["New York", "New Jersey"]),
    ("Filadelfia",     "United States",  "Eastern Standard Time",           ["Philadelphia"]),
    ("Santa Clara",    "United States",  "Pacific Standard Time",           ["San Francisco", "Bay Area"]),
    ("Seattle",        "United States",  "Pacific Standard Time",           []),
]

# Nombres de las fases tal como aparecen en los titulos de la pagina eliminatoria
FASES_ELIMINATORIA = ["Round of 32", "Round of 16", "Quarter-finals", "Quarterfinals",
                      "Semi-finals", "Semifinals", "Match for third place",
                      "Third place play-off", "Third-place play-off", "Final"]

# Fase de la eliminatoria segun el NUMERO OFICIAL del partido (calendario FIFA 2026).
# Es la fuente mas segura: en la pagina, arriba de cada recuadro no siempre esta el
# titulo de la fase (a veces hay subtitulos por partido), y eso daba fases mal puestas.
FASES_POR_NUMERO = [
    (73,  88,  "Round of 32"),
    (89,  96,  "Round of 16"),
    (97,  100, "Quarter-finals"),
    (101, 102, "Semi-finals"),
    (103, 103, "Match for third place"),
    (104, 104, "Final"),
]

avisos = []   # problemas encontrados, se muestran al final
goles_filas = []   # goles de todos los partidos (los llena scrapear_partidos)


# =====================================================================
# Funciones de ayuda
# =====================================================================

def descargar(url, carpeta_html=None):
    """Devuelve el HTML de la pagina ya 'parseado' con BeautifulSoup.
    Si se indico --html, lo lee de un archivo guardado en vez de internet."""
    if carpeta_html:
        nombre = url.rsplit("/", 1)[-1] + ".html"
        with open(os.path.join(carpeta_html, nombre), encoding="utf-8") as f:
            html = f.read()
    else:
        print("  descargando", url)
        respuesta = requests.get(url, headers=HEADERS, timeout=30)
        respuesta.raise_for_status()          # si la pagina no existe, corta con error
        html = respuesta.text
        time.sleep(1)                         # pausa para no saturar a Wikipedia
    sopa = BeautifulSoup(html, "html.parser")
    quitar_ocultos(sopa)
    return sopa


def quitar_ocultos(sopa):
    """Wikipedia mete texto oculto (para ordenar las tablas, fechas ISO
    escondidas, notas al pie). Se borra para quedarnos solo con lo que se ve."""
    for tag in sopa.select('[style*="display:none"], [style*="display: none"], '
                           '.sortkey, sup.reference, .mw-editsection'):
        tag.decompose()


def texto(tag):
    """Texto visible de un elemento, sin espacios de mas.
    Se cambia el espacio especial de la web (\\xa0) por uno comun y el ';'
    por ',' para no romper el separador del CSV."""
    if tag is None:
        return ""
    t = tag.get_text(" ", strip=True).replace("\xa0", " ").replace(";", ",")
    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"\(\s+", "(", t)          # "( captain )" -> "(captain)"
    t = re.sub(r"\s+\)", ")", t)
    t = re.sub(r"\s+,", ",", t)
    return t.strip()


def titulo_anterior(tag, niveles=("h2", "h3", "h4")):
    """Titulo de la seccion en la que esta el elemento (el h2/h3 de arriba)."""
    titulo = tag.find_previous(list(niveles))
    return texto(titulo)


def fase_de_la_seccion(tag):
    """Fase de un recuadro de la eliminatoria segun los titulos de la pagina.
    Se miran los titulos de arriba (del mas cercano al mas lejano) y se toma el
    PRIMERO que sea el nombre de una fase. Asi se saltean los subtitulos que no
    son fases (ej. un titulo por partido)."""
    for titulo in tag.find_all_previous(["h2", "h3", "h4"]):
        t = texto(titulo).lower()
        for f in FASES_ELIMINATORIA:
            if f.lower() in t:
                return f
    return ""


def fase_por_numero(nro):
    """Fase segun el numero oficial del partido (73 a 104). '' si no corresponde."""
    try:
        n = int(nro)
    except ValueError:
        return ""
    for desde, hasta, fase in FASES_POR_NUMERO:
        if desde <= n <= hasta:
            return fase
    return ""



def pais_de_bandera(celda):
    """El pais del club solo aparece como una bandera (imagen). El nombre
    del archivo de la imagen dice el pais: '.../Flag_of_Mexico.svg/...'"""
    if celda is None:
        return ""
    for img in celda.find_all("img"):
        m = re.search(r"Flag_of_(.+?)\.svg", unquote(img.get("src", "")))
        if m:
            pais = m.group(1).replace("_", " ")
            if pais.lower().startswith("the "):
                pais = pais[4:]
            return pais
    return ""


def escribir_csv(ruta, titulos, filas):
    """Escribe el CSV: separado por ';', UTF-8, fin de linea de Windows."""
    with open(ruta, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";", lineterminator="\r\n", quoting=csv.QUOTE_NONE,
                       escapechar="\\")
        w.writerow(titulos)
        w.writerows(filas)
    print(f"  -> {ruta}: {len(filas)} filas")


def normalizar(t):
    """Para comparar nombres: minusculas, sin la cruz de Wikipedia, con los
    distintos tipos de guion convertidos a '-' y sin signos raros."""
    t = (t or "").replace("\u2020", "").replace("&amp;", "&")
    t = re.sub(r"[\u2010-\u2015\u2212]", "-", t)
    return re.sub(r"\s+", " ", t).strip().lower()


def ciudad_sede(nombre):
    """Devuelve (ciudad, pais, huso) de CIUDADES_SEDE si el texto menciona
    la ciudad o alguno de sus otros nombres (ej. 'Inglewood' -> Los Angeles)."""
    n = normalizar(nombre)
    for ciudad, pais, huso, alias in CIUDADES_SEDE:
        if any(normalizar(x) in n for x in [ciudad] + alias):
            return ciudad, pais, huso
    return "", "", ""


def tabla_como_grilla(tabla):
    """Convierte una tabla HTML en una lista de filas (lista de celdas),
    repitiendo las celdas combinadas (rowspan / colspan) en cada fila que
    ocupan. Sin esto, las filas con celdas combinadas quedan 'cortas'."""
    grilla, pendientes = [], {}            # pendientes[col] = (celda, filas que faltan)
    for tr in tabla.find_all("tr"):
        fila, col = [], 0
        celdas = tr.find_all(["td", "th"], recursive=False)
        i = 0
        while i < len(celdas) or col in pendientes:
            if col in pendientes:                       # celda que viene de una fila de arriba
                celda, resto = pendientes.pop(col)
                fila.append(celda)
                if resto > 1:
                    pendientes[col] = (celda, resto - 1)
                col += 1
                continue
            celda = celdas[i]
            i += 1
            span_f = int(re.sub(r"\D", "", celda.get("rowspan", "1")) or 1)
            span_c = int(re.sub(r"\D", "", celda.get("colspan", "1")) or 1)
            for _ in range(span_c):
                fila.append(celda)
                if span_f > 1:
                    pendientes[col] = (celda, span_f - 1)
                col += 1
        grilla.append(fila)
    return grilla


def es_equipo_real(nombre):
    """Descarta los lugares todavia no definidos ('Winner Group A', 'Match 73')."""
    n = nombre.lower()
    return bool(nombre) and not any(p in n for p in
                                    ("winner", "runner", "loser", "match ", "path", "group ", "place"))

# 1) PLANTILLAS


def scrapear_plantillas(carpeta_html):
    print("Plantillas:")
    sopa = descargar(PAGINAS["plantillas"], carpeta_html)
    filas = []

    for tabla in sopa.select("table.wikitable"):
        encabezados = [texto(th) for th in tabla.find("tr").find_all(["th", "td"])]
        # Solo las tablas de jugadores (tienen las columnas Player y Club)
        if "Player" not in encabezados or "Club" not in encabezados:
            continue

        seleccion = titulo_anterior(tabla, ("h3",))   # ej. "Mexico"
        col = {nombre: i for i, nombre in enumerate(encabezados)}

        for tr in tabla.find_all("tr")[1:]:
            celdas = tr.find_all(["td", "th"])
            if len(celdas) < len(encabezados):
                continue

            def celda(nombre):
                i = col.get(nombre)
                return celdas[i] if i is not None else None

            # Posicion: Wikipedia escribe GK / DF / MF / FW
            m = re.search(r"\b(GK|DF|MF|FW)\b", texto(celda("Pos.")))
            posicion = m.group(1) if m else texto(celda("Pos."))

            fecha_col = next((n for n in encabezados if n.startswith("Date of birth")), None)

            filas.append([
                seleccion,
                texto(celda("No.")),
                posicion,
                texto(celda("Player")),            # queda "(captain)" si lo tiene: lo saca el SP
                texto(celda(fecha_col)) if fecha_col else "",
                texto(celda("Club")),
                pais_de_bandera(celda("Club")),
            ])

    if not filas:
        avisos.append("Plantillas: no se encontro ninguna tabla de jugadores (cambio la pagina?).")
    return filas

# 2) SEDES

def scrapear_sedes(carpeta_html):
    print("Sedes:")
    sopa = descargar(PAGINAS["sedes"], carpeta_html)
    filas, vistas = [], set()

    for tabla in sopa.select("table.wikitable"):
        grilla = tabla_como_grilla(tabla)
        if not grilla:
            continue
        encabezados = [texto(c) for c in grilla[0]]
        if "Stadium" not in encabezados or "Capacity" not in encabezados:
            continue
        col = {nombre: i for i, nombre in enumerate(encabezados)}
        i_ciudad = col.get("City", 0)

        for fila in grilla[1:]:
            if len(fila) <= max(col["Stadium"], col["Capacity"], i_ciudad):
                continue
            ciudad_wiki = texto(fila[i_ciudad])
            estadio = texto(fila[col["Stadium"]])
            capacidad = texto(fila[col["Capacity"]])
            if not estadio or not re.search(r"\d", capacidad) or estadio in vistas:
                continue
            vistas.add(estadio)

            ciudad, pais, huso = ciudad_sede(ciudad_wiki + " " + estadio)
            if not pais:
                avisos.append(f"Sedes: no se reconocio la ciudad '{ciudad_wiki}' (agregarla a CIUDADES_SEDE).")
                ciudad = ciudad_wiki
            # latitud y longitud quedan vacias (no estan en la tabla)
            filas.append([pais, ciudad, estadio, capacidad, "", "", huso])
        if filas:
            break                                      # ya se encontro la tabla de sedes

    # Control: tienen que estar las 16 ciudades sede
    cargadas = {f[1] for f in filas}
    faltan = [c for c, *_ in CIUDADES_SEDE if c not in cargadas]
    if faltan:
        avisos.append("Sedes: faltan estas ciudades en la tabla: " + ", ".join(faltan))
    if not filas:
        avisos.append("Sedes: no se encontro la tabla de la seccion Venues.")
    return filas

# 3) PARTIDOS

def buscar_sede_del_partido(lugar, sedes):
    lugar_n = normalizar(lugar)
    for pais, ciudad, estadio, *_ in sedes:
        limpio = normalizar(estadio)
        m = re.match(r"(.*?)\s*\((.*)\)", limpio)
        nombres = [m.group(1), m.group(2)] if m else [limpio]
        if any(n and n in lugar_n for n in nombres):
            return estadio, ciudad

    ciudad, _, _ = ciudad_sede(lugar)
    for pais, c, estadio, *_ in sedes:
        if ciudad and c == ciudad:
            return estadio, c
    return "", ""


def leer_recuadro(box):
    datos = {}
    datos["fecha"] = texto(box.select_one(".fdate"))
    m = re.search(r"\d{1,2}:\d{2}", texto(box.select_one(".ftime")))
    datos["hora"] = m.group(0) if m else ""
    datos["local"] = texto(box.select_one(".fhome"))
    datos["visitante"] = texto(box.select_one(".faway"))

    marcador = texto(box.select_one(".fscore"))
    m = re.search(r"(\d+)\s*[\u2013\-]\s*(\d+)", marcador)       # "2–1"
    datos["gl"], datos["gv"] = (m.group(1), m.group(2)) if m else ("", "")

    todo = texto(box)
    m = re.search(r"Match\s+(\d+)", todo)                          # "Match 1" (si aparece)
    datos["nro"] = m.group(1) if m else ""
    m = re.search(r"Penalties\D*?(\d+)\s*[\u2013\-]\s*(\d+)", todo)  # tanda de penales
    datos["pl"], datos["pv"] = (m.group(1), m.group(2)) if m else ("", "")
    m = re.search(r"Attendance:?\s*([\d,\.]+)", todo)
    datos["asistencia"] = m.group(1) if m else ""

    lugar = box.select_one('[itemprop="location"]')
    datos["lugar"] = texto(lugar) if lugar else ""
    datos["goles"] = leer_goles(box)
    return datos


# Minuto de un gol como lo escribe Wikipedia: 23'  90+3'  34' (o.g.)  12' (pen.)
# La aclaracion entre parentesis puede venir como "(pen.)", "(o.g.)" o, si es un
# link, con su titulo: "(Penalty kick)", "(Own goal)". Se toma cualquiera.
MINUTO_GOL = re.compile(r"(\d{1,3})(?:\s*\+\s*(\d{1,2}))?\s*['\u2032\u2019]\s*(?:\(([^()]{1,40})\))?",
                        re.IGNORECASE)


def leer_goles(box):
    """Goles del recuadro del partido. Wikipedia los lista en la celda .fhgoal
    (local) y .fagoal (visitante): el nombre del jugador y despues sus minutos.
        'Lionel Messi 23' (pen.), 90+3' Julian Alvarez 57''
    Se recorren los minutos en orden: el texto que hay antes de cada minuto,
    si tiene letras, es el nombre del jugador que sigue. La tanda de penales
    no tiene minutos, asi que no se toma (no son goles del partido).
    Devuelve [lado, jugador, minuto, adicional, tipo] con lado 'L' o 'V'."""
    goles = []
    for lado, clase in (("L", ".fhgoal"), ("V", ".fagoal")):
        for celda in box.select(clase):
            # En el recuadro suele figurar solo el apellido ("Messi"), pero el link
            # tiene el nombre completo en su titulo ("Lionel Messi"): se usa ese,
            # que es el mismo que figura en la plantilla. Se saca la aclaracion
            # entre parentesis: "Pepe (footballer, born 1983)" -> "Pepe".
            for a in celda.find_all("a"):
                es_aclaracion = re.fullmatch(r"\(?\s*(pen|o\.?\s*g)\.?\s*\)?", a.get_text(strip=True), re.I)
                if a.get("title") and not es_aclaracion:      # "pen." y "o.g." quedan como estan
                    a.string = re.sub(r"\s*\(.*\)\s*$", "", a["title"])
            t = texto(celda)
            jugador, desde = "", 0
            for m in MINUTO_GOL.finditer(t):
                antes = t[desde:m.start()].strip(" ,")
                if re.search(r"[^\W\d_]", antes):          # tiene letras: es un nombre
                    jugador = antes
                desde = m.end()
                if not jugador:
                    continue
                marca = (m.group(3) or "").lower().replace(" ", "")
                if marca.startswith("pen"):
                    tipo = "Penal"
                elif marca.startswith("o.g") or marca.startswith("og") or marca.startswith("owngoal"):
                    tipo = "En contra"
                else:
                    tipo = "Jugada"
                goles.append([lado, jugador, m.group(1), m.group(2) or "0", tipo])
    return goles


def scrapear_partidos(carpeta_html, sedes):
    print("Partidos:")
    partidos = []

    # Fase de grupos: una pagina por grupo
    for url in PAGINAS["grupos"]:
        letra = url[-1]
        sopa = descargar(url, carpeta_html)
        for box in sopa.select("div.footballbox"):
            d = leer_recuadro(box)
            d["fase"], d["grupo"] = "Group stage", letra
            partidos.append(d)

    # Fase eliminatoria: la fase es el titulo de la seccion del recuadro
    sopa = descargar(PAGINAS["eliminatoria"], carpeta_html)
    for box in sopa.select("div.footballbox"):
        d = leer_recuadro(box)
        d["fase"] = fase_de_la_seccion(box)     # se confirma con el numero mas abajo
        d["grupo"] = ""
        partidos.append(d)

    # Solo partidos con las dos selecciones definidas
    partidos = [p for p in partidos if es_equipo_real(p["local"]) and es_equipo_real(p["visitante"])]

    numeracion_oficial = all(p["nro"] for p in partidos)
    if not numeracion_oficial:
        avisos.append("Partidos: la pagina no muestra el numero oficial de todos los partidos; "
                      "se numeraron en orden de aparicion.")
        for i, p in enumerate(partidos, start=1):
            p["nro"] = str(i)

    # Fase de la eliminatoria: manda el numero del partido (73-88 Round of 32,
    # 89-96 Round of 16, 97-100 Quarter-finals, 101-102 Semi-finals,
    # 103 tercer puesto, 104 Final). Si el titulo de la pagina decia otra cosa,
    # se avisa y se usa la del numero.
    # Solo si el numero es confiable: el oficial de la pagina, o el de orden de
    # aparicion cuando estan los 104 partidos (72 de grupos + 32 de eliminatoria).
    numero_confiable = numeracion_oficial or len(partidos) == 104
    for p in partidos:
        if p["grupo"] == "" and numero_confiable:
            fase_nro = fase_por_numero(p["nro"])
            if fase_nro and p["fase"] != fase_nro:
                if p["fase"]:
                    avisos.append(f"Partidos: el partido {p['nro']} figuraba como '{p['fase']}' "
                                  f"en la pagina; se usa '{fase_nro}' (por su numero).")
                p["fase"] = fase_nro
        if p["grupo"] == "" and not p["fase"]:
            avisos.append(f"Partidos: no se pudo saber la fase del partido {p['nro']} "
                          f"({p['local']} - {p['visitante']}).")

    filas = []
    for p in partidos:
        estadio, ciudad = buscar_sede_del_partido(p["lugar"], sedes)
        if not estadio:
            avisos.append(f"Partidos: no se encontro la sede de '{p['lugar']}' "
                          f"({p['local']} - {p['visitante']}).")
            estadio, ciudad = p["lugar"], ""
        filas.append([p["nro"], p["fase"], p["grupo"], p["fecha"], p["hora"], estadio, ciudad,
                      p["local"], p["visitante"], p["gl"], p["gv"], p["pl"], p["pv"], p["asistencia"]])

    if not filas:
        avisos.append("Partidos: no se encontro ningun partido (cambio la pagina?).")

    # Goles: el autor juega para el lado donde figura, salvo el gol en contra,
    # que Wikipedia lista del lado del equipo que lo recibio a favor.
    for p in partidos:
        goles_partido = 0
        for lado, jugador, minuto, adicional, tipo in p["goles"]:
            del_local = (lado == "L") != (tipo == "En contra")
            seleccion = p["local"] if del_local else p["visitante"]
            goles_filas.append([p["nro"], seleccion, jugador, minuto, adicional, tipo])
            goles_partido += 1
        esperados = int(p["gl"] or 0) + int(p["gv"] or 0)
        if p["gl"] != "" and goles_partido != esperados:
            avisos.append(f"Goles: en el partido {p['nro']} ({p['local']} - {p['visitante']}) "
                          f"se leyeron {goles_partido} goles y el resultado suma {esperados}.")
    return filas


# =====================================================================
# EQUIVALENCIAS DE PAISES (sin listas fijas en el codigo)
#   Los tres CSV traen los paises en ingles, como Wikipedia. En la base
#   (cat.Pais) estan en castellano, como en archivos/paises.csv.
#   Para saber como se llama cada pais en castellano se le pregunta a la
#   misma Wikipedia: cada articulo en ingles tiene el link a su version en
#   castellano (API de Wikipedia, "langlinks"). Ej.:
#       en "Qatar"          -> es "Catar"
#       en "Czech Republic" -> es "Chequia"
#   Si el titulo en castellano no es igual al de paises.csv, se buscan sus
#   otros nombres (redirecciones de Wikipedia en castellano) y se toma el
#   que este en paises.csv.
#   Resultado: equivalencias_paises_2026.csv (nombre_externo;nombre_pais),
#   que importa imp.usp_Importar_EquivalenciasPais. La traduccion la usa
#   la base (imp.usp_BuscarPais) al importar sedes, partidos y plantillas.
# =====================================================================
API_EN = "https://en.wikipedia.org/w/api.php"
API_ES = "https://es.wikipedia.org/w/api.php"


def consultar_api(url, parametros):
    """Llama a la API de Wikipedia (JSON). Si la respuesta viene en partes
    ("continue"), pide las siguientes y junta las paginas."""
    parametros = dict(parametros, action="query", format="json", formatversion="2")
    query = {"normalized": [], "redirects": [], "pages": {}}
    while True:
        r = requests.get(url, params=parametros, headers=HEADERS, timeout=30)
        r.raise_for_status()
        time.sleep(1)                                   # pausa para no saturar a Wikipedia
        datos = r.json()
        q = datos.get("query", {})
        query["normalized"] += q.get("normalized", [])
        query["redirects"] += q.get("redirects", [])
        for p in q.get("pages", []):
            actual = query["pages"].setdefault(p["title"], {"langlinks": [], "redirects": []})
            actual["langlinks"] += p.get("langlinks", [])
            actual["redirects"] += p.get("redirects", [])
        if "continue" not in datos:
            return query
        parametros.update(datos["continue"])


def titulo_final(nombre, query):
    """Titulo real del articulo: aplica las correcciones de la API
    (mayusculas, redirecciones). Ej. 'Czech Republic' -> 'Czechia'."""
    normalizados = {x["from"]: x["to"] for x in query["normalized"]}
    redirecciones = {x["from"]: x["to"] for x in query["redirects"]}
    t = normalizados.get(nombre, nombre)
    return redirecciones.get(t, t)


def de_a_lotes(lista, tamanio):
    for i in range(0, len(lista), tamanio):
        yield lista[i:i + tamanio]


def leer_paises_csv(ruta):
    """Nombres de paises.csv (los que hay en cat.Pais). None si no esta el archivo."""
    if not ruta or not os.path.exists(ruta):
        return None
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        return {fila["nombre"].strip() for fila in csv.DictReader(f) if fila.get("nombre")}


def generar_equivalencias(plantillas, sedes, partidos, validos, carpeta):
    """Escribe equivalencias_paises_2026.csv con el nombre en castellano de
    cada pais que aparece en los tres archivos."""
    nombres = set()
    for f in plantillas:
        nombres.update([f[0], f[6]])        # seleccion y pais del club
    for f in sedes:
        nombres.add(f[0])                   # pais de la sede
    for f in partidos:
        nombres.update([f[7], f[8]])        # local y visitante
    nombres.discard("")
    # Los que ya estan igual en paises.csv (Argentina, Uruguay...) no necesitan equivalencia
    pendientes = sorted(n for n in nombres if validos is None or n not in validos)
    print(f"Equivalencias de paises: consultando Wikipedia para {len(pendientes)} nombres")

    # 1) ingles -> titulo del articulo en castellano
    en_castellano = {}
    for lote in de_a_lotes(pendientes, 50):
        q = consultar_api(API_EN, {"titles": "|".join(lote), "prop": "langlinks",
                                   "lllang": "es", "lllimit": "max", "redirects": 1})
        for n in lote:
            pagina = q["pages"].get(titulo_final(n, q), {})
            if pagina.get("langlinks"):
                en_castellano[n] = pagina["langlinks"][0]["title"]

    # 2) si ese titulo no esta en paises.csv, buscar entre sus otros nombres
    if validos is not None:
        a_revisar = sorted({t for t in en_castellano.values() if t not in validos})
        mejor = {}
        for lote in de_a_lotes(a_revisar, 20):
            q = consultar_api(API_ES, {"titles": "|".join(lote), "prop": "redirects",
                                       "rdlimit": "max", "redirects": 1})
            for t in lote:
                real = titulo_final(t, q)
                pagina = q["pages"].get(real, {})
                otros = [real] + [r["title"] for r in pagina.get("redirects", [])]
                encontrado = next((o for o in otros if o in validos), None)
                if encontrado:
                    mejor[t] = encontrado
        en_castellano = {n: mejor.get(t, t) for n, t in en_castellano.items()}

    # 3) escribir el archivo (solo las que sirven) y avisar las que no
    filas = []
    for n in pendientes:
        es = en_castellano.get(n)
        if es is None:
            avisos.append(f"Equivalencias: Wikipedia no tiene version en castellano de '{n}'.")
        elif validos is not None and es not in validos:
            avisos.append(f"Equivalencias: '{n}' es '{es}' en castellano, pero no esta en paises.csv "
                          f"(agregar el pais a paises.csv o esas filas van a dar 'pais desconocido').")
        else:
            filas.append([n, es])
    escribir_csv(os.path.join(carpeta, "equivalencias_paises_2026.csv"),
                 ["nombre_externo", "nombre_pais"], filas)


# Programa principal

def main():
    parser = argparse.ArgumentParser(description="Scraping de Wikipedia - Mundial 2026")
    parser.add_argument("--salida", default=r"C:\MundialDB", help="carpeta donde se dejan los CSV")
    parser.add_argument("--html", default=None,
                        help="(opcional) carpeta con las paginas ya guardadas como .html, para no descargarlas")
    parser.add_argument("--paises", default=None,
                        help="ruta de paises.csv (por defecto se busca en ..\\archivos\\ o en la carpeta de salida)")
    args = parser.parse_args()
    if args.paises is None:
        aqui = os.path.dirname(os.path.abspath(__file__))
        for candidato in (os.path.join(aqui, "..", "archivos", "paises.csv"),
                          os.path.join(aqui, "archivos", "paises.csv"),
                          os.path.join(args.salida, "paises.csv")):
            if os.path.exists(candidato):
                args.paises = os.path.abspath(candidato)
                break
    os.makedirs(args.salida, exist_ok=True)

    plantillas = scrapear_plantillas(args.html)
    escribir_csv(os.path.join(args.salida, "plantillas_2026.csv"),
                 ["seleccion", "dorsal", "posicion", "jugador", "fecha_nacimiento", "club", "pais_club"],
                 plantillas)

    sedes = scrapear_sedes(args.html)
    escribir_csv(os.path.join(args.salida, "sedes_2026.csv"),
                 ["pais", "ciudad", "estadio", "capacidad", "latitud", "longitud", "huso_horario"],
                 sedes)

    partidos = scrapear_partidos(args.html, sedes)
    escribir_csv(os.path.join(args.salida, "partidos_2026.csv"),
                 ["nro_partido", "fase", "grupo", "fecha", "hora_local", "estadio", "ciudad", "local",
                  "visitante", "goles_local", "goles_visitante", "penales_local", "penales_visitante",
                  "asistencia"],
                 partidos)

    escribir_csv(os.path.join(args.salida, "goles_2026.csv"),
                 ["nro_partido", "seleccion", "jugador", "minuto", "minuto_adicional", "tipo"],
                 goles_filas)

    # Equivalencias de paises (ingles -> castellano), consultando a Wikipedia
    validos = leer_paises_csv(args.paises)
    if validos is None:
        avisos.append("Equivalencias: no se encontro paises.csv (usar --paises con la ruta); "
                      "se escribe el titulo en castellano de Wikipedia sin controlarlo.")
    if args.html:
        avisos.append("Equivalencias: con --html no se consulta Wikipedia; no se genero el archivo.")
    else:
        generar_equivalencias(plantillas, sedes, partidos, validos, args.salida)

    if avisos:
        print("\nAVISOS (revisar):")
        for a in avisos:
            print("  -", a)
    print("\nListo. Ahora ejecutar en SSMS, en este orden:\n"
          "  imp.usp_ImportarPaises_CSV          (paises.csv, si no estaban)\n"
          "  imp.usp_Importar_EquivalenciasPais  (equivalencias_paises_2026.csv)\n"
          "  imp.usp_Importar_Sedes              (sedes_2026.csv)\n"
          "  imp.usp_Importar_Partidos           (partidos_2026.csv, 2026)\n"
          "  imp.usp_Importar_Plantillas         (plantillas_2026.csv, 2026)\n"
          "  imp.usp_Importar_Goles              (goles_2026.csv, 2026)")


if __name__ == "__main__":
    try:
        main()
    except requests.RequestException as e:
        sys.exit(f"No se pudo descargar una pagina: {e}")