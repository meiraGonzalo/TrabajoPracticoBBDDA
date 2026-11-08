"""
UNLaM - 3641 Bases de Datos Aplicada
TP: Sistema de Registro y Gestion del Mundial de Futbol
Entrega 6: Procesos de Importacion Masiva - Extraccion API Frankfurter
Grupo 02 - Comision 02-5600
Integrantes:
    - Mendez Camacho, Tatiana (tatimendez)
    - Rocha Escalera, Sheila Belisa (sheilarocha02)
    - Meira da Cruz Saleiro, Gonzalo (meiraGonzalo)

Objetivo:
    Conectarse a la API publica de Frankfurter, obtener las cotizaciones
    de tipo de cambio y generar el archivo CSV en la carpeta 'archivos/'
    con el formato exacto requerido por imp.vw_stg_TipoCambio_carga:
    (fecha, moneda_base, moneda_cotizada, tasa).
"""

import os
import sys
import csv
import urllib.request
import json

# Definicion de rutas relativas basadas en la estructura del proyecto
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Directorio de salida: ../archivos
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "tipos_cambio_frankfurter.csv")

# Parametros de configuracion
BASE_CURRENCY = "USD"
# Rango para el periodo del Mundial 2026
START_DATE = "2026-01-01"
END_DATE = "2026-06-30"

# Rango historico de respaldo por si el periodo 2026 aun no posee cotizaciones publicadas
FALLBACK_START_DATE = "2024-01-01"
FALLBACK_END_DATE = "2024-06-30"


def obtener_datos(url):
    """Realiza la solicitud HTTP GET utilizando la libreria estandar urllib."""
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "MundialDB-Import/1.0"}
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        if response.status == 200:
            return response.read().decode("utf-8")
        else:
            raise Exception(f"HTTP Status {response.status}")


def exportar_csv_desde_api():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[*] Conectando con la API de Frankfurter...")

    # Intentamos primero con el rango objetivo del 2026
    url = f"https://api.frankfurter.dev/v1/{START_DATE}..{END_DATE}?base={BASE_CURRENCY}"
    
    try:
        try:
            print(f"[*] Consultando cotizaciones periodo {START_DATE} a {END_DATE} (Base: {BASE_CURRENCY})...")
            payload = obtener_datos(url)
            data = json.loads(payload)
            if not data.get("rates"):
                raise ValueError("Sin tasas para el periodo 2026.")
        except Exception as e_2026:
            print(f"[!] Aviso: No se obtuvieron datos para 2026 ({e_2026}).")
            print(f"[*] Usando rango historico de respaldo ({FALLBACK_START_DATE} a {FALLBACK_END_DATE})...")
            url = f"https://api.frankfurter.dev/v1/{FALLBACK_START_DATE}..{FALLBACK_END_DATE}?base={BASE_CURRENCY}"
            payload = obtener_datos(url)
            data = json.loads(payload)

        base = data.get("base", BASE_CURRENCY)
        rates_by_date = data.get("rates", {})

        total_filas = 0
        # Escritura del CSV garantizando UTF-8 y saltos de linea estandar para SQL Server BULK INSERT
        with open(OUTPUT_FILE, mode="w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL)
            # Cabecera exacta que mapea con imp.vw_stg_TipoCambio_carga
            writer.writerow(["fecha", "moneda_base", "moneda_cotizada", "tasa"])

            for fecha in sorted(rates_by_date.keys()):
                cotizaciones = rates_by_date[fecha]
                for moneda_cotizada, valor in sorted(cotizaciones.items()):
                    # Formateo decimal con punto estricto y 6 decimales para DECIMAL(18,6)
                    tasa_formateada = f"{float(valor):.6f}"
                    writer.writerow([fecha, base, moneda_cotizada, tasa_formateada])
                    total_filas += 1

        print(f"[OK] Archivo generado exitosamente:")
        print(f"     -> Ruta: {OUTPUT_FILE}")
        print(f"     -> Registros generados: {total_filas}")

    except Exception as err:
        print(f"[ERROR] No se pudo completar la extraccion de Frankfurter: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    exportar_csv_desde_api()
