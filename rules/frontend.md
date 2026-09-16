# Regras de Frontend - Next.js App Router + TypeScript + Tailwind

> Regras universais, válidas para todo projeto Next.js.
> Projeto fullstack em um repositório só: UI, Route Handlers, acesso ao banco e autenticação convivem no mesmo app.
> Sempre usar a versão mais recente do Next.js com App Router. Gerenciador de pacotes: npm.

## Estrutura de Pastas

```text
<projeto>/
├── prisma/                          # schema.prisma, migrations, seed (ver rules/database.md)
└── src/
    ├── app/                         # Rotas (App Router)
    │   ├── layout.tsx               # Layout raiz
    │   ├── page.tsx                 # Home
    │   ├── loading.tsx              # Estado de carregamento da rota
    │   ├── error.tsx                # Estado de erro da rota ("use client")
    │   ├── not-found.tsx            # 404
    │   ├── (auth)/                  # Grupo de rotas, não entra na URL
    │   ├── <domain>/
    │   │   ├── page.tsx
    │   │   ├── [id]/page.tsx        # Rota dinâmica
    │   │   └── loading.tsx
    │   └── api/<resource>/route.ts  # Route Handlers
    ├── components/ui/               # Primitivos de UI (Button, Input, Modal...)
    ├── components/layout/           # Layout (Sidebar, Header, PageWrapper...)
    ├── features/<domain>/           # Domínio, quando o projeto tem peso para isso
    │   ├── components/
    │   └── hooks/
    ├── lib/
    │   ├── db.ts                    # Instância singleton do PrismaClient
    │   ├── auth.ts                  # Configuração do Auth.js
    │   ├── services/                # Regra de negócio, um arquivo por domínio
    │   ├── validations/             # Schemas Zod + tipos inferidos
    │   ├── hooks/                   # Hooks globais (useDebounce...)
    │   ├── cn.ts
    │   └── utils/                   # Funções puras
    ├── generated/prisma/            # Prisma Client gerado, nunca editar
    ├── styles/globals.css           # Tokens de cor e camadas do Tailwind
    └── proxy.ts                     # Auth.js na borda (antigo middleware.ts)
```

- Projeto pequeno dispensa `features/`: deixar tudo em `lib/` e `components/`. Criar pasta de domínio só quando houver mais de um punhado de arquivos por assunto.
- `app/` guarda rota, layout e estado de rota. Lógica de negócio mora em `lib/services/` (ver `rules/backend.md`).

## Server Components e Client Components

- Todo componente é Server Component por padrão. Não escrever `"use client"` por hábito.
- `"use client"` só quando o componente precisa de: estado (`useState`, `useReducer`), efeito (`useEffect`), evento do usuário (`onClick`, `onChange`), hook de navegação (`useRouter`, `usePathname`) ou API do navegador (`window`, `localStorage`).
- Empurrar o `"use client"` para a folha: a página busca os dados no servidor e passa por props para um componente cliente pequeno.
- Segredo (chave de API, string de conexão, token) nunca entra em componente cliente, nem por props.

```tsx
// src/app/products/page.tsx - Server Component, sem "use client"
import { listProducts } from "@/lib/services/products";
import { ProductFilter } from "@/features/products/components/product-filter";

export default async function ProductsPage() {
  const products = await listProducts();
  return <ProductFilter products={products} />;
}
```

```tsx
// src/features/products/components/product-filter.tsx
"use client";

import { useState } from "react";

export function ProductFilter({ products }: { products: ProductListItem[] }) {
  const [search, setSearch] = useState("");
  // ...
}
```

## Data Fetching

- Buscar dados no servidor sempre que possível: Server Component `async` chamando o service, que fala com o Prisma ou com a API externa.
- Mutação vinda do cliente: Server Action ou Route Handler. Depois de gravar, revalidar com `revalidatePath` ou `revalidateTag`.
- TanStack Query só para dados do cliente que precisam de cache, refetch, paginação interativa ou polling. Não usar no primeiro carregamento que o servidor já resolve.
- Nunca chamar `fetch` de rota interna (`/api/...`) dentro de um Server Component: chamar a função de service direto.

```ts
// src/lib/services/products.ts
import "server-only";
import { prisma } from "@/lib/db";
import { productListSelect, type ProductListItem } from "@/lib/services/products-select";

export async function listProducts(): Promise<ProductListItem[]> {
  return prisma.product.findMany({ where: { deletedAt: null }, select: productListSelect });
}
```

## Padrão de Componente

- Helper de classes (composição condicional e merge de Tailwind): todo projeto usa `cn` de `lib/cn.ts`. Nunca instalar `clsx`. A única dependência é `tailwind-merge`, que resolve conflito de classes (`px-2` contra `px-4`) e embute a taxonomia inteira do Tailwind.

```ts
// src/lib/cn.ts
import { twMerge } from "tailwind-merge";

type ClassValue =
  | string
  | number
  | boolean
  | null
  | undefined
  | ClassValue[]
  | { [key: string]: unknown };

function flatten(value: ClassValue): string {
  if (typeof value === "string" || typeof value === "number") return String(value);
  if (!value || value === true) return "";
  if (Array.isArray(value)) return value.map(flatten).filter(Boolean).join(" ");
  return Object.entries(value)
    .filter(([, cond]) => Boolean(cond))
    .map(([key]) => key)
    .join(" ");
}

export function cn(...inputs: ClassValue[]): string {
  return twMerge(inputs.map(flatten).filter(Boolean).join(" "));
}
```

- Variantes declaradas como objetos de mapeamento: `Record<Variant, string>`.
- Tipagem explícita com TypeScript (regras gerais em `rules/codigo.md`).
- Valor padrão nas props opcionais.
- `className` sempre aceito para extensão externa.
- Antes de criar qualquer componente, verificar se já existe algo reutilizável no projeto.
- Se houver potencial de reuso, criar genérico, não só para o caso atual.

```tsx
type ButtonVariant = "primary" | "secondary" | "ghost";

type ButtonProps = {
  children?: React.ReactNode;
  variant?: ButtonVariant;
  icon?: React.ReactNode;
  className?: string;
  onClick?: () => void;
  disabled?: boolean;
  isLoading?: boolean;
  type?: "button" | "submit" | "reset";
};

const variantClasses: Record<ButtonVariant, string> = {
  primary: "bg-primary text-primary-foreground",
  secondary: "bg-background text-foreground border border-border",
  ghost: "bg-transparent text-foreground hover:text-primary",
};
```

## Navegação - App Router

- Roteamento por pastas dentro de `app/`: cada pasta é um segmento de URL e `page.tsx` é a página.
- Nomes de pasta em `kebab-case`. Parâmetro dinâmico entre colchetes: `[id]`, `[...slug]`.
- Arquivos especiais por segmento: `layout.tsx` (casca compartilhada), `loading.tsx`, `error.tsx`, `not-found.tsx`.
- Grupo de rotas com parênteses, como `(auth)`, organiza pastas sem entrar na URL.
- Navegação com `Link` de `next/link`. Nunca `<a>` para rota interna.
- Navegação programática e leitura da URL com `useRouter`, `usePathname` e `useSearchParams` de `next/navigation`, só em Client Component. No servidor, `params` e `searchParams` chegam por props da página.

```tsx
// src/app/products/[id]/page.tsx
import { notFound } from "next/navigation";

export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const product = await getProduct(id);
  if (!product) notFound();
  return <ProductDetail product={product} />;
}
```

## Formulários - React Hook Form + Zod

- Todo formulário usa React Hook Form + Zod. Nunca gerenciar campo de formulário com `useState`. Para estado de UI (modal aberto, página atual, filtros), `useState` é normal e esperado.
- Formulário é Client Component: `"use client"` no topo do arquivo.
- Schema Zod em arquivo separado: `lib/validations/<domain>.ts`. O schema é a fonte da verdade, nunca duplicar validação.
- O mesmo schema valida no servidor, no Route Handler ou na Server Action. Validação no cliente não substitui validação no servidor.
- Erro de campo: inline abaixo do campo. Erro de API: toast.
- Mensagens em português: `"O e-mail é obrigatório."`, não `"email: required"`.
- Desabilitar o submit durante `isSubmitting`.
- Usar `resolver` via `@hookform/resolvers/zod`.

```tsx
const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<Schema>({
  resolver: zodResolver(schema),
});
```

## Estados de UI - Obrigatório

Toda tela com dados assíncronos trata os 3 estados: carregando, erro e vazio.

No servidor, o App Router resolve carregando e erro por arquivo:

```tsx
// src/app/products/loading.tsx
export default function Loading() {
  return <Skeleton />;
}
```

```tsx
// src/app/products/error.tsx
"use client";

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return <ErrorState message="Não foi possível carregar os produtos." onRetry={reset} />; // nunca error.message: pode vazar detalhe técnico
}
```

O estado vazio é sempre do componente, o App Router não cobre isso:

```tsx
if (!products.length) return <EmptyState message="Nenhum produto encontrado." />;
```

No cliente com TanStack Query, os 3 estados ficam no componente:

```tsx
const { data, isLoading, isError, refetch } = useQuery({ /* ... */ });

if (isLoading) return <Skeleton />;
if (isError) return <ErrorState onRetry={refetch} />;
if (!data?.length) return <EmptyState message="Nenhum item encontrado." />;
```

- Criar componentes reutilizáveis `<Skeleton />`, `<EmptyState />` e `<ErrorState />` em `components/ui/`.
- Nunca tela em branco, nunca lista vazia sem feedback.

## Hooks

- Hooks customizados para isolar lógica de estado e requisição do cliente.
- Prefixo `use` obrigatório: `useProducts`, `useDebounce`.
- Hooks ficam em `features/<domain>/hooks/` ou `lib/hooks/` se global.
- Hook de React é código de cliente: o arquivo que o usa precisa de `"use client"`.

## Serviços e Route Handlers

- `lib/services/` tem um arquivo por domínio com funções tipadas: consultas Prisma, regra de negócio e chamadas a APIs externas.
- Server Component chama o service direto. Route Handler chama o mesmo service, sem duplicar regra.
- Route Handler valida a entrada com Zod antes de qualquer coisa e devolve status coerente (ver `rules/api.md`).
- Toda rota que exige usuário logado confere a sessão do Auth.js antes de executar (ver `rules/security.md`).

```ts
// src/app/api/products/route.ts
import { NextResponse } from "next/server";
import { errorResponse } from "@/lib/api-error";
import { createProduct } from "@/lib/services/products";
import { createProductSchema } from "@/lib/validations/products";

export async function POST(request: Request) {
  try {
    const data = createProductSchema.parse(await request.json());
    const product = await createProduct(data);
    return NextResponse.json({ data: product, message: "Produto criado com sucesso." }, { status: 201 });
  } catch (error) {
    return errorResponse(error); // Zod vira 422, AppError vira o status dela, o resto vira 500
  }
}
```

- No cliente, o tratamento de erro de resposta fica centralizado no `ApiError` de `lib/api/client.ts` (ver `rules/api.md`), com mensagem em português. Nunca mostrar stack trace na tela.

## Variáveis de Ambiente

- Só variáveis com prefixo `NEXT_PUBLIC_` chegam ao navegador: `NEXT_PUBLIC_APP_NAME`, `NEXT_PUBLIC_APP_URL`.
- Segredo fica sem prefixo e só é lido em código de servidor: `DATABASE_URL`, `AUTH_SECRET`.
- Nunca colocar segredo em variável `NEXT_PUBLIC_`, nem importar módulo de servidor dentro de Client Component.
- Manter `.env.example` atualizado com todas as chaves e valores fictícios.

## Imagens e Fontes

- Imagens com `Image` de `next/image`: informar `width` e `height`, ou `fill` com container posicionado, e `alt` descritivo. Domínio externo precisa estar liberado no `next.config`.
- Fontes com `next/font`, carregadas no `layout.tsx` raiz e expostas como variável CSS. Nunca `<link>` para CDN de fonte.

```tsx
// src/app/layout.tsx
import { Inter } from "next/font/google";

const inter = Inter({ subsets: ["latin"], variable: "--font-sans" });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={inter.variable}>
      <body>{children}</body>
    </html>
  );
}
```

## Estilos - Tailwind

- Estas regras não pré-definem nenhuma cor, fonte ou estilo visual. Cada projeto decide a identidade visual na hora, junto com o usuário. Pedir referência (Figma, screenshot, site de referência) antes de escolher a paleta.
- As cores decididas viram tokens em `styles/globals.css`, dentro de `@theme`, com prefixo `--color-`.
- Usar no Tailwind sem prefixo: `bg-primary`, `text-foreground`, `border-border`.
- Nunca hex ou rgb hardcoded em componente: sempre via token.
- Nunca adicionar `* { padding: 0; margin: 0 }`: o Preflight já faz o reset.
- Componentes compõem classes com o `cn` de `lib/cn.ts`.

### Modo escuro - básico obrigatório

Todo projeto nasce com modo claro e escuro. Não é feature para depois: quando o design não define as cores do escuro, derivar do claro e confirmar com o usuário.

- Token semântico, nunca cor crua: `--background`, `--foreground`, `--primary`, `--muted`, `--border`. O componente usa `bg-background text-foreground`; a cor real muda por tema.
- Os dois temas vivem no `styles/globals.css`: valores claros em `:root`, escuros em `.dark`, e o `@theme inline` liga cada token ao Tailwind. `@theme` só funciona no topo do arquivo, por isso a troca fica fora dele.
- Ativação por classe, não por `prefers-color-scheme` direto: `@custom-variant dark (&:where(.dark, .dark *));`. Assim o usuário consegue trocar à mão.
- Padrão inicial segue o sistema; escolha manual persiste em `localStorage.theme`. Um `<script>` inline no `<head>` do layout raiz aplica a classe `dark` no `<html>` antes da primeira pintura, para não piscar. `<html suppressHydrationWarning>` porque a classe muda no cliente.
- Nunca `dark:bg-gray-800` solto em componente. Se um componente precisa de uma cor que não existe, cria o token nos dois temas primeiro.
- Contraste de 4.5:1 vale nos dois temas: conferir o escuro também, não só o claro.
- O script inline do tema só roda se a CSP permitir script inline. A CSP padrão do `rules/security.md` já permite; com CSP de nonce, passar o nonce no `<script>`.

```css
/* src/styles/globals.css */
@import "tailwindcss";
@custom-variant dark (&:where(.dark, .dark *));

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.15 0 0);
}

.dark {
  --background: oklch(0.15 0 0);
  --foreground: oklch(0.98 0 0);
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
}
```

```tsx
// src/app/layout.tsx - trecho: aplica o tema antes da primeira pintura
<html lang="pt-BR" suppressHydrationWarning>
  <head>
    <script
      dangerouslySetInnerHTML={{
        __html: `document.documentElement.classList.toggle("dark", localStorage.theme === "dark" || (!("theme" in localStorage) && matchMedia("(prefers-color-scheme: dark)").matches))`,
      }}
    />
  </head>
```

## Acessibilidade

- Todo elemento interativo acessível pelo teclado (`Tab`, `Enter`, `Escape`).
- Tags semânticas: `<button>` para ação, `<a>` ou `Link` para navegação, `<nav>`, `<main>`, `<section>`.
- Nunca `<div>` ou `<span>` clicável sem `role` e `tabIndex`.
- Imagens com `alt` descritivo. Decorativas: `alt=""`.
- Ícone sem texto: `aria-label` ou `aria-hidden`.
- Contraste mínimo 4.5:1 (WCAG AA).
- Foco visível sempre (`focus:ring-2`). Modal prende o foco.
- Campo de formulário com `<label>` ligado por `htmlFor` e `id`.
- `lang="pt-BR"` no `<html>` do layout raiz.

## Performance

- Server Component por padrão já reduz o JavaScript enviado ao navegador: essa é a primeira alavanca.
- `dynamic` de `next/dynamic` para componente cliente pesado que não aparece na primeira dobra.
- `Suspense` para streaming das partes lentas da página, em vez de segurar a página inteira.
- `React.memo`, `useCallback` e `useMemo` só onde há re-render medido, não por precaução.
- Cache com TanStack Query nos dados do cliente, especialmente em dashboard.
- Evitar overfetching: selecionar só as colunas e os registros necessários na consulta.

## SEO - Landing pages e páginas de marketing

Toda página pública (landing, institucional, preços, blog, página de produto) nasce pensando em SEO. Página privada (dashboard, área logada) não indexa.

- Antes de escrever o conteúdo, fechar com o usuário a palavra-chave principal e a intenção de busca de cada página. Título, H1, descrição e URL usam essa palavra-chave de forma natural, sem repetição forçada.
- `metadata` ou `generateMetadata` em toda `page.tsx` pública: `title` (até 60 caracteres, palavra-chave no começo), `description` (até 160, com chamada para ação), `openGraph` (title, description, imagem 1200x630, url, siteName, locale `pt_BR`), `twitter` (`summary_large_image`) e `alternates.canonical`. `metadataBase` definido no layout raiz.
- Um só `<h1>` por página, hierarquia `h2`/`h3` sem pular nível. Texto real em HTML, nunca só dentro de imagem.
- URL curta, em kebab-case, sem parâmetro desnecessário. Slug em português para conteúdo em português.
- Dados estruturados JSON-LD conforme o tipo da página (`Organization`, `WebSite`, `Product`, `FAQPage`, `Article`, `BreadcrumbList`) em `<script type="application/ld+json">`. Validar no Rich Results Test do Google.
- `app/sitemap.ts` e `app/robots.ts` gerados pelo Next. Página privada recebe `robots: { index: false, follow: false }` no metadata.
- Landing page é estática (SSG) ou ISR, nunca `force-dynamic` sem motivo: o crawler recebe o HTML completo do Server Component.
- Imagem da primeira dobra com `priority` (é o LCP). As demais com lazy loading, que é o padrão do `next/image`.
- Conteúdo suficiente para responder a intenção de busca e uma chamada para ação clara acima da dobra. Página fina (só título e botão) não ranqueia.
- Critério de pronto: Lighthouse mobile com 90+ em Performance e SEO; LCP abaixo de 2,5 s, INP abaixo de 200 ms, CLS abaixo de 0,1.

## Formatação

- Datas e moedas com `Intl.DateTimeFormat` e `Intl.NumberFormat`, nunca formatação manual.
- Manipulação de datas com date-fns, nunca moment.js, dayjs ou cálculo na mão.
- Formatação que roda no servidor e no cliente precisa usar o mesmo locale e o mesmo fuso, senão o React acusa erro de hidratação.

## Tabelas

- Tabela simples de leitura: `<table>` semântica, sem biblioteca.
- Tabela com ordenação, paginação ou seleção: TanStack Table.
- Coluna ordenável tem botão de ordenar no header (asc/desc), e a ordenação envia `sortBy` e `sortDirection` para a API (ver `rules/api.md`).
- Ordenar e paginar no servidor quando o volume passa de algumas centenas de linhas.

## Paginação

- Usar o formato de resposta paginada definido em `rules/api.md`.
- `page`, `pageSize`, `sortBy` e `sortDirection` vivem nos query params da URL: a página fica compartilhável e sobrevive ao refresh.
- `pageSize` padrão: 25. Opções disponíveis: 25, 50, 100. A API limita a 100 (ver `rules/api.md`), então não oferecer valor acima disso.
- Sempre exibir total de registros e página atual.
- Componente reutilizável em `components/ui/pagination.tsx`: seletor de itens por página, navegação de páginas e total de registros.

### Exemplo

```tsx
"use client";

import { useRouter, useSearchParams } from "next/navigation";

export function ProductsTable({ data }: { data: PaginatedResponse<Product> }) {
  const router = useRouter();
  const searchParams = useSearchParams();

  function updateParams(updates: Record<string, string>) {
    const params = new URLSearchParams(searchParams);
    Object.entries(updates).forEach(([key, value]) => params.set(key, value));
    router.push("?" + params.toString());
  }

  return (
    <Pagination
      page={data.page}
      pageSize={data.pageSize}
      totalCount={data.totalCount}
      totalPages={data.totalPages}
      pageSizeOptions={[25, 50, 100]}
      onPageChange={(page) => updateParams({ page: String(page) })}
      onPageSizeChange={(size) => updateParams({ pageSize: String(size), page: "1" })}
    />
  );
}
```
