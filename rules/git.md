# Regras de Git - Workflow e Convenções

## Estratégia de Branches

```text
main            # Produção - sempre estável
├── develop     # Desenvolvimento - integração contínua
│   ├── feature/*   # Novas funcionalidades
│   ├── fix/*       # Correções de bugs
│   ├── refactor/*  # Refatorações
│   ├── chore/*     # Tarefas técnicas (deps, configs, CI)
│   └── release/*   # Preparação de release
```

- `main`: código em produção. Nunca commitar direto.
- `develop`: branch de integração. Merge via PR.
- Branches de trabalho sempre criadas a partir de `develop`.

## Nomes de Branch

- Formato: `<tipo>/<short-description>` em inglês e `kebab-case`.
- Exemplos: `feature/user-registration`, `fix/login-redirect`, `refactor/split-services`.
- Nunca espaços, acentos ou caracteres especiais.
- Nunca branches genéricas como `teste`, `temp`, `nova-branch`.

## Commits - Conventional Commits

Formato, idioma, tipos, crases, tamanho e exemplos moram em `~/.claude/commands/commit.md`, fonte única. Usar `/commit` para gerar o commit; o hook `pre-commit-msg-guard.sh` barra mensagem fora do padrão.

## Pull Requests

- Título em inglês, curto e descritivo (máximo 70 caracteres). Descrição do PR em português.
- Descrição com: o que foi feito, por que, como testar.
- PR sempre de branch de trabalho → `develop`.
- `develop` → `main` apenas para releases.
- Nunca fazer merge sem build passando.

## Regras Gerais

- Nunca `git push --force` em `main` ou `develop`.
- Nunca commitar sem confirmar a branch com o usuário. Nunca dar `git push`, `commit --amend` ou `git rebase` sem permissão explícita.
- Antes de todo commit, mostrar no chat a mensagem completa e a lista de arquivos daquele commit. Em múltiplos commits, mostrar por commit.
- Nunca commitar arquivos grandes (binários, dumps, node_modules, bin/obj).
- Sempre verificar `git status` antes de commitar.
- Resolver conflitos antes de abrir PR - nunca fazer merge com conflitos.
- Para regras de `.env`, secrets e permissões de commit ver `CLAUDE.md`.
