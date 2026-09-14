#!/usr/bin/env python3
"""Apaga a transcricao das sessoes arquivadas na extensao do VSCode.

Arquivar so esconde o chat: o id entra em hiddenSessionIds dentro do state.vscdb
do VSCode, e o .jsonl continua ocupando espaco em ~/.claude/projects/.
"""
import glob
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import time

HOME = os.path.expanduser("~")
STATE = os.path.join(os.environ.get("APPDATA", ""), "Code", "User", "globalStorage", "state.vscdb")
PROJETOS = os.path.join(HOME, ".claude", "projects")
PROTEGIDOS = os.path.join(HOME, ".claude", "hooks", "nao-apagar.txt")
LOG = os.path.join(HOME, ".claude", "apagar-sessoes-arquivadas.log")
CARIMBO = os.path.join(HOME, ".claude", ".last-apagar-arquivadas")

DRY = "--dry-run" in sys.argv
HOOK = "--hook" in sys.argv
LISTAR = "--listar" in sys.argv
THROTTLE_S = 300
OCIOSO_MIN = 10


def log(msg):
    linha = time.strftime("%d/%m %H:%M") + "  " + msg
    if not HOOK or LISTAR:
        print(linha)
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(linha + "\n")


def ids_arquivados():
    tmp = os.path.join(tempfile.gettempdir(), "claude_state_ro.vscdb")
    shutil.copy(STATE, tmp)
    con = sqlite3.connect(tmp)
    try:
        linha = con.execute(
            "select value from ItemTable where key='Anthropic.claude-code'"
        ).fetchone()
    finally:
        con.close()
        os.unlink(tmp)
    if not linha:
        return []
    return json.loads(linha[0]).get("hiddenSessionIds", [])


def ids_protegidos():
    protegidos = set()
    if os.path.exists(PROTEGIDOS):
        with open(PROTEGIDOS, encoding="utf-8") as fh:
            for linha in fh:
                valor = linha.split("#")[0].strip()
                if valor:
                    protegidos.add(valor.lower())
    # a sessao que disparou o hook nunca e apagada
    if HOOK and not sys.stdin.isatty():
        try:
            atual = json.loads(sys.stdin.read() or "{}").get("session_id")
            if atual:
                protegidos.add(atual.lower())
        except (ValueError, OSError):
            pass
    return protegidos


def alvos(sid):
    for jsonl in glob.glob(os.path.join(PROJETOS, "*", sid + ".jsonl")):
        yield jsonl
        pasta = jsonl[: -len(".jsonl")]
        if os.path.isdir(pasta):
            yield pasta


def main():
    if HOOK and os.path.exists(CARIMBO) and time.time() - os.path.getmtime(CARIMBO) < THROTTLE_S:
        return 0
    if not os.path.exists(STATE):
        log("state.vscdb nao encontrado em " + STATE)
        return 0
    open(CARIMBO, "a").close()
    os.utime(CARIMBO, None)

    protegidos = ids_protegidos()
    apagados, bytes_livres, mantidos = 0, 0, []
    for sid in ids_arquivados():
        alvo = list(alvos(sid))
        if not alvo:
            continue
        if sid.lower() in protegidos or sid[:8].lower() in protegidos:
            mantidos.append(sid[:8] + " (protegido)")
            continue
        idade_min = (time.time() - max(os.path.getmtime(p) for p in alvo)) / 60
        if idade_min < OCIOSO_MIN:
            mantidos.append(sid[:8] + f" (ativo ha {idade_min:.0f} min)")
            continue
        for p in alvo:
            tamanho = os.path.getsize(p) if os.path.isfile(p) else 0
            if LISTAR or DRY:
                log(f"apagaria {os.path.basename(p)} ({tamanho / 1e6:.2f} MB)")
            else:
                shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
            bytes_livres += tamanho
        apagados += 1

    verbo = "apagaria" if (DRY or LISTAR) else "apagou"
    if apagados or mantidos:
        log(f"{verbo} {apagados} sessao(oes) arquivada(s), {bytes_livres / 1e6:.1f} MB"
            + (" | mantidas: " + ", ".join(mantidos) if mantidos else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
