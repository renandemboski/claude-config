# Padrões Universais de Código

> Fonte única dos padrões que valem em qualquer código, back ou front, para a sessão principal e para todos os agentes. Ler antes de codar, sempre.

## Inegociáveis

- Nunca `any` em TypeScript. Tipar tudo explicitamente.
- Nunca hardcodar cores, URLs, secrets ou credenciais: usar tokens e variáveis de ambiente.
- Nunca instalar dependência sem verificar se o projeto já resolve com o que tem.
- Toda tecnologia entra na versão estável mais recente: Next.js, React, Node (LTS atual), PostgreSQL, Prisma, Tailwind, Zod, Better Auth e qualquer outra dependência. Nunca beta, canary, RC nem major em fim de suporte.
- Antes de instalar ou fixar versão, conferir a estável atual com `npm view <pacote> version` (tag `latest` do npm; pré-release fica em `next` ou `beta`). Runtime e imagem (Node, Postgres) se conferem na página oficial de releases. Nunca de memória: número de versão escrito nestas rules é exemplo e pode estar velho.
- Projeto novo nasce de `npx create-next-app@latest` (TypeScript, Tailwind, App Router, `src/`), nunca de `package.json` escrito de cabeça. Logo depois, `npm outdated` e atualizar o que ficou para trás antes da primeira feature.
- Projeto existente: ao abrir para uma feature, rodar `npm outdated`. Major novo de item da stack vira aviso ao usuário e só atualiza com aprovação, em commit `chore` separado.
- Onde se fixa versão, fixar exata: `.npmrc` com `save-exact=true` na raiz (todo `npm i` grava versão exata, sem `^`), tag de imagem Docker, `engines` no `package.json`, lockfile commitado. "Mais recente" decide o que escolher na hora; depois disso a versão fica travada até alguém atualizar de propósito.
- Dependência que deixou de ser usada sai do projeto na mesma tarefa: `npm uninstall`, nunca deixar pacote morto no `package.json`. Antes de encerrar, conferir se toda dependência instalada ainda tem import em uso; vale também para a que foi instalada só para testar uma ideia.
- Nunca usar biblioteca paga, com plano gratuito limitado, trial ou licença restritiva (comercial, GPL, AGPL, SSPL, "source available") sem permissão explícita do usuário. Antes de propor, checar a licença e o custo. Preferir open source com licença permissiva: MIT, Apache 2.0, ISC, BSD.
- Serviço externo pago ou com cota (API, SaaS, chave de terceiro) segue a mesma regra: propor primeiro, usar só depois do aval.
- Context7 (MCP) é obrigatório no ambiente: entrega a documentação atual de qualquer biblioteca. Conferir com `claude mcp get context7`; se faltar, instalar com `claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp` e reiniciar a sessão.
- Em dúvida sobre API de biblioteca (assinatura, versão, funcionalidade nova), consultar o Context7, a documentação oficial ou o código instalado em `node_modules`, nunca a memória.
- Após qualquer alteração, limpar: imports não usados, variáveis mortas, arquivos órfãos, dependência sem uso.
- Toda página com dados assíncronos trata os 3 estados: loading, empty e erro.
- Comentários só onde precisa e curtos: uma linha explicando um "porquê" não óbvio. Proibido bloco de comentário com várias linhas, comentário narrando o que a linha seguinte faz e comentário óbvio.
- Travessão (`—`) e emojis são proibidos em código, comentários e qualquer arquivo gerado. No lugar do travessão: hífen com espaços, vírgula ou dois-pontos.

## Formatação e lint (obrigatório em todo projeto)

Todo projeto nasce com formatador e linter configurados, antes da primeira feature. Sem isso, cada code review vira discussão de estilo e o diff enche de mudança de espaço.

- **Prettier** decide a formatação. `.prettierrc` na raiz com poucas opções (`semi`, `singleQuote`, `printWidth`, `trailingComma`) e `.prettierignore`. Formatação nunca é discutida em review nem feita à mão.
- **ESLint** em flat config (`eslint.config.mjs`) com `typescript-eslint` no preset `strict` e `eslint-config-prettier` por último, para não brigar com o Prettier. Em Next.js, incluir `eslint-config-next`.
- **`.editorconfig`** na raiz: `indent_style = space`, `indent_size = 2`, `end_of_line = lf`, `charset = utf-8`, `trim_trailing_whitespace = true`, `insert_final_newline = true`.
- **Scripts com nome fixo** no `package.json`: `lint`, `lint:fix`, `format`, `format:check`, `typecheck` (`tsc --noEmit`) e `test` (`vitest run`). CI, QA e agentes chamam esses nomes, nunca comando avulso.
- **Pre-commit local**: `lint-staged` rodando Prettier e ESLint só nos arquivos staged, acionado por `simple-git-hooks` (mais leve que husky). Commit com erro de lint não passa; `--no-verify` continua proibido.
- **Warning é erro**: `eslint --max-warnings 0`. Regra desligada só com comentário de uma linha dizendo o porquê.
- Setup de projeto novo em um comando:

```bash
npm i -D prettier eslint typescript-eslint eslint-config-prettier lint-staged simple-git-hooks
```

## Tipagem (TypeScript)

Fonte única das regras de tipo. O `backend.md` só acrescenta o que é de servidor.

- `tsconfig.json` mínimo: `strict: true`, `noUncheckedIndexedAccess: true` (`lista[0]` vira `T | undefined` e obriga a tratar) e `verbatimModuleSyntax: true` (força `import type` para tipo).
- Nunca `any`. Dado que chega de fora (request, `localStorage`, JSON, resposta de API) é `unknown` e passa por Zod antes de virar tipo.
- Sem escape do compilador: nunca `as Tipo` para calar erro, nunca `!` (non-null assertion), nunca `@ts-ignore`. Permitido: `as const`, `satisfies`, type guard para estreitar `unknown`, e `@ts-expect-error` com o motivo na mesma linha.
- Tipo derivado, nunca redigitado: entrada com `z.infer<typeof schema>`, saída do banco com `Prisma.XGetPayload<{ select: typeof xSelect }>`, constante com `typeof` mais `satisfies`.
- `type` por padrão. `interface` só para estender tipo de biblioteca que exige declaration merging.
- Conjunto fixo de valores é união de literais (`type Status = "active" | "inactive"`), nunca `enum` do TypeScript: gera código em runtime e não passa no `erasableSyntaxOnly`. Valor que vem do banco usa o `enum` do Prisma.
- Estado com mais de uma forma é união discriminada (`{ status: "ok"; data: T } | { status: "error"; message: string }`), não três booleanos soltos: combinação impossível deixa de compilar.
- Anotar onde importa: retorno de toda função exportada e props de componente (`type XProps`). Variável local deixa inferir; `const nome: string = "x"` é ruído.

## Nomenclatura

Todo identificador de código é em inglês: variáveis, funções, tipos, componentes, hooks, arquivos, pastas, modelos de banco, tabelas e colunas. Texto visível ao usuário final continua em português: labels, mensagens de erro e de validação, placeholders, conteúdo de tela. Comentário de código, quando existir, também em inglês.

### Geral

- CRUD: `get` (único), `list` (coleção), `create`, `update`, `delete`
- Booleanos: `isActive`, `isLoading`, `hasError` - nunca nomes ambíguos
- Conjunto fixo de valores: união de literais em `camelCase` ou `snake_case` conforme o banco (`"active" | "inactive"`), ver seção Tipagem

### Frontend

- `camelCase` variáveis/funções | `PascalCase` componentes/tipos | `kebab-case` arquivos/pastas
- Componentes = substantivos (`UserCard`) | Funções = verbos (`fetchUser`)

### Servidor (Next.js)

- Service é módulo de funções em `lib/services/<domain>.ts` (`listProducts`, `createProduct`): sem classe, sem interface com prefixo `I`, sem sufixo `Service`, `Controller` ou `Repository`.
- Tipo de entrada vem do schema Zod e termina em `Input`: `CreateProductInput = z.infer<typeof createProductSchema>`.
- Tipo de saída vem do Prisma Client e diz o recorte: `ProductListItem`, `ProductDetail`.
- Erro de domínio é `AppError` com `code` em `UPPER_SNAKE_CASE` (`NOT_FOUND`, `UNAUTHORIZED`).
