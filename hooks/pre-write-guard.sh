#!/usr/bin/env bash
# Hook PreToolUse (Edit|Write): bloqueia gravar travessao (U+2014) ou emoji
# em qualquer arquivo. Ignora trechos entre crases, que sao citacao do
# caractere (ex: a propria regra no CLAUDE.md). Recebe o JSON via stdin.

node -e '
let d = "";
process.stdin.on("data", c => d += c).on("end", () => {
  let j;
  try { j = JSON.parse(d); } catch { process.exit(0); }
  const ti = j.tool_input || {};
  const file = ti.file_path || "";
  if (/node_modules|[\\/]dist[\\/]|\.lock$|-lock\.json$|\.min\./.test(file)) process.exit(0);

  const text = ti.new_string ?? ti.content ?? "";
  if (!text) process.exit(0);

  const semCrase = text.replace(/`[^`\n]*`/g, "");
  const emoji = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}\u{2B55}]/u;
  const linhas = semCrase.split("\n");
  const problemas = [];

  const comTravessao = linhas.find(l => l.includes("—"));
  if (comTravessao) problemas.push("travessao em: " + comTravessao.trim().slice(0, 80));

  const comEmoji = linhas.find(l => emoji.test(l));
  if (comEmoji) problemas.push("emoji em: " + comEmoji.trim().slice(0, 80));

  if (problemas.length) {
    process.stderr.write(
      "BLOQUEADO: " + problemas.join(" | ") +
      ". Regra do CLAUDE.md: sem travessao (use hifen com espacos, virgula ou dois-pontos) e sem emoji em nenhum arquivo. Reescreva o trecho e grave de novo.\n"
    );
    process.exit(2);
  }
  process.exit(0);
});
'
