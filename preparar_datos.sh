#!/bin/bash
# Copia los datos del repo a las carpetas que usan los scripts de SQL.
# Los archivos de archivos/ se copian con fin de linea LF (los SP de catalogos lo esperan),
# sin importar como los haya dejado git en cada PC. Los de archivos_scraping/ se copian tal cual (CRLF).
mkdir -p /c/Mundial2026_Datos /c/MundialDB
for f in archivos/*; do
  tr -d '\r' < "$f" > "/c/Mundial2026_Datos/$(basename "$f")"
done
cp archivos_scraping/* /c/MundialDB/
echo "Listo: datos copiados a C:\\Mundial2026_Datos (LF) y C:\\MundialDB"
