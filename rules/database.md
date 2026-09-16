# Regras de Banco de Dados - PostgreSQL + Prisma

## Organização

- Um banco por projeto, schema `public` por padrão.
- Criar schema adicional só quando existe motivo real de isolamento. Nome em minúsculo, sem acentos, sem abreviação.
- Um único `prisma/schema.prisma` na raiz do projeto. Se o schema passar de algumas centenas de linhas, quebrar em vários `.prisma` na pasta `prisma/schema/`.

```text
<projeto>/
├── prisma/
│   ├── schema.prisma       # modelos e datasource
│   ├── migrations/         # SQL gerado, versionado no repo
│   └── seed.ts             # dados iniciais
└── src/
    └── lib/
        └── db.ts           # instância única do PrismaClient
```

## Nomenclatura

Identificadores de código, nomes de tabela e coluna sempre em inglês. Texto visível ao usuário final (mensagem de erro, label, conteúdo) continua em português.

### Modelos e tabelas

- Modelo em `PascalCase` singular: `model Product`, `model AccountReceivable`.
- Tabela física em lowercase, plural, `snake_case` para palavra composta: `products`, `accounts_receivable`.
- Ligar os dois com `@@map`.

### Campos e colunas

- Campo em `camelCase`, em inglês: `dueDate`, `totalAmount`.
- Coluna física em lowercase `snake_case`, mapeada com `@map`.

### Chave primária

- Campo `id`, sempre.
- `String @id @default(uuid()) @db.Uuid` quando o id aparece em URL ou sai do sistema.
- `Int @id @default(autoincrement())` em tabela de apoio interna.

### Chave estrangeira

- Campo escalar no formato `<modeloSingular>Id`, coluna `<tabela_singular>_id`: `categoryId` / `category_id`.
- Tipo igual ao da PK referenciada.
- Sempre declarar `onDelete`: `Restrict` é o default seguro, `Cascade` só em filho que não existe sozinho.

## Colunas de Auditoria

Obrigatórias em todo modelo de domínio:

| Campo | Coluna | Regra |
|-------|--------|-------|
| `createdAt` | `created_at` | `DateTime @default(now()) @db.Timestamptz(6)` |
| `updatedAt` | `updated_at` | `DateTime @updatedAt @db.Timestamptz(6)` |
| `deletedAt` | `deleted_at` | `DateTime?`, marca soft delete |

Toda leitura de dado ativo filtra `deletedAt: null`.

## Constraints e Índices

| Tipo | Formato | Onde declarar |
|------|---------|---------------|
| PK | `pk_<tabela>` | `@id(map: "pk_products")` |
| FK | `fk_<tabela>_<coluna>` | `@relation(..., map: "fk_products_category_id")` |
| Unique | `uq_<tabela>_<coluna>` | `@@unique([name], map: "uq_products_name")` |
| Índice | `idx_<tabela>_<coluna>` | `@@index([categoryId], map: "idx_products_category_id")` |

- Índice em toda FK e em coluna usada em filtro ou ordenação frequente.
- `CHECK` não existe no schema do Prisma: adicionar com SQL na migration, seguindo o formato `ck_<tabela>_<coluna>`.

## Tipos de Dados

| Prisma | Postgres | Usar quando |
|--------|----------|-------------|
| `String @db.Uuid` | `uuid` | PK e FK expostas |
| `Int` / `BigInt` | `integer` / `bigint` | PK interna, contador |
| `String @db.VarChar(n)` | `varchar(n)` | Texto curto com limite conhecido |
| `String @db.Text` | `text` | Texto longo |
| `Boolean` | `boolean` | Verdadeiro ou falso |
| `DateTime @db.Timestamptz(6)` | `timestamptz` | Data com hora, sempre |
| `DateTime @db.Date` | `date` | Data sem hora |
| `Decimal @db.Decimal(10, 4)` | `numeric(10,4)` | Valor financeiro, nunca `Float` |
| `Json @db.JsonB` | `jsonb` | Dado semi-estruturado, com parcimônia |

`Decimal` chega no código como objeto `Decimal`, não como `number`. Converter na borda do service (`.toNumber()` ou `.toString()`), nunca deixar vazar para o componente.

## Schema

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client"
  output   = "../src/generated/prisma"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Category {
  id       String    @id(map: "pk_categories") @default(uuid()) @db.Uuid
  name     String    @db.VarChar(80)
  products Product[]

  createdAt DateTime  @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt DateTime  @updatedAt @map("updated_at") @db.Timestamptz(6)
  deletedAt DateTime? @map("deleted_at") @db.Timestamptz(6)

  @@unique([name], map: "uq_categories_name")
  @@map("categories")
}

model Product {
  id          String  @id(map: "pk_products") @default(uuid()) @db.Uuid
  name        String  @db.VarChar(120)
  description String? @db.Text
  price       Decimal @db.Decimal(10, 4)
  categoryId  String  @map("category_id") @db.Uuid

  category Category @relation(fields: [categoryId], references: [id], onDelete: Restrict, map: "fk_products_category_id")

  createdAt DateTime  @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt DateTime  @updatedAt @map("updated_at") @db.Timestamptz(6)
  deletedAt DateTime? @map("deleted_at") @db.Timestamptz(6)

  @@unique([name], map: "uq_products_name")
  @@index([categoryId], map: "idx_products_category_id")
  @@map("products")
}
```

## Client

Instância única exportada de `src/lib/db.ts`. Sem o `globalThis`, o hot reload do Next abre uma conexão nova a cada recompilação até estourar o limite do Postgres.

```ts
// src/lib/db.ts
import "server-only";
import { PrismaClient } from "@/generated/prisma";

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["query", "warn", "error"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```

`import "server-only"` garante erro de build se algum componente cliente importar o banco por engano.

## Queries

`select` explícito sempre: nunca devolver o modelo inteiro quando a tela usa quatro campos.

```ts
import { Prisma } from "@/generated/prisma";
import { prisma } from "@/lib/db";

export const productListSelect = {
  id: true,
  name: true,
  price: true,
  createdAt: true,
  category: { select: { id: true, name: true } },
} satisfies Prisma.ProductSelect;

export type ProductListItem = Prisma.ProductGetPayload<{ select: typeof productListSelect }>;

const where: Prisma.ProductWhereInput = {
  deletedAt: null,
  ...(search ? { name: { contains: search, mode: "insensitive" } } : {}),
  ...(categoryId ? { categoryId } : {}),
};

const [items, totalCount] = await prisma.$transaction([
  prisma.product.findMany({
    where,
    select: productListSelect,
    orderBy: { [sortBy]: sortDirection },
    skip: (page - 1) * pageSize,
    take: pageSize,
  }),
  prisma.product.count({ where }),
]);
```

- Tipos vêm do Prisma Client (`Prisma.ProductGetPayload`, `Prisma.ProductWhereInput`): nunca redigitar a forma da linha à mão.
- Campo de ordenação vem de uma lista fechada validada com Zod, nunca direto do query param.
- Escrita que toca mais de uma tabela roda em `prisma.$transaction`.
- Delete de domínio é soft delete: `update` em `deletedAt`. Delete físico só em tabela de log ou fila.
- Relação carregada com `select` aninhado, não com `include`: `include` traz a tabela inteira.

### SQL cru

- `$queryRawUnsafe` e `$executeRawUnsafe` são proibidos.
- Quando o query builder não resolve, usar `$queryRaw` com template tag: a interpolação vira parâmetro.

```ts
const rows = await prisma.$queryRaw<{ id: string; total: number }[]>`
  select category_id as id, count(*)::int as total
  from products
  where deleted_at is null and created_at >= ${startDate}
  group by category_id
`;
```

## Migrations

```bash
npx prisma migrate dev --name create-products  # desenvolvimento: gera o SQL e aplica
npx prisma migrate deploy                      # produção: aplica o que está pendente
npx prisma generate                            # regera o client após mudar o schema
```

- `prisma/migrations/` é versionada no repositório, SQL e `migration_lock.toml` juntos.
- Nunca editar migration já aplicada: gerar uma nova.
- `prisma db push` só em base local descartável, nunca onde existe dado que importa.
- Migration que renomeia ou remove coluna com dado é revisada à mão antes de aplicar.
- `CHECK` e índice parcial entram como SQL escrito na migration gerada, antes de aplicar.
- Dado inicial vai em `prisma/seed.ts`, nunca dentro de migration.

## Inegociáveis

- Nunca alterar o banco sem permissão explícita do usuário.
- `DATABASE_URL` só em `.env`, nunca commitada.
- Nenhum acesso ao banco fora do servidor (ver `rules/backend.md`).
- Nunca commitar dump, volume ou backup.
