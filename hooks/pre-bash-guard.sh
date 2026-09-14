#!/usr/bin/env bash
# Hook PreToolUse (Bash): protege operações de risco.
# - push --force em main/master/develop: bloqueado sempre
# - demais operações destrutivas: pedem confirmação do usuário (prompt)
# - qualquer git push: pede permissão do usuário (aviso reforçado em main/master)
# - git add . / -A / --all: bloqueado (adicionar arquivos específicos)
# Recebe o JSON do hook via stdin.

cmd=$(node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write((j.tool_input&&j.tool_input.command)||"")}catch(e){}})')
[ -n "$cmd" ] || exit 0

block() { echo "BLOQUEADO: $1" >&2; exit 2; }
ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}' "$1"
  exit 0
}

is_push=0
printf '%s' "$cmd" | grep -qE '\bgit\s+push\b' && is_push=1

if [ "$is_push" = 1 ] \
  && printf '%s' "$cmd" | grep -qE '(--force(-with-lease)?|-f)\b' \
  && printf '%s' "$cmd" | grep -qiE '\b(main|master|develop)\b'; then
  block "push --force em main/master/develop nunca é permitido."
fi

if printf '%s' "$cmd" | grep -qiE 'push\s+--force|push\s+-f\b|reset\s+--hard|rm\s+-rf|\bDROP\s+(TABLE|DATABASE)\b|\bTRUNCATE\b|\bDELETE\s+FROM\b'; then
  ask "Operação destrutiva detectada. Confirme antes de executar."
fi

if printf '%s' "$cmd" | grep -qE '\bgit\s+add\s+(\.|-A|--all)(\s|$)'; then
  block "git add . / git add -A não permitido. Adicione arquivos específicos."
fi

if printf '%s' "$cmd" | grep -qE '\bgit\s+add\b'; then
  sensivel=$(printf '%s' "$cmd" | tr ' ' '\n' | grep -E '((^|/)\.env(\.[A-Za-z0-9_-]+)?|\.(pem|key|pfx|p12)|(^|/)id_rsa[A-Za-z0-9._-]*|(^|/)credentials\.json)$' | grep -vE '\.env\.example$' | head -3 | tr '\n' ' ')
  if [ -n "$sensivel" ]; then
    block "arquivo sensível no git add: $sensivel. Nunca commitar segredos (.env, chaves, certificados). Use .env.example com valores fictícios."
  fi
fi

if printf '%s' "$cmd" | grep -qE '\bgit\s+rebase\b'; then
  ask "git rebase reescreve histórico. Requer permissão explícita do usuário."
fi

if [ "$is_push" = 1 ]; then
  if printf '%s' "$cmd" | grep -qiE '\b(main|master)\b'; then
    ask "ATENÇÃO: push envolvendo main/master. Confirme explicitamente."
  fi
  ask "Push requer permissão explícita do usuário."
fi

exit 0
