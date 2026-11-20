#!/bin/bash
# Copia los datos del repo a las carpetas que usan los scripts de SQL
mkdir -p /c/Mundial2026_Datos /c/MundialDB
cp archivos/* /c/Mundial2026_Datos/
cp archivos_scraping/* /c/MundialDB/
echo "Listo: datos copiados a C:\\Mundial2026_Datos y C:\\MundialDB"
