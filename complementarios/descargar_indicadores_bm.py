"""
UNLaM - 3641 Bases de Datos Aplicada
TP: Sistema de Registro y Gestion del Mundial de Futbol
Entrega 6: Procesos de Importacion Masiva - Extraccion API World Bank
Grupo 02 - Comision 02-5600
Integrantes:
    - Mendez Camacho, Tatiana (tatimendez)
    - Rocha Escalera, Sheila Belisa (sheilarocha02)
    - Meira da Cruz Saleiro, Gonzalo (meiraGonzalo)

Objetivo:
    Conectarse a la API publica del Banco Mundial (World Bank API v2),
    consultar los indicadores de PBI per capita (NY.GDP.PCAP.CD) para todos 
    los paises del torneo con mecanismo de reintento ante timeouts
    y generar el archivo 'archivos/indicadores_bm.json'.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error

# Rutas relativas del proyecto
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "indicadores_bm.json")

INDICADOR_OBJETIVO = "NY.GDP.PCAP.CD"
RANGO_ANIOS = "2020:2025"

PAISES_MUNDIAL_ISO3 = [
    # Anfitriones
    "USA", "MEX", "CAN",
    # CONMEBOL
    "ARG", "BRA", "URY", "COL", "CHL", "ECU", "PRY", "PER", "VEN", "BOL",
    # UEFA
    "ESP", "FRA", "DEU", "ITA", "GBR", "NLD", "PRT", "BEL", "HRV", "DNK",
    "CHE", "SRB", "POL", "AUT", "SWE", "UKR", "TUR", "CZE",
    # CONCACAF
    "CRI", "PAN", "JAM", "HND",
    # CAF
    "MAR", "SEN", "EGY", "NGA", "DZA", "CMR", "TUN", "GHA", "ZAF",
    # AFC
    "JPN", "KOR", "AUS", "SAU", "QAT",
    # OFC
    "NZL"
]


def consultar_indicador_pais(codigo_iso3, indicador=INDICADOR_OBJETIVO, anios=RANGO_ANIOS, max_reintentos=3):
    """
    Consulta la API del Banco Mundial con reintentos y timeout de 30 segundos.
    """
    url = f"https://api.worldbank.org/v2/country/{codigo_iso3}/indicator/{indicador}?date={anios}&format=json&per_page=100"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "MundialDB-Import/1.0 (UNLaM-BDA)"}
    )

    for intento in range(1, max_reintentos + 1):
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                if response.status == 200:
                    contenido = response.read().decode("utf-8")
                    raw_data = json.loads(contenido)
                    
                    registros = []
                    if len(raw_data) > 1 and isinstance(raw_data[1], list):
                        for item in raw_data[1]:
                            valor = item.get("value")
                            if valor is not None:
                                pais_iso3 = item.get("countryiso3code") or codigo_iso3
                                anio_obs = int(item.get("date"))
                                indicador_id = item.get("indicator", {}).get("id", indicador)
                                valor_num = round(float(valor), 2)

                                registros.append({
                                    "REF_AREA": pais_iso3,
                                    "TIME_PERIOD": anio_obs,
                                    "INDICATOR": indicador_id,
                                    "OBS_VALUE": valor_num,
                                    "countryiso3code": pais_iso3,
                                    "date": anio_obs,
                                    "indicator": indicador_id,
                                    "value": valor_num
                                })
                    return registros
                return []
        except urllib.error.HTTPError as http_err:
            if http_err.code == 404:
                print(" [404 no encontrado]", end="", flush=True)
                return []
            print(f" [HTTP {http_err.code} intento {intento}]", end="", flush=True)
        except Exception as err:
            if intento < max_reintentos:
                print(f" [Timeout. Reintentando ({intento}/{max_reintentos})...]", end="", flush=True)
                time.sleep(2)
            else:
                print(f" [Fallo tras {max_reintentos} intentos: {err}]", end="", flush=True)
                return []
    return []


def extraer_indicadores():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("=" * 70)
    print(" EXTRACTOR DE INDICADORES ECONOMICOS - BANCO MUNDIAL (WORLD BANK)")
    print(f" Indicador: {INDICADOR_OBJETIVO} (PBI per capita US$)")
    print(f" Periodos : {RANGO_ANIOS}")
    print("=" * 70)
    print(f"[*] Paises a consultar: {len(PAISES_MUNDIAL_ISO3)}")
    print(f"[*] Destino: {OUTPUT_FILE}")
    print("----------------------------------------------------------------------")

    indicadores_totales = []
    paises_exitosos = 0
    paises_fallidos = []

    for codigo_iso3 in PAISES_MUNDIAL_ISO3:
        print(f" -> Consultando {codigo_iso3}...", end=" ", flush=True)
        datos_pais = consultar_indicador_pais(codigo_iso3)

        if datos_pais:
            indicadores_totales.extend(datos_pais)
            paises_exitosos += 1
            print(f" OK ({len(datos_pais)} registros)")
        else:
            paises_fallidos.append(codigo_iso3)
            print(" SIN DATOS")

        time.sleep(0.3)

    if not indicadores_totales:
        print("\n[ERROR] No se pudo obtener informacion para ningun pais.", file=sys.stderr)
        sys.exit(1)

    with open(OUTPUT_FILE, mode="w", encoding="utf-8") as f:
        json.dump(indicadores_totales, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 70)
    print("[OK] Proceso de extraccion finalizado")
    print(f"     -> Archivo generado : {OUTPUT_FILE}")
    print(f"     -> Paises con exito : {paises_exitosos} de {len(PAISES_MUNDIAL_ISO3)}")
    if paises_fallidos:
        print(f"     -> Paises sin datos : {', '.join(paises_fallidos)}")
    print(f"     -> Total registros  : {len(indicadores_totales)}")
    print("=" * 70)


if __name__ == "__main__":
    extraer_indicadores()