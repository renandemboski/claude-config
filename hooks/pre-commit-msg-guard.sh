#!/usr/bin/env bash
# Hook PreToolUse (Bash): valida mensagens de git commit contra o padrão do
# /commit (parte determinística). A validação semântica completa (idioma,
# formato Conventional Commits, 72 chars) é feita pelo prompt hook no
# settings.json. Recebe o JSON do hook via stdin.

cmd=$(node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write((j.tool_input&&j.tool_input.command)||"")}catch(e){}})')

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

block() { echo "BLOQUEADO: $1" >&2; exit 2; }

case "$cmd" in
  "git commit"*) ;;
  *) block "rode o git commit como comando isolado, sem encadear com outros comandos." ;;
esac

if printf '%s' "$cmd" | grep -q -- '--no-verify'; then
  block "nunca usar --no-verify em commits."
fi

if printf '%s' "$cmd" | grep -qi 'co-authored-by'; then
  block "não incluir Co-Authored-By na mensagem de commit."
fi

emdash=$(printf '\xe2\x80\x94')
case "$cmd" in
  *"$emdash"*) block "travessão na mensagem de commit. Use hífen com espaços, vírgula ou dois-pontos." ;;
esac

# Remove trechos entre crases (identificadores de codigo) e o escopo entre
# parenteses antes de checar o idioma da descricao.
msg=$(printf '%s' "$cmd" | sed 's/`[^`]*`//g; s/([a-z0-9-]*)//g')

if printf '%s' "$msg" | grep -qwiE 'adicionar|corrigir|criar|remover|atualizar|ajustar|alterar|extrair|renomear|mover|implementar|refatorar|melhorar|validacao|validar|usuario|usuarios|pagina|paginas|funcao|codigo|banco|tela|arquivo|arquivos|configuracao|mensagem|campo|campos|botao|erro|erros'; then
  block "mensagem de commit em portugues. Escreva em ingles, no imperativo presente (add, fix, remove, update, extract)."
fi

# Verbo no passado ou terceira pessoa quebra o imperativo presente.
if printf '%s' "$msg" | grep -qE ':[[:space:]]+(added|fixed|removed|updated|created|changed|refactored|renamed|moved|adds|fixes|removes|updates|creates|changes)\b'; then
  block "verbo fora do imperativo presente. Use add, fix, remove, update (nao added, fixes)."
fi

# Mensagem válida: pede confirmação do usuário mostrando branch, arquivos
# staged e alerta de possível segredo. A mensagem do commit aparece no
# próprio comando exibido pelo prompt de permissão.
branch=$(git branch --show-current 2>/dev/null | tr -cd 'A-Za-z0-9._/-')
[ -n "$branch" ] || branch="fora de um repositório git"

files=$(git diff --cached --name-only 2>/dev/null | head -15 | tr -d '"\\' | tr '\n' '|' | sed 's/|$//; s/|/, /g')
total=$(git diff --cached --name-only 2>/dev/null | grep -c .)
if [ "$total" -gt 15 ] 2>/dev/null; then
  files="$files e mais $((total - 15)) arquivo(s)"
fi
[ -n "$files" ] || files="nada staged"

# Varredura de secrets no diff staged (linhas adicionadas).
q="'"
SECRET_RE="(password|passwd|senha|pwd)[[:space:]]*[:=][[:space:]]*[\"$q][^\"$q]{4,}|(api[_-]?key|apikey|client[_-]?secret|access[_-]?token)[[:space:]]*[:=][[:space:]]*[\"$q][A-Za-z0-9]|(password|senha|pwd)=[^;\"$q\$[:space:]]{4,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-"
alerta=""
staged=$(git diff --cached 2>/dev/null | grep '^+' | grep -v '^+++')
if [ -n "$staged" ] && printf '%s' "$staged" | grep -qiE "$SECRET_RE"; then
  alerta="ATENÇÃO: possível segredo no diff staged (senha, API key, token ou chave privada). Revise antes de aprovar. "
fi

amend=""
case "$cmd" in
  *--amend*) amend="ATENÇÃO: --amend reescreve o último commit. Só aprove se você autorizou o amend. " ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s%sCommit na branch: %s. Arquivos: %s."}}' "$amend" "$alerta" "$branch" "$files"
exit 0
