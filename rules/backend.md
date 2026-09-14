# Regras da Camada de Servidor - Next.js

## Onde Cada Coisa Roda

| Caso | Usar |
|------|------|
| Ler dados para renderizar a página | Server Component `async` chamando o service direto |
| Mutação vinda de formulário ou botão do próprio app | Server Action |
| Endpoint consumido por script, app externo, integração ou webhook | Route Handler |
| Upload, streaming, resposta não-JSON, CORS | Route Handler |
| Dado que precisa de cache do TanStack Query no cliente | Route Handler |
| Invalidar cache depois de gravar | Server Action com `revalidatePath` ou `revalidateTag` |

Regra prática: leitura de página não passa por `fetch` na própria API, chama o service. Route Handler existe para quem está fora do app. Contrato REST e formato de resposta em `rules/api.md`.

## Estrutura

```text
src/
├── app/
│   ├── api/<recurso>/route.ts      # Route Handlers
│   ├── (private)/products/page.tsx # Server Component
│   └── (private)/products/actions.ts
├── lib/
│   ├── services/                   # regra de negócio, um arquivo por domínio
│   ├── validations/                # schemas Zod compartilhados
│   ├── db.ts                       # instância única do PrismaClient
│   ├── auth.ts                     # configuração do Auth.js
│   ├── api-error.ts                # helper central de erro
│   └── env.ts                      # variáveis de ambiente validadas
├── generated/prisma/               # Prisma Client gerado
└── middleware.ts
```

### Regras de organização

- Regra de negócio mora em `lib/services/`. Nunca dentro do componente, do Route Handler ou da Server Action.
- Route Handler e Server Action fazem três coisas: validar entrada, chamar o service, formatar a saída.
- Service não conhece `Request`, `NextResponse` nem `FormData`: recebe dado já validado e devolve dado tipado.
- Todo arquivo de service começa com `import "server-only"`.
- Consulta ao Prisma só dentro de `lib/services/` (ver `rules/database.md`).

## Server Component

```tsx
// src/app/(private)/products/page.tsx
import { listProducts } from "@/lib/services/products";
import { ProductsTable } from "@/features/products/components/products-table";

export default async function ProductsPage() {
  const { items } = await listProducts({ page: 1, pageSize: 25 });

  return <ProductsTable products={items} />;
}
```

- Componente com `"use client"` nunca importa service, `prisma` ou `env`.
- Passar para o cliente só o que a tela usa: `select` explícito no service resolve isso na origem.
- `Decimal` e `Date` do Prisma são serializados na borda: converter para `string` ou `number` no service.

## Server Action

```ts
// src/app/(private)/products/actions.ts
"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { auth } from "@/lib/auth";
import { createProduct } from "@/lib/services/products";
import { createProductSchema } from "@/lib/validations/products";

export type FormState = {
  ok: boolean;
  message: string;
  fieldErrors?: Record<string, string[] | undefined>;
};

export async function createProductAction(
  _state: FormState,
  formData: FormData,
): Promise<FormState> {
  const session = await auth();
  if (!session?.user) return { ok: false, message: "Sessão expirada. Entre novamente." };

  const parsed = createProductSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return {
      ok: false,
      message: "Verifique os campos destacados.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
    };
  }

  await createProduct(parsed.data, session.user.id);
  revalidatePath("/products");

  return { ok: true, message: "Produto criado com sucesso." };
}
```

- Toda Server Action é um endpoint público: verificar sessão e permissão dentro dela, sempre. Esconder o botão na UI não protege nada.
- Server Action nunca recebe `id` de dono vindo do formulário: esse dado vem da sessão.
- Retornar estado tipado para o formulário, nunca lançar erro cru para a UI.
- Revalidar o cache no fim (`revalidatePath` ou `revalidateTag`).

## Validação de Entrada

Zod em toda fronteira: `body` de Route Handler, `formData` de Server Action, route params e query params.

- Um schema por operação, em `lib/validations/`, reaproveitado pelo formulário no cliente.
- Tipo derivado do schema com `z.infer`, nunca escrito duas vezes.
- `safeParse` quando o retorno é estado de formulário. `parse` dentro de `try/catch` quando o `errorResponse` cuida do 422.
- Validar também o que vem de serviço externo e de webhook: nada entra no service sem passar por schema.
- Nunca repassar o objeto inteiro do request para o Prisma: o schema define exatamente os campos aceitos.

## Tratamento de Erro

```ts
// src/lib/api-error.ts
import { NextResponse } from "next/server";
import { z, ZodError } from "zod";

export class AppError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export function errorResponse(error: unknown): NextResponse {
  if (error instanceof ZodError) {
    const fieldErrors = z.flattenError(error).fieldErrors;

    return NextResponse.json(
      {
        error: {
          code: "VALIDATION_ERROR",
          message: "Dados inválidos.",
          details: Object.entries(fieldErrors).map(([field, messages]) => ({
            field,
            message: messages?.[0] ?? "Campo inválido.",
          })),
        },
      },
      { status: 422 },
    );
  }

  if (error instanceof AppError) {
    return NextResponse.json({ error: { code: error.code, message: error.message } }, { status: error.status });
  }

  console.error(error);

  return NextResponse.json(
    { error: { code: "INTERNAL_ERROR", message: "Erro interno. Tente novamente." } },
    { status: 500 },
  );
}
```

- Um helper só para todas as respostas de erro.
- Stack trace, mensagem do Prisma e nome de coluna nunca vão para a resposta: ficam no `console.error` do servidor.
- Mensagem do usuário em português, curta, sem termo técnico.
- Erro esperado é `AppError` com código e status. Erro inesperado cai no `500` genérico.
- Regra de negócio lança `AppError` do service, não retorna `null` ambíguo.

## Autenticação com Auth.js

```ts
// src/lib/auth.ts
import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { authenticateUser } from "@/lib/services/users";

export const { handlers, auth, signIn, signOut } = NextAuth({
  session: { strategy: "jwt" },
  pages: { signIn: "/login" },
  providers: [
    Credentials({
      credentials: { email: {}, password: {} },
      authorize: async (credentials) => authenticateUser(credentials),
    }),
  ],
  callbacks: {
    jwt: ({ token, user }) => (user ? { ...token, id: user.id } : token),
    session: ({ session, token }) => ({
      ...session,
      user: { ...session.user, id: token.id as string },
    }),
  },
});
```

```ts
// src/app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/lib/auth";

export const { GET, POST } = handlers;
```

### Protegendo o servidor

```ts
// dentro de um Route Handler
const session = await auth();
if (!session?.user) throw new AppError("Não autenticado.", "UNAUTHORIZED", 401);
```

```ts
// src/middleware.ts
export { auth as middleware } from "@/lib/auth";

export const config = {
  matcher: ["/((?!api/auth|login|_next/static|_next/image|favicon.ico).*)"],
};
```

- Middleware corta o tráfego óbvio, mas não é a proteção: todo Route Handler e toda Server Action verificam a sessão de novo.
- Permissão por recurso é checada no service, comparando com o dono do registro. Ter sessão válida não dá acesso ao dado de outro usuário.
- `AUTH_SECRET` obrigatório e só em variável de ambiente.
- Senha nunca em log, nunca em resposta, nunca em `console.log`. Hash com `argon2` ou `bcrypt`.
- Ver `rules/security.md` para o resto (rate limit, headers, CSRF).

## Tipagem

- Nunca `any`. Entrada desconhecida é `unknown` e passa por Zod.
- Retorno explícito em toda função exportada de service, action e handler.
- `catch (error: unknown)`, nunca `catch (error: any)`.
- Tipo de dado do banco vem do Prisma Client (`Prisma.ProductGetPayload`), não redigitado.
- Tipo de entrada vem do schema Zod (`z.infer`), não redigitado.

## Variáveis de Ambiente

```ts
// src/lib/env.ts
import "server-only";
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.url("DATABASE_URL inválida."),
  AUTH_SECRET: z.string().min(32, "AUTH_SECRET muito curta."),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
});

export const env = envSchema.parse(process.env);
```

- Só variável com prefixo `NEXT_PUBLIC_` chega ao cliente, e ela fica embutida no bundle: nunca colocar segredo lá.
- `env.ts` é server-only. Componente cliente lê `process.env.NEXT_PUBLIC_*` direto.
- Toda chave nova entra no `.env.example` com valor fictício, no mesmo commit.
- `.env` nunca vai para o repositório.
- Validar no boot: variável faltando derruba o app na subida, não no meio de uma request.
