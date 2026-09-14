#!/usr/bin/env bash
# Hook PostToolUse (Edit|Write): formata o arquivo alterado.
# prettier no arquivo alterado, só se estiver instalado no projeto.
# Recebe o JSON do hook via stdin. Nunca bloqueia (sempre exit 0).

f=$(node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);const t=j.tool_input||{};const r=j.tool_response||{};process.stdout.write(t.file_path||r.filePath||"")}catch(e){}})')

[ -n "$f" ] && [ -f "$f" ] || exit 0

case "$f" in
  *.ts|*.tsx|*.js|*.jsx|*.css|*.json|*.md)
    npx --no-install prettier --write "$f" >/dev/null 2>&1 || true
    ;;
esac

exit 0
