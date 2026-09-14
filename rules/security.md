# Regras de Segurança - Next.js, OWASP Top 10 e Boas Práticas

Stack: TypeScript, Next.js App Router (sempre a versão mais recente), PostgreSQL com Prisma ORM, Auth.js com sessão em cookie HttpOnly, npm.

## Princípios Gerais

- Defense in depth: várias camadas de proteção, nunca confiar em uma só.
- Least privilege: cada usuário, token e credencial de banco recebe o mínimo necessário.
- Never trust input: toda entrada é hostil até ser validada com Zod.
- Servidor é fonte de verdade: validação em Client Component existe só para UX.
- Fail securely: em erro, negar acesso por padrão e nunca expor stack trace. Segurança desde a primeira rota, não como patch.

## OWASP Top 10 - Ataques e Mitigações

### A01 - Broken Access Control

**Ataque:** usuário lê ou altera recurso de outro usuário (IDOR), escala privilégio, chama ação sem permissão. **Mitigação:**

- Verificar a sessão do Auth.js em **todo** Route Handler e **toda** Server Action. Server Action não é privada por padrão: é chamável por quem descobrir o id.
- `middleware.ts` protege rotas privadas por prefixo (`export { auth as middleware } from '@/auth'` com `config.matcher`), mas é só a primeira camada. A checagem real fica dentro do handler.
- Verificar ownership antes de update e delete, filtrando pelo `userId` da sessão dentro da própria query.
- Nunca confiar em UI escondida: botão oculto não é autorização. ID público como UUID, nunca inteiro sequencial.

```ts
const session = await auth()
if (!session?.user?.id) return Response.json({ error: 'Não autenticado' }, { status: 401 })

const { count } = await prisma.note.updateMany({
  where: { id: params.id, userId: session.user.id },
  data: { title: parsed.title },
})
if (count === 0) return Response.json({ error: 'Não encontrado' }, { status: 404 })
```

### A02 - Cryptographic Failures

**Ataque:** interceptação de dados em trânsito, leitura de dados sensíveis em repouso. **Mitigação:**

- HTTPS obrigatório em produção, com HSTS. `AUTH_SECRET` forte e diferente por ambiente.
- Senha nunca em plain text: login por credenciais usa hash argon2 ou bcrypt. Dado sensível (CPF, cartão, token de integração) criptografado em repouso.
- Sessão em cookie HttpOnly. Token nunca em `localStorage` nem `sessionStorage`.

### A03 - Injection

**Ataque:** atacante injeta SQL ou comando em input interpretado pelo servidor. **Mitigação:**

- O Prisma Client parametriza toda query do query builder. É o caminho padrão.
- Nunca usar `$queryRawUnsafe` nem montar SQL com template string concatenando input. Precisando de SQL cru, usar `$queryRaw` com template tag, que parametriza os valores interpolados.
- Nome de coluna e direção de ordenação vindos do usuário passam por whitelist, nunca entram em SQL cru. Validar toda entrada com Zod antes de tocar no banco e nunca executar shell com input do usuário (`child_process.exec`).

```ts
await prisma.$queryRawUnsafe(`select * from "User" where email = '${email}'`) // NUNCA
await prisma.$queryRaw`select id from "User" where email = ${email}` // SQL cru parametrizado
await prisma.user.findUnique({ where: { email }, select: { id: true } }) // padrão
```

### A04 - Insecure Design

**Ataque:** falha de arquitetura, como login sem rate limit ou token de reset adivinhável. **Mitigação:**

- Rate limit em login, reset de senha, cadastro e reenvio de código. Contador em memória serve para projeto pessoal em instância única; com mais de uma instância, usar store compartilhado (Redis) ou biblioteca equivalente.
- Token de reset com expiração curta (15 minutos), uso único, gerado por fonte aleatória criptográfica.
- Ambientes separados: dev e produção nunca compartilham banco nem secrets.

```ts
// lib/rate-limit.ts - janela fixa em memória, uma instância
const hits = new Map<string, { count: number; resetAt: number }>()
export function rateLimit(key: string, limit = 5, windowMs = 60_000) {
  const now = Date.now()
  const entry = hits.get(key)
  if (!entry || now > entry.resetAt) {
    hits.set(key, { count: 1, resetAt: now + windowMs })
    return { allowed: true }
  }
  entry.count += 1
  return { allowed: entry.count <= limit }
}
```

### A05 - Security Misconfiguration

**Ataque:** CORS liberado, stack trace exposto, headers de segurança ausentes. **Mitigação:**

- Headers de segurança no `next.config.ts`, aplicados em `/:path*`.
- CORS restritivo em Route Handler público: lista explícita de origens, nunca `*` quando a rota lê a sessão.
- Nunca retornar `error.message` ou stack trace em produção: detalhe vai para o log do servidor, cliente recebe mensagem genérica. `.env` fora do commit.

```ts
// next.config.ts - async headers() { return [{ source: '/:path*', headers: securityHeaders }] }
const securityHeaders = [
  { key: 'Content-Security-Policy', value: "default-src 'self'; frame-ancestors 'none'" },
  { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
]
```

### A06 - Vulnerable and Outdated Components

**Ataque:** dependência com CVE conhecido é explorada. **Mitigação:**

- `npm audit` periódico e antes de cada deploy. `npm ci` no build, com `package-lock.json` commitado.
- Evitar pacote abandonado: sem release recente, poucos downloads, autor desconhecido.
- Atualizar dependências em commits `chore: ...` dedicados.

### A07 - Identification and Authentication Failures

**Ataque:** credential stuffing, sessão sem expiração, cookie roubado. **Mitigação:**

- Auth.js como única camada de autenticação. Sem auth caseira.
- Cookie de sessão com `httpOnly: true`, `secure: true` em produção e `sameSite: 'lax'`.
- Sessão curta (por exemplo 30 minutos de `maxAge`), renovada enquanto o usuário está ativo. Nunca guardar token em `localStorage` nem passar em query string.
- Rate limit em login e reset de senha (ver A04). Logout invalida a sessão no servidor, não só apaga o cookie.

### A08 - Software and Data Integrity Failures

**Ataque:** supply chain, pipeline comprometido, desserialização insegura. **Mitigação:**

- Secrets do CI no cofre do provedor, nunca no repositório. Nunca desserializar payload externo em objeto arbitrário: sempre `schema.parse()` do Zod.
- Script externo com `integrity` (SRI) e `crossorigin="anonymous"`.

### A09 - Security Logging and Monitoring Failures

**Ataque:** atividade maliciosa passa despercebida por falta de log. **Mitigação:**

- Logar evento de autenticação (login, logout, falha), mudança de senha e de permissão, acesso negado (401 e 403) e erro 5xx com contexto.
- Nunca logar senha, token, cookie de sessão, CPF, cartão ou dado de saúde.
- Log estruturado em JSON com `userId`, `requestId`, `timestamp`, `action` e `result`. Alerta em pico de 401, 403 ou 5xx.

### A10 - Server-Side Request Forgery (SSRF)

**Ataque:** atacante faz o servidor buscar URL interna (metadata da cloud, banco, serviço privado). **Mitigação:**

- Nunca dar `fetch` no servidor em URL arbitrária do usuário.
- Se for necessário: allowlist de hosts, exigir `https:`, timeout curto e `redirect: 'manual'`.
- Bloquear destino interno: `localhost`, `127.0.0.1`, faixas privadas, `169.254.169.254`.

## Frontend - Riscos Específicos

- **XSS**: React escapa por padrão. `dangerouslySetInnerHTML` só com HTML sanitizado: `<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />`. CSP sem `'unsafe-eval'`.
- **URL do usuário em `href` ou `src`**: validar que começa com `https://`. Bloquear `javascript:` e `data:`.
- **CSRF**: Server Actions já trazem proteção nativa por checagem de origem. Em Route Handler que muda estado, manter cookie `SameSite=Lax` e conferir o header `Origin`.
- **Clickjacking**: `X-Frame-Options: DENY` mais CSP `frame-ancestors 'none'`. **Tabnabbing**: `rel="noopener noreferrer"` em todo `target="_blank"`.
- **Open redirect**: nunca redirecionar para URL vinda de query param sem validar. Aceitar só caminho relativo começando com `/` ou host da allowlist.
- **Secrets no bundle**: só `NEXT_PUBLIC_*` vai ao cliente, e tudo que é `NEXT_PUBLIC_` é público. Chave de API pública com restrição por domínio no provedor. Sem `console.log` de dados de usuário e sem source map público.

## Servidor - Riscos Específicos

- **Mass assignment**: schema Zod por operação, com `.strict()`. Nunca passar o body direto para `prisma.<model>.create` ou `update`: montar o objeto campo a campo a partir do resultado da validação.
- **Path traversal**: nunca concatenar input em caminho de arquivo. Resolver com `path.resolve` e conferir que o resultado começa no diretório base.
- **Race condition**: transação (`prisma.$transaction`) em operação crítica e unique constraint no banco como última defesa.
- **Migrations**: versionadas em `prisma/migrations/` e aplicadas por `prisma migrate deploy`. Nunca alterar o banco de produção na mão.
- **Enumeração**: resposta genérica em login ("Credenciais inválidas") e em reset de senha (mesma resposta existindo ou não o email), com mesmo status e tempo.
- **Usuário do banco**: a aplicação conecta com role dedicada de permissão mínima, nunca com superuser.

## Secrets e Credenciais

- `.env` e `.env.local` nunca commitados. `.env.example` versionado com valores fictícios.
- Apenas variáveis `NEXT_PUBLIC_` chegam ao cliente. Connection string, `AUTH_SECRET` e chaves de provedor ficam no servidor.
- Em produção, secrets no painel do provedor de deploy, não em arquivo.
- Credencial vazada é credencial queimada: rotacionar na hora. Remover do commit não resolve, o histórico guarda.
- `gitleaks` ou equivalente em pre-commit hook.

## Validação de Input

- Um schema Zod por operação, no servidor, antes de qualquer acesso ao banco.
- Validar tipo, tamanho mínimo e máximo, formato, range e whitelist de valores.
- O mesmo schema pode servir ao formulário, mas a validação que conta é a do servidor: atacante chama a rota direto com curl.

## Uploads de Arquivo

- Limite de tamanho validado no handler antes de ler o corpo inteiro. Extensão por allowlist, nunca blocklist.
- Tipo confirmado por magic bytes, nunca pelo `Content-Type` do cliente.
- Renomear o arquivo com UUID, nunca usar o nome original. Nunca executar arquivo enviado.
- Guardar em storage dedicado ou fora do diretório público, servindo de domínio separado. SVG e HTML no mesmo domínio viram XSS.

## LGPD - Dados Pessoais

- Minimização: coletar só o necessário. Finalidade: usar o dado apenas para o que foi informado, com consentimento explícito quando aplicável.
- Implementar acesso, correção, exportação e exclusão dos dados do usuário. Dado pessoal criptografado em trânsito e em repouso.

## Regras práticas - Faça / Não faça

- Sempre limitar `pageSize` com teto (`Math.min(pageSize, 100)`). Sem teto, `pageSize=999999` derruba a aplicação.
- Sempre usar whitelist de campos de ordenação, com mapa explícito de string para campo do modelo. String arbitrária deixa o atacante ordenar por `passwordHash` e inferir valores.
- Sempre aplicar o mesmo filtro de dono nas rotas de export (CSV, PDF). É o lugar que mais escapa.
- Nunca aceitar `userId`, `role`, `isAdmin` ou `plan` vindos do body. Esses valores saem da sessão do Auth.js.
- Nunca retornar o modelo inteiro do banco. Sempre `select` explícito: `prisma.user.findMany({ select: { id: true, name: true } })`. Sem isso, `passwordHash`, tokens e campos internos vazam.
- Nunca reaproveitar o schema de criação no update sem revisar quais campos podem mudar.
- Sempre checar sessão na primeira linha de Route Handler e Server Action, mesmo quando a página só aparece para quem tem acesso.
- Nunca usar `revalidatePath` ou `redirect` com caminho vindo do usuário sem validar.
- Sempre responder erro genérico ao cliente e guardar o detalhe no log do servidor.

## Checklist antes de subir para produção

- [ ] HTTPS obrigatório, HSTS habilitado e headers de segurança no `next.config.ts`
- [ ] CORS restritivo nas rotas públicas, sem `*`
- [ ] Sessão do Auth.js checada em todo Route Handler e Server Action
- [ ] Ownership verificado na query de update e delete
- [ ] Cookie de sessão HttpOnly, Secure e SameSite, com expiração curta
- [ ] Rate limit em login e reset de senha
- [ ] Toda entrada validada com Zod no servidor
- [ ] Queries pelo Prisma Client, sem `$queryRawUnsafe`, e `select` explícito em vez do modelo inteiro
- [ ] Migrations versionadas em `prisma/migrations/`, sem alteração manual em produção
- [ ] `npm audit` sem vulnerabilidade alta ou crítica e lock file commitado
- [ ] Secrets fora do repositório, só `NEXT_PUBLIC_` no cliente
- [ ] Logs estruturados sem senha, token, CPF ou cartão, e stack trace nunca exposto
- [ ] Testes cobrindo autorização, ownership e rate limit

## Referências

- Código: `rules/codigo.md`
- API: `rules/api.md`
- Backend: `rules/backend.md`
- Banco: `rules/database.md`
- Docker: `rules/docker.md`
- Frontend: `rules/frontend.md`
- Git: `rules/git.md`
- Testes: `rules/tests.md`
