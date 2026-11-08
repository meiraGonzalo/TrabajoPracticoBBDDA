"""
UNLaM - 3641 Bases de Datos Aplicada
TP: Sistema de Registro y Gestion del Mundial de Futbol
Entrega 6: Procesos de Importacion Masiva - Extraccion API Nager.Date
Grupo 02 - Comision 02-5600
Integrantes:
    - Mendez Camacho, Tatiana (tatimendez)
    - Rocha Escalera, Sheila Belisa (sheilarocha02)
    - Meira da Cruz Saleiro, Gonzalo (meiraGonzalo)

Objetivo:
    Conectarse a la API publica de Nager.Date (v3), consultar los feriados 
    oficiales del anio 2026 para todos los paises del torneo (anfitriones,
    selecciones participantes y mercados publicitarios cargados en cat.Pais)
    y generar el archivo 'archivos/feriados_nagerdate.json' tal cual como
    es provisto por la API para su posterior procesamiento con OPENJSON 
    en imp.usp_ImportarFeriados_JSON.
"""

import os
import sys
import json
import urllib.request
import urllib.error

# Definicion de rutas relativas segun la estructura del proyecto
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Directorio de salida: ../archivos
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "feriados_nagerdate.json")

# Configuracion de anio
ANIO_MUNDIAL = 2026

# Listado representativo de paises del Mundial 2026 (ISO 3166-1 alpha-2)
# Incluye anfitriones, selecciones clasificadas/competidoras y mercados publicitarios
PAISES_MUNDIAL_ISO2 = [
    # Anfitriones
    "US",  # Estados Unidos
    "MX",  # Mexico
    "CA",  # Canada

    # CONMEBOL
    "AR",  # Argentina
    "BR",  # Brasil
    "UY",  # Uruguay
    "CO",  # Colombia
    "CL",  # Chile
    "EC",  # Ecuador
    "PY",  # Paraguay
    "PE",  # Peru
    "VE",  # Venezuela
    "BO",  # Bolivia

    # UEFA
    "ES",  # Espana
    "FR",  # Francia
    "DE",  # Alemania
    "IT",  # Italia
    "GB",  # Reino Unido / Inglaterra
    "NL",  # Paises Bajos
    "PT",  # Portugal
    "BE",  # Belgica
    "HR",  # Croacia
    "DK",  # Dinamarca
    "CH",  # Suiza
    "RS",  # Serbia
    "PL",  # Polonia
    "AT",  # Austria
    "SE",  # Suecia
    "UA",  # Ucrania
    "TR",  # Turquia
    "CZ",  # Chequia

    # CONCACAF
    "CR",  # Costa Rica
    "PA",  # Panama
    "JM",  # Jamaica
    "HN",  # Honduras

    # CAF (Africa)
    "MA",  # Marruecos
    "SN",  # Senegal
    "EG",  # Egipto
    "NG",  # Nigeria
    "DZ",  # Argelia
    "CM",  # Camerun
    "TN",  # Tunez
    "GH",  # Ghana
    "ZA",  # Sudafrica

    # AFC (Asia)
    "JP",  # Japon
    "KR",  # Corea del Sur
    "AU",  # Australia
    "SA",  # Arabia Saudita
    "QA",  # Catar

    # OFC (Oceania)
    "NZ"   # Nueva Zelanda
]


def consultar_feriados_api(anio, codigo_iso):
    """
    Realiza la peticion GET al endpoint oficial v3 de Nager.Date:
    https://date.nager.at/api/v3/PublicHolidays/{Year}/{CountryCode}
    Devuelve los objetos tal como son provistos por la API.
    """
    url = f"https://date.nager.at/api/v3/PublicHolidays/{anio}/{codigo_iso}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "MundialDB-Import/1.0 (UNLaM-BDA)"}
    )

    try:
        with urllib.request.urlopen(req, timeout=12) as response:
            if response.status == 200:
                contenido = response.read().decode("utf-8")
                return json.loads(contenido)
            return []
    except urllib.error.HTTPError as http_err:
        if http_err.code == 404:
            print(f"      [!] 404: Sin registros para {codigo_iso} en el anio {anio}.")
        else:
            print(f"      [!] HTTP {http_err.code} al consultar {codigo_iso}.")
        return []
    except Exception as err:
        print(f"      [!] Error de conexion consultando {codigo_iso}: {err}")
        return []


def extraer_feriados():
    """
    Itera por los paises objetivo, consolida los feriados crudos de la API
    y guarda la coleccion completa en formato JSON sin alterar su estructura.
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("=" * 70)
    print(f" EXTRACTOR DE FERIADOS NAGER.DATE - MUNDIAL {ANIO_MUNDIAL}")
    print("=" * 70)
    print(f"[*] Paises configurados para consulta: {len(PAISES_MUNDIAL_ISO2)}")
    print(f"[*] Directorio de destino: {OUTPUT_DIR}")
    print("----------------------------------------------------------------------")

    feriados_totales = []
    paises_exitosos = 0

    for codigo_iso in PAISES_MUNDIAL_ISO2:
        print(f" -> Consultando feriados de {codigo_iso}...", end=" ", flush=True)
        datos = consultar_feriados_api(ANIO_MUNDIAL, codigo_iso)
        
        if datos:
            # Los registros se agregan respetando estrictamente las propiedades
            # nativas: date, localName, name, countryCode, fixed, global, counties, etc.
            feriados_totales.extend(datos)
            paises_exitosos += 1
            print(f"OK ({len(datos)} feriados)")
        else:
            print("SIN DATOS")

    if not feriados_totales:
        print("\n[ERROR] No se pudo obtener informacion de feriados para ningun pais.", file=sys.stderr)
        sys.exit(1)

    # Escritura del archivo JSON preservando la codificacion UTF-8 exacta
    with open(OUTPUT_FILE, mode="w", encoding="utf-8") as f:
        json.dump(feriados_totales, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 70)
    print("[OK] Proceso de extraccion finalizado exitosamente")
    print(f"     -> Archivo generado : {OUTPUT_FILE}")
    print(f"     -> Paises procesados: {paises_exitosos} de {len(PAISES_MUNDIAL_ISO2)}")
    print(f"     -> Total de feriados: {len(feriados_totales)}")
    print("=" * 70)


if __name__ == "__main__":
    extraer_feriados()
