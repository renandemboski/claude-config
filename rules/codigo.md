# Padrões Universais de Código

> Fonte única dos padrões que valem em qualquer código, back ou front, para a sessão principal e para todos os agentes. Ler antes de codar, sempre.

## Inegociáveis

- Nunca `any` em TypeScript. Tipar tudo explicitamente.
- Nunca hardcodar cores, URLs, secrets ou credenciais: usar tokens e variáveis de ambiente.
- Nunca instalar dependência sem verificar se o projeto já resolve com o que tem.
- Dependência que deixou de ser usada sai do projeto na mesma tarefa: `npm uninstall`, nunca deixar pacote morto no `package.json`. Antes de encerrar, conferir se toda dependência instalada ainda tem import em uso; vale também para a que foi instalada só para testar uma ideia.
- Nunca usar biblioteca paga, com plano gratuito limitado, trial ou licença restritiva (comercial, GPL, AGPL, SSPL, "source available") sem permissão explícita do usuário. Antes de propor, checar a licença e o custo. Preferir open source com licença permissiva: MIT, Apache 2.0, ISC, BSD.
- Serviço externo pago ou com cota (API, SaaS, chave de terceiro) segue a mesma regra: propor primeiro, usar só depois do aval.
- Em dúvida sobre API de biblioteca (assinatura, versão, funcionalidade nova), consultar o Context7 (MCP) em vez de confiar na memória.
- Após qualquer alteração, limpar: imports não usados, variáveis mortas, arquivos órfãos, dependência sem uso.
- Toda página com dados assíncronos trata os 3 estados: loading, empty e erro.
- Comentários só onde precisa e curtos: uma linha explicando um "porquê" não óbvio. Proibido bloco de comentário com várias linhas, comentário narrando o que a linha seguinte faz e comentário óbvio.
- Travessão (`—`) e emojis são proibidos em código, comentários e qualquer arquivo gerado. No lugar do travessão: hífen com espaços, vírgula ou dois-pontos.

## Formatação e lint (obrigatório em todo projeto)

Todo projeto nasce com formatador e linter configurados, antes da primeira feature. Sem isso, cada code review vira discussão de estilo e o diff enche de mudança de espaço.

- **Prettier** decide a formatação. `.prettierrc` na raiz com poucas opções (`semi`, `singleQuote`, `printWidth`, `trailingComma`) e `.prettierignore`. Formatação nunca é discutida em review nem feita à mão.
- **ESLint** em flat config (`eslint.config.mjs`) com `typescript-eslint` no preset `strict` e `eslint-config-prettier` por último, para não brigar com o Prettier. Em Next.js, incluir `eslint-config-next`.
- **`.editorconfig`** na raiz: `indent_style = space`, `indent_size = 2`, `end_of_line = lf`, `charset = utf-8`, `trim_trailing_whitespace = true`, `insert_final_newline = true`.
- **Scripts com nome fixo** no `package.json`: `lint`, `lint:fix`, `format`, `format:check`, `typecheck` (`tsc --noEmit`). CI, QA e agentes chamam esses nomes, nunca comando avulso.
- **Pre-commit local**: `lint-staged` rodando Prettier e ESLint só nos arquivos staged, acionado por `simple-git-hooks` (mais leve que husky). Commit com erro de lint não passa; `--no-verify` continua proibido.
- **Warning é erro**: `eslint --max-warnings 0`. Regra desligada só com comentário de uma linha dizendo o porquê.
- Setup de projeto novo em um comando:

```bash
npm i -D prettier eslint typescript-eslint eslint-config-prettier lint-staged simple-git-hooks
```

## Nomenclatura

Todo identificador de código é em inglês: variáveis, funções, tipos, componentes, hooks, arquivos, pastas, modelos de banco, tabelas e colunas. Texto visível ao usuário final continua em português: labels, mensagens de erro e de validação, placeholders, conteúdo de tela. Comentário de código, quando existir, também em inglês.

### Geral

- CRUD: `get` (único), `list` (coleção), `create`, `update`, `delete`
- Booleanos: `isActive`, `isLoading`, `hasError` - nunca nomes ambíguos
- Enums para conjuntos fixos: `UserStatus.Active`, `OrderStatus.Pending`

### Frontend

- `camelCase` variáveis/funções | `PascalCase` componentes/tipos | `kebab-case` arquivos/pastas
- Componentes = substantivos (`UserCard`) | Funções = verbos (`fetchUser`)

### Backend

- `PascalCase` classes, métodos, propriedades, DTOs | `camelCase` variáveis locais e parâmetros
- `I` prefixo em interfaces: `IUserService`, `IUserRepository`
- Sufixos por camada: `UserController`, `UserService`, `UserRepository`, `CreateUserDto`
