# Regras de Testes

Stack única: Vitest + Testing Library, para unidade e para integração de componentes e funções. Playwright entra só como opção de E2E quando o projeto pedir.

## Fluxo obrigatório

- Fluxo: desenvolver, validar funcionando, escrever testes, rodar a suíte completa.
- Testes são escritos DEPOIS da implementação validada funcionalmente (código estável), e SEMPRE antes do commit.
- Nunca commitar lógica nova sem testes. Pular só com pedido explícito do usuário, registrado como pendência.
- Se falhar, corrigir antes de seguir.

## Só o essencial

Teste existe para pegar bug real, não para fazer volume. Antes de escrever, perguntar: "se este teste não existisse, algum bug passaria?". Se a resposta é não, não escrever.

### Testar

- Regra de negócio com decisão real: cálculo, condição, validação que rejeita algo.
- Bug corrigido: um teste de regressão que reproduz o bug.
- O caminho principal do fluxo (1 teste feliz) e os erros que importam para o usuário (1 a 3 testes). Nunca matriz combinatória de entradas.

### Não testar

- CRUD que só repassa dados (handler, service ou consulta sem regra).
- Mapeamento de objeto, getters, wrappers de biblioteca.
- O que o TypeScript ou o Zod já garante.
- Teste que só repete a implementação (mock devolve X, assert que retornou X).

### Teto

- Por regra ou função: 1 caminho feliz mais os erros relevantes. Passou de 4 testes na mesma função, é excesso.

---

## Vitest + Testing Library

- Vitest como framework, para código de cliente e de servidor.
- Testing Library para testar pelo comportamento, não pela implementação: buscar por role, label e texto, nunca por classe CSS ou estrutura interna.
- Arquivo junto do código testado: `Button.test.tsx`, `useProducts.test.ts`, `productService.test.ts`.
- Componentes com DOM rodam no ambiente `jsdom`. Código de servidor roda em `node`.

### O que testar no cliente

- Hooks customizados: lógica pura, fácil de testar.
- Funções utilitárias: alto retorno, baixo custo.
- Componentes com lógica condicional (carregando, erro, permissão, vazio).

### O que NÃO testar no cliente

- Componente puramente presentacional, sem lógica.
- Tipos TypeScript.
- O que o Zod já valida.

```tsx
import { render, screen, fireEvent } from "@testing-library/react";
import { Button } from "./Button";

it("calls onClick when clicked", () => {
  const onClick = vi.fn();
  render(<Button onClick={onClick}>Salvar</Button>);
  fireEvent.click(screen.getByRole("button", { name: "Salvar" }));
  expect(onClick).toHaveBeenCalledTimes(1);
});

it("disables the button when isLoading", () => {
  render(<Button isLoading>Salvar</Button>);
  expect(screen.getByRole("button")).toBeDisabled();
});
```

---

## Código de servidor no Next.js

- Funções de service e regras de negócio: testar direto, chamando a função e mockando o acesso ao banco. Nada de subir servidor.
- Schemas Zod: testar só quando a validação tem regra própria (refine, transform, dependência entre campos). Campo obrigatório simples não precisa de teste.
- Route Handler: importar a função exportada (`GET`, `POST`) e chamá-la com um `Request`, checando status e corpo da resposta. Sem servidor, sem HTTP real.

```ts
import { POST } from "@/app/api/products/route";

it("returns 400 when payload is invalid", async () => {
  const response = await POST(
    new Request("http://localhost/api/products", {
      method: "POST",
      body: JSON.stringify({ name: "" }),
    }),
  );

  expect(response.status).toBe(400);
});
```

---

## E2E - opcional

Playwright, só quando o projeto pedir teste ponta a ponta. Cobrir o fluxo crítico do usuário (login, fluxo principal), não a tela inteira.

---

## Build - Validação final

- `npm run build` e `npx tsc --noEmit` antes de entregar.
- Nunca entregar com erro ou warning de build.
