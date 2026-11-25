"""
ABM de Anunciantes (pub.Anunciante) - MundialDB
UNLaM - 3641 Bases de Datos Aplicada - Grupo 02

Aplicacion de escritorio (tkinter) para dar de Alta, Baja y Modificar
anunciantes. No escribe SQL de modificacion propio: invoca los stored
procedures del script 02_crear_sp_ABM.sql, asi que las validaciones
(nombre obligatorio, pais existente, nombre unico, marcas asociadas)
las sigue haciendo la base y la app solo muestra el mensaje del THROW.

Requisitos:  python -m pip install pyodbc
Uso:         python abm_anunciantes.py [--server localhost\\SQLEXPRESS]
                                       [--database MundialDB]
                                       [--user U --password P]
Sin --user se usa autenticacion de Windows.
"""

import argparse
import os
import re
import tkinter as tk
from tkinter import messagebox, ttk

import pyodbc


# ---------------------------------------------------------------------------
# Capa de datos
# ---------------------------------------------------------------------------

def elegir_driver():
    """Devuelve el driver ODBC de SQL Server mas nuevo que haya instalado."""
    preferidos = ["ODBC Driver 18 for SQL Server",
                  "ODBC Driver 17 for SQL Server",
                  "SQL Server"]
    instalados = pyodbc.drivers()
    for d in preferidos:
        if d in instalados:
            return d
    raise RuntimeError("No se encontro un driver ODBC para SQL Server.")


def mensaje_sql(error):
    """Limpia el texto de un error de pyodbc y deja solo el mensaje del THROW.

    pyodbc devuelve algo como
      [42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]
      usp_Anunciante_Alta: - Pais inexistente. (50341) (SQLExecDirectW)
    """
    texto = str(error.args[1]) if len(error.args) > 1 else str(error)
    texto = re.sub(r"\[[^\]]*\]", "", texto)            # quita los [..]
    texto = re.sub(r"\(\d+\)\s*\(SQL\w+\)\s*$", "", texto)  # quita (50341) (SQLExecDirectW)
    texto = texto.strip()
    # Cada validacion viene como " - ..."; se muestra una por renglon.
    return texto.replace(" - ", "\n - ")


class AnuncianteRepo:
    def __init__(self, server, database, user=None, password=None):
        partes = [f"DRIVER={{{elegir_driver()}}}",
                  f"SERVER={server}",
                  f"DATABASE={database}",
                  "TrustServerCertificate=yes"]
        if user:
            partes += [f"UID={user}", f"PWD={password or ''}"]
        else:
            partes.append("Trusted_Connection=yes")
        # autocommit: cada SP confirma por si mismo, igual que en SSMS.
        self.cn = pyodbc.connect(";".join(partes), autocommit=True, timeout=5)

    def paises(self):
        cur = self.cn.cursor()
        cur.execute("SELECT id_pais, nombre FROM cat.Pais ORDER BY nombre")
        return [(r.id_pais, r.nombre) for r in cur.fetchall()]

    def listar(self, filtro=""):
        cur = self.cn.cursor()
        cur.execute("""
            SELECT a.id_anunciante, a.nombre, a.id_pais, p.nombre AS pais,
                   (SELECT COUNT(*) FROM pub.Marca m
                     WHERE m.id_anunciante = a.id_anunciante) AS marcas
            FROM pub.Anunciante a
            LEFT JOIN cat.Pais p ON p.id_pais = a.id_pais
            WHERE a.nombre LIKE ?
            ORDER BY a.nombre""", f"%{filtro}%")
        return cur.fetchall()

    def alta(self, nombre, id_pais):
        self.cn.execute("EXEC pub.usp_Anunciante_Alta @nombre = ?, @id_pais = ?",
                        nombre, id_pais)

    def modificacion(self, id_anunciante, nombre, id_pais):
        self.cn.execute("EXEC pub.usp_Anunciante_Modificacion "
                        "@id_anunciante = ?, @nombre = ?, @id_pais = ?",
                        id_anunciante, nombre, id_pais)

    def baja(self, id_anunciante):
        self.cn.execute("EXEC pub.usp_Anunciante_Baja @id_anunciante = ?",
                        id_anunciante)


# ---------------------------------------------------------------------------
# Interfaz
# ---------------------------------------------------------------------------

class App(tk.Tk):
    def __init__(self, repo):
        super().__init__()
        self.repo = repo
        self.title("MundialDB - ABM de Anunciantes")
        self.geometry("720x460")
        self.minsize(600, 380)

        self.paises = repo.paises()
        self.pais_por_nombre = {n: i for i, n in self.paises}
        self.id_sel = None  # id del anunciante seleccionado en la grilla

        self._armar_busqueda()
        self._armar_grilla()
        self._armar_formulario()
        self.refrescar()

    # --- widgets -----------------------------------------------------------

    def _armar_busqueda(self):
        f = ttk.Frame(self, padding=(10, 10, 10, 0))
        f.pack(fill="x")
        ttk.Label(f, text="Buscar por nombre:").pack(side="left")
        self.var_filtro = tk.StringVar()
        e = ttk.Entry(f, textvariable=self.var_filtro, width=30)
        e.pack(side="left", padx=6)
        e.bind("<KeyRelease>", lambda _e: self.refrescar())
        ttk.Button(f, text="Refrescar", command=self.refrescar).pack(side="left")

    def _armar_grilla(self):
        f = ttk.Frame(self, padding=10)
        f.pack(fill="both", expand=True)
        cols = ("id", "nombre", "pais", "marcas")
        self.tree = ttk.Treeview(f, columns=cols, show="headings",
                                 selectmode="browse")
        for c, titulo, ancho, anchor in [("id", "ID", 50, "center"),
                                         ("nombre", "Nombre", 260, "w"),
                                         ("pais", "Pais", 200, "w"),
                                         ("marcas", "Marcas", 70, "center")]:
            self.tree.heading(c, text=titulo)
            self.tree.column(c, width=ancho, anchor=anchor)
        sb = ttk.Scrollbar(f, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=sb.set)
        self.tree.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        self.tree.bind("<<TreeviewSelect>>", self._al_seleccionar)

    def _armar_formulario(self):
        f = ttk.LabelFrame(self, text="Datos del anunciante", padding=10)
        f.pack(fill="x", padx=10, pady=(0, 10))

        ttk.Label(f, text="Nombre:").grid(row=0, column=0, sticky="w")
        self.var_nombre = tk.StringVar()
        ttk.Entry(f, textvariable=self.var_nombre, width=40).grid(
            row=0, column=1, sticky="we", padx=6, pady=2)

        ttk.Label(f, text="Pais:").grid(row=1, column=0, sticky="w")
        self.var_pais = tk.StringVar()
        ttk.Combobox(f, textvariable=self.var_pais, state="readonly", width=38,
                     values=[n for _i, n in self.paises]).grid(
            row=1, column=1, sticky="we", padx=6, pady=2)
        f.columnconfigure(1, weight=1)

        b = ttk.Frame(f)
        b.grid(row=0, column=2, rowspan=2, padx=(10, 0))
        ttk.Button(b, text="Alta", command=self.alta).grid(row=0, column=0, padx=2)
        ttk.Button(b, text="Modificar", command=self.modificar).grid(row=0, column=1, padx=2)
        ttk.Button(b, text="Baja", command=self.baja).grid(row=0, column=2, padx=2)
        ttk.Button(b, text="Limpiar", command=self.limpiar).grid(row=0, column=3, padx=2)

    # --- comportamiento ----------------------------------------------------

    def refrescar(self):
        self.tree.delete(*self.tree.get_children())
        for r in self.repo.listar(self.var_filtro.get().strip()):
            self.tree.insert("", "end", iid=str(r.id_anunciante),
                             values=(r.id_anunciante, r.nombre,
                                     r.pais or f"(id {r.id_pais})", r.marcas))

    def _al_seleccionar(self, _evento):
        sel = self.tree.selection()
        if not sel:
            return
        _id, nombre, pais, _marcas = self.tree.item(sel[0], "values")
        self.id_sel = int(_id)
        self.var_nombre.set(nombre)
        self.var_pais.set(pais if pais in self.pais_por_nombre else "")

    def limpiar(self):
        self.id_sel = None
        self.var_nombre.set("")
        self.var_pais.set("")
        self.tree.selection_remove(self.tree.selection())

    def _datos_formulario(self):
        # La validacion real la hace el SP; aca se pasa None si no hay pais
        # para que el SP responda "Pais inexistente".
        nombre = self.var_nombre.get().strip()
        id_pais = self.pais_por_nombre.get(self.var_pais.get())
        return nombre, id_pais

    def _ejecutar(self, accion, exito):
        try:
            accion()
        except pyodbc.Error as e:
            messagebox.showerror("Error", mensaje_sql(e))
            return
        self.limpiar()
        self.refrescar()
        messagebox.showinfo("OK", exito)

    def alta(self):
        nombre, id_pais = self._datos_formulario()
        self._ejecutar(lambda: self.repo.alta(nombre, id_pais),
                       f"Anunciante '{nombre}' dado de alta.")

    def modificar(self):
        if self.id_sel is None:
            messagebox.showwarning("Modificar", "Seleccione un anunciante de la lista.")
            return
        nombre, id_pais = self._datos_formulario()
        self._ejecutar(lambda: self.repo.modificacion(self.id_sel, nombre, id_pais),
                       "Anunciante modificado.")

    def baja(self):
        if self.id_sel is None:
            messagebox.showwarning("Baja", "Seleccione un anunciante de la lista.")
            return
        if not messagebox.askyesno("Baja", f"Eliminar el anunciante "
                                   f"'{self.var_nombre.get()}'?"):
            return
        self._ejecutar(lambda: self.repo.baja(self.id_sel),
                       "Anunciante eliminado.")


def main():
    p = argparse.ArgumentParser(description="ABM de pub.Anunciante (MundialDB)")
    p.add_argument("--server", default=os.getenv("MUNDIAL_SERVER", r"localhost\SQLEXPRESS"))
    p.add_argument("--database", default=os.getenv("MUNDIAL_DB", "MundialDB"))
    p.add_argument("--user", default=os.getenv("MUNDIAL_USER"))
    p.add_argument("--password", default=os.getenv("MUNDIAL_PASSWORD"))
    a = p.parse_args()

    try:
        repo = AnuncianteRepo(a.server, a.database, a.user, a.password)
    except (pyodbc.Error, RuntimeError) as e:
        tk.Tk().withdraw()
        messagebox.showerror("Conexion", f"No se pudo conectar a {a.server}/{a.database}:\n\n{e}")
        return
    App(repo).mainloop()


if __name__ == "__main__":
    main()
