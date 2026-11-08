"""
UNLaM - 3641 Bases de Datos Aplicada
TP: Sistema de Registro y Gestion del Mundial de Futbol
Extraccion Comercial: Franjas Horarias y Tarifario de Publicidad (pub.FranjaHoraria y pub.Tarifa)
Salidas:
    - archivos/franjas_comerciales.csv (nombre,hora_desde,hora_hasta,es_prime_time)
    - archivos/tarifas.csv             (anio_torneo,fase,franja,monto,codigo_moneda)
"""

import os
import csv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "archivos"))
FRANJAS_CSV = os.path.join(OUTPUT_DIR, "franjas_comerciales.csv")
TARIFAS_CSV = os.path.join(OUTPUT_DIR, "tarifas.csv")

# 1. Catalogo de Franjas Horarias de transmision (cobertura 24 horas continuas)
# Cumple con CHECK / formato time(0) y bandera es_prime_time bit
FRANJAS_CATALOGO = [
    {
        "nombre": "Madrugada",
        "hora_desde": "00:00:00",
        "hora_hasta": "05:59:59",
        "es_prime_time": 0
    },
    {
        "nombre": "Mañana",
        "hora_desde": "06:00:00",
        "hora_hasta": "11:59:59",
        "es_prime_time": 0
    },
    {
        "nombre": "Tarde",
        "hora_desde": "12:00:00",
        "hora_hasta": "17:59:59",
        "es_prime_time": 0
    },
    {
        "nombre": "Prime Time",
        "hora_desde": "18:00:00",
        "hora_hasta": "23:59:59",
        "es_prime_time": 1
    }
]

# 2. Parametrizacion del Tarifario Comercial FIFA 2026
# Fases oficiales segun comp.Fase y anio segun comp.Torneo
ANIO_TORNEO = 2026
MONEDA_BASE = "USD"

FASES_TORNEO = [
    "Grupos",
    "Dieciseisavos",
    "Octavos",
    "Cuartos",
    "Semifinal",
    "Tercer puesto",
    "Final"
]

# Matriz base de tarifas en USD por fase del torneo y franja
# Refleja el incremento de audiencia por instancia y horario estelar
TARIFAS_BASE_USD = {
    "Grupos": {
        "Madrugada": 15000.00,
        "Mañana": 25000.00,
        "Tarde": 35000.00,
        "Prime Time": 50000.00
    },
    "Dieciseisavos": {
        "Madrugada": 20000.00,
        "Mañana": 30000.00,
        "Tarde": 42000.00,
        "Prime Time": 60000.00
    },
    "Octavos": {
        "Madrugada": 25000.00,
        "Mañana": 38000.00,
        "Tarde": 52000.00,
        "Prime Time": 75000.00
    },
    "Cuartos": {
        "Madrugada": 35000.00,
        "Mañana": 50000.00,
        "Tarde": 70000.00,
        "Prime Time": 100000.00
    },
    "Semifinal": {
        "Madrugada": 50000.00,
        "Mañana": 75000.00,
        "Tarde": 105000.00,
        "Prime Time": 150000.00
    },
    "Tercer puesto": {
        "Madrugada": 40000.00,
        "Mañana": 60000.00,
        "Tarde": 85000.00,
        "Prime Time": 120000.00
    },
    "Final": {
        "Madrugada": 80000.00,
        "Mañana": 120000.00,
        "Tarde": 180000.00,
        "Prime Time": 250000.00
    }
}


def exportar_franjas_y_tarifas():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Escribir archivos/franjas_comerciales.csv
    print(f"[*] Exportando franjas horarias en: {FRANJAS_CSV}")
    with open(FRANJAS_CSV, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        # Cabecera exacta para imp.vw_stg_FranjaHoraria_carga
        writer.writerow(["nombre", "hora_desde", "hora_hasta", "es_prime_time"])
        for fh in FRANJAS_CATALOGO:
            writer.writerow([fh["nombre"], fh["hora_desde"], fh["hora_hasta"], fh["es_prime_time"]])

    # 2. Escribir archivos/tarifas.csv
    print(f"[*] Exportando tarifas comerciales en: {TARIFAS_CSV}")
    total_tarifas = 0
    with open(TARIFAS_CSV, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        # Cabecera exacta para imp.vw_stg_Tarifa_carga
        writer.writerow(["anio_torneo", "fase", "franja", "monto", "codigo_moneda"])

        for fase in FASES_TORNEO:
            franjas_fase = TARIFAS_BASE_USD.get(fase, {})
            for franja, monto in franjas_fase.items():
                writer.writerow([
                    ANIO_TORNEO,
                    fase,
                    franja,
                    f"{monto:.2f}",
                    MONEDA_BASE
                ])
                total_tarifas += 1

    print("\n" + "=" * 65)
    print("[OK] Generacion comercial completada exitosamente:")
    print(f"     -> Franjas horarias : {len(FRANJAS_CATALOGO)} filas en {FRANJAS_CSV}")
    print(f"     -> Tarifas cruzadas : {total_tarifas} combinaciones en {TARIFAS_CSV}")
    print("=" * 65)


if __name__ == "__main__":
    exportar_franjas_y_tarifas()