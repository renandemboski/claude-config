# Regras de Docker

> Subir para produção, escala, cache e observabilidade: `rules/deploy.md`.

## Contexto

Docker cobre dois casos no projeto:

| Caso | O que roda |
|------|------------|
| Desenvolvimento | Só o PostgreSQL em container. O Next.js roda com `npm run dev` na máquina. |
| Build de produção | Imagem multi-stage do Next.js com `output: "standalone"`. |

## Estrutura no Repositório

```text
<project>/
├── docker-compose.yml        # PostgreSQL local
├── Dockerfile                # build de produção do Next.js
├── .dockerignore
├── database/
│   └── init.sql              # extensões do Postgres
├── prisma/
│   ├── schema.prisma
│   └── migrations/           # SQL versionado
└── src/
```

## docker-compose.yml

```yaml
services:
  db:
    image: postgres:17.5-alpine
    restart: unless-stopped
    env_file: .env
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

volumes:
  pgdata:
```

### Regras

- Versão fixada na imagem (`postgres:17.5-alpine`), nunca `latest`.
- Credenciais via `env_file` ou variável de ambiente, nunca no arquivo.
- Volume nomeado para os dados: `pgdata`. Bind mount de dados do Postgres dá problema de permissão.
- `init.sql` montado como somente leitura, roda apenas na primeira criação do volume: serve para extensão (`create extension if not exists "pgcrypto"`), não para tabela. Estrutura é `prisma migrate`, sempre.
- Healthcheck com `pg_isready`: serviço que depende do banco usa `depends_on` com `condition: service_healthy`.
- Expor porta só do que precisa ser acessado da máquina.

## Dockerfile do Next.js

Exige `output: "standalone"` no `next.config.ts`:

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
};

export default nextConfig;
```

```dockerfile
FROM node:22.14-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:22.14-alpine AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:22.14-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup -g 1001 -S nodejs && adduser -u 1001 -S nextjs -G nodejs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

### Regras

- Três estágios: `deps` instala, `builder` compila, `runner` só recebe o resultado. A imagem final não tem código-fonte nem devDependencies.
- `npm ci` com `package-lock.json` copiado antes do resto do código: o cache de camada só invalida quando o lock muda.
- Versão fixada do Node (`node:22.14-alpine`), nunca `latest`.
- Usuário não-root (`nextjs`) e `--chown` nos artefatos copiados.
- `standalone` já traz o `server.js` e só as dependências usadas: o comando final é `node server.js`, nunca `npm start`.
- `npx prisma generate` roda antes do `npm run build`: o client gerado precisa existir na hora de compilar. Com o client gerado dentro de `src/`, o `standalone` já o carrega junto.
- Migration não roda no `Dockerfile`: `npx prisma migrate deploy` é passo do deploy, com o banco acessível.
- Variável com prefixo `NEXT_PUBLIC_` é embutida no build: precisa estar presente no estágio `builder`, não só em runtime.
- Nunca `COPY .env` para dentro da imagem. Segredo entra em runtime.

## .dockerignore

```text
node_modules
.next
.git
.env
.env.*
npm-debug.log*
Dockerfile
docker-compose.yml
README.md
coverage
```

Sem `.dockerignore` o `COPY . .` manda `node_modules` e `.next` da máquina para dentro do build: imagem grande e cache quebrado.

## Comandos

```bash
docker compose up -d                  # sobe o Postgres
docker compose down                   # para o Postgres, mantém os dados
docker compose down -v                # para e apaga os dados (reset do banco)
docker compose logs -f db             # acompanha o log do banco

docker build -t <project>:local .     # build da imagem de produção
docker run --rm -p 3000:3000 --env-file .env <project>:local
```

## Regras Gerais

- Nunca commitar dump, volume ou backup de banco.
- Nunca colocar segredo em `Dockerfile`, `ENV` ou `ARG` de build.
- Imagem base sempre com tag de versão explícita.
- Em desenvolvimento, o app roda fora do container: hot reload dentro do Docker no Windows fica lento e sem ganho.
