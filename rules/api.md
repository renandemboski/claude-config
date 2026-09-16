# Regras de API - Route Handlers no Next.js

## Route Handler ou Server Action

| Caso | Usar |
|------|------|
| Mutação disparada por formulário ou botão do próprio app | Server Action |
| Leitura para renderizar a página | Server Component chamando o service direto |
| Endpoint consumido por outro cliente (script, app externo, webhook, integração) | Route Handler |
| Upload, streaming, resposta não-JSON, CORS | Route Handler |
| Dado que precisa de cache do TanStack Query no cliente | Route Handler |

Regra prática: se quem chama é a própria página do app, Server Action resolve com menos código e já revalida o cache. Route Handler existe para quem está fora do app. Ver `rules/backend.md` para o padrão de Server Action.

## Rotas e Verbos HTTP

- Substantivos no plural: `/api/users`, `/api/orders`, `/api/products`.
- Palavras compostas em kebab-case com o último substantivo no plural: `/api/product-categories`, `/api/shopping-carts`.
- Nunca verbos na URL: `/api/getUser` está errado, o certo é `/api/users`.
- Aninhar quando há relação direta: `/api/users/[id]/orders`.
- Máximo 2 níveis: acima disso, preferir query param (`/api/orders?userId=123`).
- Versionar pela URL só quando a API é consumida por terceiros: `app/api/v1/users/route.ts`. App pessoal de cliente único não precisa de versão.

| Verbo | Uso | Arquivo |
|-------|-----|---------|
| `GET` | Buscar recurso(s) | `app/api/users/route.ts`, `app/api/users/[id]/route.ts` |
| `POST` | Criar recurso | `app/api/users/route.ts` |
| `PUT` | Substituir completo | `app/api/users/[id]/route.ts` |
| `PATCH` | Atualizar parcial | `app/api/users/[id]/route.ts` |
| `DELETE` | Remover recurso | `app/api/users/[id]/route.ts` |

- `GET` e `DELETE` nunca têm body.
- `POST` retorna `201` com o recurso criado e header `Location`.
- `PUT` e `PATCH` retornam `200` com o recurso atualizado.
- Cada verbo é uma função exportada do mesmo `route.ts`.

## Estrutura de Arquivos

```text
src/app/api/
├── products/
│   ├── route.ts            # GET (lista), POST (cria)
│   └── [id]/
│       └── route.ts        # GET, PUT, PATCH, DELETE
└── auth/
    └── [...nextauth]/
        └── route.ts
```

O Route Handler só faz três coisas: validar entrada, chamar o service, formatar a resposta. Regra de negócio e acesso ao banco ficam em `lib/services/` (ver `rules/backend.md`).

## Status Codes

| Código | Situação |
|--------|----------|
| `200` | Sucesso (GET, PUT, PATCH) |
| `201` | Criado (POST) |
| `204` | Sem conteúdo (DELETE) |
| `400` | Request malformado (JSON inválido) |
| `401` | Não autenticado |
| `403` | Sem permissão |
| `404` | Não encontrado |
| `409` | Conflito (ex: e-mail duplicado) |
| `422` | Validação de negócio ou de schema |
| `429` | Rate limit |
| `500` | Erro interno |

Nunca `200` com erro no body. Nunca stack trace na resposta.

## Validação de Entrada

Zod em toda fronteira: body, query params e route params. O schema é a fonte de verdade do tipo.

```ts
// src/lib/validations/products.ts
import { z } from "zod";

export const createProductSchema = z.object({
  name: z.string().trim().min(1, "Informe o nome.").max(120),
  price: z.number().positive("Preço deve ser maior que zero."),
  categoryId: z.uuid("Categoria inválida."),
});

export const listProductsSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
  search: z.string().trim().optional(),
  status: z.array(z.coerce.number().int()).default([]),
  sortBy: z.enum(["name", "price", "createdAt"]).default("createdAt"),
  sortDirection: z.enum(["asc", "desc"]).default("desc"),
});

export type CreateProductInput = z.infer<typeof createProductSchema>;
export type ListProductsInput = z.infer<typeof listProductsSchema>;
```

Erro de validação retorna `422` com os campos. O helper `errorResponse` centraliza esse formato (ver `rules/backend.md`).

## Formato de Response

Item único:

```json
{
  "data": { },
  "message": "Produto criado com sucesso."
}
```

Erro:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dados inválidos.",
    "details": [
      { "field": "name", "message": "Informe o nome." }
    ]
  }
}
```

- `code` em `UPPER_SNAKE_CASE`.
- `details` só em erro de validação: um item por campo inválido, como o `errorResponse` monta.
- `message` sempre em português, escrita para o usuário final.
- Nunca dado sensível na resposta: hash de senha, token, e-mail de terceiro.
- Exceção intencional: listagens retornam `PaginatedResponse<T>` puro, sem o wrapper `{ data }`.

## Paginação

```ts
// src/lib/types/api.ts
export type PaginatedResponse<T> = {
  items: T[];
  totalCount: number;
  page: number;
  pageSize: number;
  totalPages: number;
};
```

| Param | Tipo | Default |
|-------|------|---------|
| `page` | `number` | `1` |
| `pageSize` | `number` | `25` |

```json
{
  "items": [],
  "totalCount": 150,
  "page": 1,
  "pageSize": 25,
  "totalPages": 6
}
```

Não paginar tabela de apoio com poucos registros e estrutura fixa (categorias, status, unidades): retornar a lista completa.

## Filtros e Ordenação

| Tipo | Exemplo | Uso |
|------|---------|-----|
| Seleção múltipla | `status=1&status=2` | Vários valores do mesmo campo |
| Valor único | `categoryId=<uuid>` | Filtro por FK |
| Busca textual | `search=text` | `ilike` em um ou mais campos |
| Semântico | `dueDate=overdue` | Regra de data traduzida no service |

| Param | Tipo | Default |
|-------|------|---------|
| `sortBy` | `string` | `createdAt` |
| `sortDirection` | `"asc" \| "desc"` | `desc` |

- Filtros combinam com `AND`.
- Campo de ordenação sempre validado contra uma lista fechada (`z.enum`): nunca interpolar o valor recebido em SQL.
- Default de ordenação: mais recente primeiro.

## Handler de Listagem

```ts
// src/app/api/products/route.ts
import { NextResponse, type NextRequest } from "next/server";
import { errorResponse } from "@/lib/api-error";
import { createProduct, listProducts } from "@/lib/services/products";
import { createProductSchema, listProductsSchema } from "@/lib/validations/products";

export async function GET(request: NextRequest): Promise<NextResponse> {
  try {
    const params = request.nextUrl.searchParams;
    const filters = listProductsSchema.parse({
      ...Object.fromEntries(params),
      status: params.getAll("status"),
    });

    return NextResponse.json(await listProducts(filters));
  } catch (error) {
    return errorResponse(error);
  }
}

export async function POST(request: NextRequest): Promise<NextResponse> {
  try {
    const body: unknown = await request.json();
    const product = await createProduct(createProductSchema.parse(body));

    return NextResponse.json(
      { data: product, message: "Produto criado com sucesso." },
      { status: 201, headers: { Location: `/api/products/${product.id}` } },
    );
  } catch (error) {
    return errorResponse(error);
  }
}
```

## Handler de Item Único

`params` é uma Promise nas versões atuais do Next: sempre `await` antes de usar.

```ts
// src/app/api/products/[id]/route.ts
import { NextResponse, type NextRequest } from "next/server";
import { z } from "zod";
import { AppError, errorResponse } from "@/lib/api-error";
import { updateProduct, deleteProduct, getProduct } from "@/lib/services/products";
import { updateProductSchema } from "@/lib/validations/products";

const routeParamsSchema = z.object({ id: z.uuid("Identificador inválido.") });

type Context = { params: Promise<{ id: string }> };

export async function GET(_request: NextRequest, { params }: Context): Promise<NextResponse> {
  try {
    const { id } = routeParamsSchema.parse(await params);
    const product = await getProduct(id);

    if (!product) throw new AppError("Produto não encontrado.", "NOT_FOUND", 404);

    return NextResponse.json({ data: product });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function PATCH(request: NextRequest, { params }: Context): Promise<NextResponse> {
  try {
    const { id } = routeParamsSchema.parse(await params);
    const body: unknown = await request.json();
    const product = await updateProduct(id, updateProductSchema.parse(body));

    return NextResponse.json({ data: product, message: "Produto atualizado com sucesso." });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function DELETE(_request: NextRequest, { params }: Context): Promise<NextResponse> {
  try {
    const { id } = routeParamsSchema.parse(await params);
    await deleteProduct(id);

    return new NextResponse(null, { status: 204 });
  } catch (error) {
    return errorResponse(error);
  }
}
```

## Proteção de Rotas

- Todo Route Handler que não seja público verifica a sessão antes de qualquer coisa.
- `proxy.ts` bloqueia rotas privadas no geral, mas o handler valida de novo: proxy não substitui checagem no servidor.
- Detalhes de Auth.js, sessão e proxy em `rules/backend.md`.

```ts
const session = await auth();
if (!session?.user) throw new AppError("Não autenticado.", "UNAUTHORIZED", 401);
```

## Consumo no Cliente

Um cliente tipado, com tratamento de erro centralizado:

```ts
// src/lib/api/client.ts
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: string,
  ) {
    super(message);
  }
}

type ErrorPayload = { error?: { code?: string; message?: string } };

export async function apiFetch<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });

  if (response.status === 204) return undefined as T;

  const payload: unknown = await response.json();

  if (!response.ok) {
    const { error } = payload as ErrorPayload;
    throw new ApiError(error?.message ?? "Falha na requisição.", response.status, error?.code ?? "UNKNOWN");
  }

  return payload as T;
}
```

TanStack Query para leitura com cache no cliente:

```ts
// src/features/products/hooks/use-products.ts
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { apiFetch } from "@/lib/api/client";
import type { PaginatedResponse } from "@/lib/types/api";
import type { ProductListItem } from "@/features/products/types";

export function useProducts(filters: Record<string, string>) {
  const query = new URLSearchParams(filters).toString();

  return useQuery({
    queryKey: ["products", filters],
    queryFn: () => apiFetch<PaginatedResponse<ProductListItem>>(`/api/products?${query}`),
    placeholderData: keepPreviousData,
  });
}
```

- Um `queryKey` por recurso mais filtros: a invalidação fica previsível.
- Erro de rede e erro de API caem no mesmo `ApiError`: a UI trata um tipo só.
- Leitura que aparece na primeira pintura não precisa de `fetch`: buscar direto no Server Component.
- Toda tela com dados assíncronos trata loading, vazio e erro (ver `rules/codigo.md`).

## Versionamento

- Versionar só quando existe consumidor externo que você não controla.
- Breaking change vira nova pasta: `app/api/v2/products/route.ts`.
- Manter a versão anterior ativa durante a migração.
