---
description: Criar commits no padrão Conventional Commits em inglês, confirmando branch, arquivos e mensagem com o usuário. Usar sempre que o usuário pedir para commitar ou quando houver mudanças prontas para commit.
---

# /commit - Commit Padronizado

Criar commits seguindo Conventional Commits, mensagem em **inglês**, com validação pre-commit.

## Regras

- **OBRIGATÓRIO:** mensagem **curta**, uma linha só. Corpo é exceção rara e tem no máximo 4 linhas.
- **OBRIGATÓRIO:** mensagem em **inglês**, no imperativo presente: `add`, `fix`, `remove`, `update`, `extract`. Nunca passado (`added`) nem terceira pessoa (`adds`).
- **OBRIGATÓRIO:** mensagem **toda em minúsculo**, exceto:
  - Siglas com capitalização própria: `API`, `JWT`, `HTTP`, `HTTPS`, `SQL`, `UUID`, `URL`, `CSS`, `HTML`, `CRUD`, `CORS`, `JSON`, `OAuth`.
  - Nomes próprios de tecnologia: `React`, `Next.js`, `Tailwind`, `Prisma`, `Auth.js`, `Zod`, `PostgreSQL`, `Docker`, `GitHub`, `TypeScript`, `Node.js`.
  - Primeira letra da descrição: **minúscula** (`feat: add...`, não `feat: Add...`).
- **OBRIGATÓRIO:** envolver em **crases** (`` ` ` ``) coisas técnicas que vão direto pro código. Isso distingue "código" de "texto comum" e melhora a leitura do commit.

  | Caso | Exemplo |
  |--|--|
  | Nome de função | ``feat: add `useAuth()` hook`` |
  | Nome de arquivo | ``fix: correct build in `Dockerfile` `` |
  | Comando | ``docs: explain `npm install` `` |
  | Variável/config | ``chore: update `MAX_RETRIES` `` |
  | Endpoint | ``feat: add `GET /users` `` |
  | Tipo/componente | ``refactor: rename `UserDto` to `UserResponse` `` |
  | Caminho de pasta | ``chore: move files to `src/lib/auth/` `` |
- **NUNCA** commitar sem permissão explícita do usuário
- **NUNCA** commitar sem confirmar a branch: mostrar a branch atual e perguntar se o commit é nela, em outra existente ou em uma nova criada a partir de `develop`
- **NUNCA** dar `git push` sem permissão explícita do usuário, especialmente envolvendo `main`/`master`
- **NUNCA** incluir `Co-Authored-By` na mensagem
- **NUNCA** usar `--no-verify` ou pular hooks
- **NUNCA** fazer `git add .` ou `git add -A`, adicionar arquivos específicos
- **NUNCA** fazer amend ou rebase sem permissão explícita
- **SEMPRE** apresentar no chat a mensagem completa e a lista de arquivos antes de executar cada commit (passo 5), mesmo em commits pequenos. Em múltiplos commits, apresentar cada um separadamente
- **NUNCA** usar travessão (`—`) na mensagem, use hífen com espaços (` - `), vírgula ou dois-pontos

## Fluxo de Branches - GitFlow

| Branch | Uso |
|--------|-----|
| `main` | Produção estável |
| `develop` | Integração de features |
| `feature/*` | Nova funcionalidade |
| `fix/*` | Correção de bug |
| `refactor/*` | Refatoração sem mudar comportamento |
| `chore/*` | Tarefas técnicas (deps, configs, CI) |
| `release/*` | Preparação de release |

Nome da branch em inglês e `kebab-case`: `feature/user-registration`, `fix/login-redirect`.

## Processo

### 1. Analisar mudanças

Rodar em paralelo:
- `git status` - ver arquivos modificados e não-tracked
- `git diff` - ver mudanças staged e unstaged
- `git log --oneline -5` - ver últimos commits para manter consistência
- `git branch --show-current` - ver a branch atual (confirmada com o usuário no passo 5)

### 2. Validação pre-commit

Rodar:
- `npx tsc --noEmit`
- `npm run lint`
- `npm run build`

Se houver erros: corrigir ANTES de commitar. Warnings são bugs.

### 3. Classificar mudanças

Analisar o diff e classificar no tipo correto:

| Tipo | Quando usar | Exemplo |
|------|-------------|---------|
| `feat` | Nova funcionalidade | ``feat: add login validation to `LoginForm` `` |
| `fix` | Correção de bug | ``fix: correct total price in `calculateTotal` `` |
| `docs` | Documentação | ``docs: update install instructions`` |
| `refactor` | Refatoração sem mudar comportamento | ``refactor: extract logic to `productService` `` |
| `chore` | Manutenção/config | ``chore: update project dependencies`` |
| `style` | Formatação, espaçamento (sem lógica) | ``style: adjust `<Button/>` spacing`` |
| `test` | Adição ou correção de testes | ``test: add `userService` tests`` |
| `perf` | Melhoria de performance | ``perf: memoize list rendering with `useMemo` `` |
| `ci` | Mudanças em pipelines/CI | ``ci: add build workflow to GitHub Actions`` |
| `build` | Mudanças no sistema de build | ``build: update `next.config.ts` `` |
| `revert` | Reverter commit anterior | ``revert: revert login validation`` |

Mais exemplos:
- ``feat: add `GET /users` with pagination``
- ``feat: add session check to protected routes``
- ``fix: filter out soft-deleted rows in product list query``
- ``chore: update Prisma to the latest version``

### 4. Montar mensagem

Formato:
```
type: short description in english
```

- **Padrão: linha única, sem corpo.** Mensagem curta, a primeira linha deve bastar na grande maioria dos commits.
- Corpo é exceção: só quando a mudança precisa de contexto que a primeira linha não dá (o "por quê" de uma decisão não óbvia, efeito colateral, breaking change). Nesse caso: separado por linha em branco, no máximo 4 linhas, direto.
- Corpo que apenas repete a descrição em outras palavras, narra o passo a passo ou lista os arquivos alterados é proibido: o diff já mostra isso.

Regras da mensagem:
- **Idioma: inglês.** Verbo no imperativo presente (`add`, `fix`, `remove`, `update`, `extract`, `rename`).
- **Tudo em minúsculo**, exceto siglas (`API`, `JWT`, `URL`...) e nomes próprios de tecnologia (`React`, `Next.js`, `PostgreSQL`, `Prisma`...).
- **Crases (`` ` ``) em destaques:** nomes de arquivos, tipos, funções, componentes, hooks, props, comandos, endpoints. Ex: `` `Button.tsx` ``, `` `userService` ``, `` `useAuth` ``, `` `isLoading` ``, `` `GET /users` ``.
- Primeira linha: máximo 72 caracteres.
- Sem escopo entre parênteses. A descrição já diz o que mudou, e o diff mostra onde.
- Descrição: começa com verbo em minúsculo, sem ponto final.
- Corpo (só quando existir): explica o "por quê" (não o "o quê"), máximo 4 linhas.
- Sem travessão (`—`). Use hífen com espaços, vírgula ou dois-pontos.

### 5. Confirmar branch e commit com o usuário

Rodar `git branch --show-current` e apresentar:
```
Branch atual: feature/auth-session

Arquivos a commitar:
  M  src/components/Button.tsx
  A  src/hooks/useAuth.ts

Mensagem:
  feat: add `useAuth` hook for session handling

Commitar nessa branch? (s/n ou informe outra branch)
```

- Se o usuário indicar outra branch, trocar ou criar (`git checkout -b feature/<name>` a partir de `develop`) antes de commitar.
- **Só prosseguir com aprovação explícita da branch e da mensagem.**

### 6. Executar commit

1. Adicionar arquivos específicos: `git add <arquivo1> <arquivo2>`
2. Criar commit com HEREDOC (para formatação correta)
3. Rodar `git status` para confirmar sucesso

## Mudanças em múltiplas áreas

Se o diff contiver mudanças em áreas diferentes e não-relacionadas, sugerir commits separados:

```
Detectei mudanças em 2 áreas distintas:
1. feat: add authentication middleware
2. fix: correct goals chart

Recomendo 2 commits separados. Prosseguir assim?
```

## Erros de hook

Se um hook bloquear o commit:

- **Pre-commit do repositório** (lint, testes): ler a saída do erro, corrigir o problema, re-stage dos arquivos e criar um **novo** commit (nunca amend do anterior).
- **Guards do Claude Code** (`~/.claude/hooks/`): validam a mensagem (formato, idioma, travessão, `Co-Authored-By`) e pedem confirmação da branch. Se bloquearem, corrigir a mensagem e tentar de novo.
- **Nunca** contornar com `--no-verify`.
