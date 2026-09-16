# Regras de Deploy e Escalabilidade

Como subir o app para produção e fazer ele aguentar crescimento. Docker e imagem: `rules/docker.md`.

## Quando aplicar

Este arquivo é condicional. A maior parte dos projetos nunca precisa da seção de escala. Aplicar pelo tamanho real, nunca por precaução:

| Situação | O que vale deste arquivo |
|----------|--------------------------|
| Projeto local, protótipo, uso pessoal | Nada. Subir na plataforma mais simples e seguir a vida |
| App em produção com poucos usuários | Pré-requisitos, pool de conexões e health check. Só isso |
| App com tráfego real ou crescendo | Tudo: cache, escala horizontal, observabilidade, pipeline |

Escalabilidade aplicada cedo demais vira complexidade parada: custa tempo, dificulta manutenção e resolve um problema que ainda não existe. Na dúvida entre dois níveis, ficar no menor e perguntar ao usuário.

## Onde hospedar

Escolher pelo estágio do projeto, não por moda. Sempre confirmar com o usuário antes de assumir uma plataforma.

| Opção | Quando usar | Custo aproximado |
|-------|-------------|------------------|
| Vercel | Protótipo, MVP, tráfego imprevisível. Zero configuração, escala sozinho | Gratuito no hobby, cerca de 20 dólares por pessoa no Pro |
| Container em VPS ou PaaS (Railway, Fly.io, Hetzner, Render) | Tráfego estável e previsível, conta da Vercel passando de algumas centenas por mês | 10 a 30 dólares por mês |
| Kubernetes | Só quando já existem vários serviços e alguém no time cuida de infra | Alto, em dinheiro e em tempo |

Regra prática: começar no mais simples e migrar quando a conta ou o limite doer. Sair cedo demais para container ou Kubernetes custa semanas de trabalho que o projeto ainda não precisa.

## Pré-requisitos antes do primeiro deploy

- `npm run build` passa sem erro e sem warning.
- Variáveis de ambiente validadas com Zod no boot (ver `rules/backend.md`): app não sobe com env faltando.
- `.env.example` atualizado com todas as chaves, valores fictícios.
- Migrations aplicadas com `npx prisma migrate deploy`, nunca `db push` nem `migrate dev`.
- Headers de segurança configurados (ver `rules/security.md`).
- Health check respondendo em `/api/health`: verifica app e banco, retorna 200 ou 503.

```ts
// src/app/api/health/route.ts
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await prisma.$queryRaw`select 1`;
    return NextResponse.json({ status: "ok" });
  } catch {
    return NextResponse.json({ status: "degraded" }, { status: 503 });
  }
}
```

## Banco: o primeiro gargalo

O Postgres abre um processo por conexão. Cada instância do app com seu próprio pool derruba o banco antes de a CPU do app chegar perto do limite. Esse é o gargalo que aparece primeiro em quase todo projeto.

- **Sempre usar pool de conexões.** Self-hosted: PgBouncer em modo transaction. Gerenciado: Neon, Supabase ou Prisma Accelerate já entregam o pooler pronto.
- **Em serverless** (Vercel, Lambda), na URL do banco: `?pgbouncer=true&connection_limit=1`. O `pgbouncer=true` desliga prepared statements nomeados, que não funcionam em modo transaction. O `connection_limit=1` impede cada instância de abrir seu próprio pool.
- **Em container de longa duração**, o pool do Prisma resolve: `connection_limit` entre 5 e 10 por instância, calculado como `max_connections` do Postgres dividido pelo número de instâncias, com folga.
- Duas URLs no ambiente: `DATABASE_URL` apontando para o pooler (uso normal) e `DIRECT_URL` na conexão direta (migrations, que não funcionam através do pooler).

```prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}
```

- Índice em toda coluna usada em filtro, ordenação ou join (ver `rules/database.md`). Consulta lenta sem índice derruba o banco muito antes de o tráfego justificar mais servidor.
- Backup automático diário e teste de restauração pelo menos uma vez. Backup nunca testado não é backup.

## Cache

Cache é o que separa app que aguenta dez usuários de app que aguenta dez mil. Ordem de preferência, do mais barato para o mais caro:

1. **Página estática**: conteúdo que não muda por usuário. Renderizado no build, servido pelo CDN.
2. **`use cache` com `cacheLife`**: dado compartilhado que pode ficar alguns segundos ou minutos desatualizado (catálogo, listagem pública, home).
3. **`revalidateTag` na mutação**: atualiza o cache no exato momento em que o dado muda, em vez de esperar o tempo expirar.
4. **Sem cache**: dado por usuário e dado que não pode atrasar (saldo, carrinho, painel logado).

```ts
// Leitura compartilhada, cacheada e invalidável por tag
async function getProducts() {
  "use cache";
  cacheTag("products");
  cacheLife("minutes");
  return prisma.product.findMany({ where: { deletedAt: null }, select: productListSelect });
}

// Na mutação que altera produto
revalidateTag("products");
```

- Em mais de uma instância, o cache em memória de cada uma diverge. Nesse cenário, usar cache remoto compartilhado (`use cache: remote` ou cache handler apontando para Redis).
- Nunca cachear resposta que depende de sessão sem incluir o usuário na chave. Cache vazando dado de um usuário para outro é falha de segurança, não de performance.

## Escalar o app

- **Escalar horizontal, não vertical**: várias instâncias pequenas atrás de um balanceador, em vez de uma máquina gigante. Instância morre sem derrubar o serviço.
- **Instância sem estado**: nada de sessão em memória, arquivo salvo em disco local ou contador global. Sessão vai para cookie ou banco, arquivo vai para storage (S3, R2), estado compartilhado vai para Redis. Sem isso, escalar horizontal quebra o app.
- **Health check e graceful shutdown**: o balanceador só manda tráfego quando o health check passa; no `SIGTERM`, terminar as requisições em andamento antes de encerrar.
- **Autoscaling por métrica real** (CPU, latência, fila), com mínimo de 2 instâncias em produção para não ter ponto único de falha.
- Trabalho pesado (relatório, envio de e-mail em massa, processamento de arquivo) sai do request e vai para fila ou job em background. Request HTTP nunca espera tarefa longa.

## Observabilidade

Sem isso, escalar vira adivinhação.

- **Logs estruturados em JSON**, com `userId`, `requestId` e duração. Nunca dado sensível (ver `rules/security.md`).
- **Monitoramento de erro** com captura automática e alerta: Sentry ou equivalente.
- **Métricas mínimas**: latência p95 e p99 (não a média, que esconde o problema), taxa de erro 5xx, uso de conexões do banco, consultas lentas.
- **Core Web Vitals** medidos em produção com usuário real, não só no Lighthouse local.
- **Alerta com dono**: alerta que ninguém recebe ou que dispara toda hora vira ruído e todo mundo ignora.

## Pipeline de deploy

Ordem fixa, e qualquer passo que falhar interrompe o deploy:

1. `npm run lint` e `npm run typecheck`
2. Testes (`npm run test`)
3. Build (`npm run build`)
4. Auditoria de dependência (`npm audit --audit-level=high`)
5. Migration (`npx prisma migrate deploy`)
6. Deploy da nova versão
7. Health check na versão nova antes de mandar tráfego

- **Rollback em um comando**: manter a versão anterior pronta para voltar. Deploy sem rollback é aposta.
- **Migration compatível com as duas versões**: adicionar coluna antes de usar, remover coluna só depois que nenhuma versão em produção a usa. Renomear coluna em um passo só derruba o app durante o deploy.
- **Secret sempre em cofre** (variável de ambiente da plataforma, Secret Manager, Vault). Nunca no repositório, nem em `.env` versionado.
- Deploy automático pela branch principal, depois que tudo acima passar.

## Inegociáveis

- Nunca fazer deploy sem permissão explícita do usuário.
- Nunca rodar `prisma migrate dev`, `db push` ou `migrate reset` contra banco de produção.
- Nunca subir sem health check e sem rollback definido.
- Nunca colocar secret em imagem Docker, log ou código do cliente.
- Nunca cachear resposta específica de usuário em cache compartilhado.
