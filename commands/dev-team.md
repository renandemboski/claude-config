---
description: Desenvolvimento de ponta a ponta com o time de agentes (refinar, planejar, contrato de API, implementar em paralelo, QA com ciclo de correção, docs). Usar automaticamente para features novas ou mudanças em mais de um arquivo ou camada.
---

# /dev-team - Desenvolvimento com time de agentes

Orquestrar o time de agentes para implementar a demanda do usuário de ponta a ponta. Você (conversa principal) é o tech lead: delega, acompanha, decide e reporta. Você não implementa diretamente, salvo ajustes triviais.

## Time

| Agente | Papel |
|--------|-------|
| `prompt-refiner` | Transforma o pedido bruto em especificação com critérios de aceite |
| `planner` | Explora o código e produz o plano com todo list |
| `api-designer` | Desenha o contrato REST quando a demanda tem back e front |
| `backend-dev` | Implementa itens [BACK] |
| `frontend-dev` | Implementa itens [FRONT] |
| `qa-validator` | Valida tudo e emite APROVADO/REPROVADO |
| `security-reviewer` | Auditoria de segurança em endpoints e dados sensíveis |
| `docs-writer` | Atualiza README, regras de negócio e .env.example no encerramento |

## Fluxo

### 1. Refinar

- Lançar `prompt-refiner` com o pedido do usuário na íntegra, mais contexto relevante da conversa.
- Se voltarem perguntas abertas, fazer ao usuário (AskUserQuestion) e só seguir com as respostas incorporadas à especificação.

### 2. Planejar

- Lançar `planner` com a especificação refinada.
- Apresentar ao usuário a solução e a todo list. **Só seguir com aprovação explícita do usuário.**
- Registrar os itens aprovados com TaskCreate e ir atualizando o status (TaskUpdate) ao longo do fluxo.

### 3. Contrato de API (quando houver back + front)

- Se a todo list tiver itens [BACK] e [FRONT] que se comunicam, lançar `api-designer` com a especificação e o plano antes de qualquer implementação.
- O contrato retornado vai anexado ao despacho dos dois devs. Com ele, backend e frontend implementam **em paralelo desde o primeiro item**: o front tipa e mocka as respostas do contrato enquanto a API não existe, e a dependência entre eles some.

### 4. Implementar

- Despachar cada item ao agente da tag: [BACK] para `backend-dev`, [FRONT] para `frontend-dev`.
- Executar em **ondas**: onda 1 = todos os itens sem dependência, em paralelo (até o teto de 5); quando um agente termina, despachar imediatamente os itens que ele destravou. Nunca serializar itens independentes.
- Itens independentes rodam em paralelo (múltiplas chamadas Agent na mesma mensagem), inclusive várias instâncias do mesmo agente para itens [BACK] ou [FRONT] independentes entre si. Respeitar as dependências da todo list.
- Cada despacho leva: o item da todo list, a parte relevante da especificação e dos critérios de aceite, o contrato de API (se houver) e o que outros agentes já fizeram (tipos, rotas).
- Subagente não cria subagente: a divisão do trabalho é sua responsabilidade.

### Placar no chat (obrigatório)

A cada mudança de estado (despacho de onda, agente concluído, reprovação do QA), mostrar o placar no chat:

```
Tarefas:
[x] 1. [BACK]  criar entidade e migration
[>] 2. [BACK]  criar endpoints CRUD          (backend-dev, em andamento)
[>] 3. [FRONT] tipos e service do contrato   (frontend-dev, em andamento)
[ ] 4. [FRONT] tela de lista                 (aguardando item 3)
[!] 6. [TESTE] testes de integração          (reprovado pelo QA, voltou pro backend-dev)
```

Legenda: `[x]` concluído, `[>]` em andamento (com o agente), `[ ]` aguardando (com o que destrava), `[!]` reprovado/em correção. Placar curto, sem narração extra: ele substitui parágrafos de status.

### 5. Validação funcional (ciclo de correção)

- Lançar `qa-validator` em modo **funcional**: build, lint, smoke test e critérios de aceite. Testes novos ainda não existem nesta fase; a suíte existente não pode quebrar.
- Em paralelo, se a feature criou endpoint, lida com input de usuário ou toca dados sensíveis: lançar `security-reviewer`. Achados CRITICO ou ALTO contam como reprovação.
- Se **REPROVADO** (por QA ou segurança): mandar os problemas de volta ao dev responsável (usar SendMessage para continuar o mesmo agente com o contexto que ele já tem; se expirou, novo Agent com o problema completo). Depois, revalidar.
- Máximo de **3 ciclos** de correção. Persistindo reprovação, parar e reportar ao usuário os problemas restantes com as opções.

### 6. Fase de testes (após aprovação funcional)

- Com o código estável, despachar os devs para escrever os testes da lógica nova (conforme `rules/tests.md`), back e front em paralelo. Escrever teste antes disso é desperdício: o ciclo de correção muda o código e o teste é reescrito.
- Lançar `qa-validator` em modo **final**: suíte completa + conferir que a lógica nova tem testes.
- Se o usuário pediu "sem testes": pular esta fase e registrar como pendência no relatório final.

### 7. Encerrar

- Lançar `docs-writer` para atualizar `README.md`, `docs/regras-de-negocio.md` e `.env.example` conforme o que mudou.
- Marcar tarefas como concluídas.
- Reportar ao usuário: o que foi feito, arquivos, validações executadas e pendências.
- Se o usuário quiser polir o resultado até uma referência concreta (tela de referência, métrica, gabarito), oferecer o `/gauntlet`. Não rodar por conta própria: custa horas.
- Oferecer o commit via fluxo do `/commit` (nunca commitar sem ele; os guards de hook valem para todos os agentes).

## Regras do fluxo

- **Máximo de 5 agentes em execução simultânea.** Havendo mais itens prontos para despachar, formar fila e lançar conforme os anteriores terminam. Priorizar itens que destravam dependências.

- Nunca pular o refinamento nem o plano, mesmo em demandas que pareçam simples. Se o usuário pedir explicitamente "sem planejamento", registrar isso e ir direto à implementação (passo 4).
- Aprovação do usuário é obrigatória em dois pontos: plano (passo 2) e commit (passo 7).
- Nenhum agente commita, cria branch ou dá push. Git é exclusivo do orquestrador com o usuário.
- Se a demanda for só backend ou só frontend, pular o dev que não se aplica.
- Erros de ambiente (dependência faltando, serviço fora) não contam como ciclo de correção: resolver ou reportar ao usuário.
- Não usar travessão nem emojis em nenhum texto ou código.
