---
description: Gauntlet Loop, polimento até um padrão de referência. Divide o objetivo em partes, cada parte com builder e crítico separados; o crítico compara às cegas contra uma referência concreta e o loop repete até vencer. Usar quando o usuário pedir gauntlet, "deixar no nível de X", ou polir algo que já existe até uma barra mensurável. Custa horas e exige referência inspecionável.
---

# /gauntlet - Loop de qualidade com crítico cego

Método popularizado por Matt Shumer (julho/2026). A ideia em uma frase: quem constrói nunca julga o próprio trabalho. Um agente constrói, outro agente com contexto zerado compara o resultado real com uma referência concreta, às cegas, e escolhe um vencedor. Perdeu, constrói de novo. O loop só para quando vence ou quando o orçamento acaba.

Você (sessão principal) é o lead: decompõe, despacha, captura evidência, aplica o veredito e mantém o placar. Você nunca constrói nem julga.

## Quando usar e quando não usar

| Situação | Gauntlet? |
|----------|-----------|
| Polir algo que já existe até uma referência real (tela, jogo, algoritmo, texto) | Sim |
| Saída inspecionável: pixels, tempo medido, HTML renderizado, saída de teste, dado estruturado | Sim |
| Projeto do zero sem referência nem contrato | Não. O loop amplifica o "premium genérico" do modelo e queima orçamento sem convergir |
| Regra de negócio nova sem produto para comparar | Só no modo gabarito (abaixo) |
| Expectativa de resultado em minutos | Não. Gauntlet é medido em horas |

Regra de ouro: sem referência concreta no disco, não roda. "Deixa bonito" e "nível AAA" não são referência.

## Pré-voo obrigatório

Antes de gastar um token com agente, fechar os cinco itens com o usuário:

1. **Referência.** O que é, onde está. Copiar para `gauntlet/reference/` no projeto: screenshots, medições, documentação oficial, saída esperada. Referência precisa ser nomeada (uma coisa específica), acessível (o crítico consegue abrir) e comparável (cabe lado a lado com a saída).

2. **Evidência.** Como capturar o resultado de cada parte, de forma mecânica e repetível: script de screenshot, saída de `vitest`, medição de tempo, `curl` do endpoint, HTML renderizado. Evidência capturada na mão não vale.

3. **Ponto de partida.** O projeto roda e o build passa. Gauntlet não conserta base quebrada.

4. **Orçamento.** Rodadas máximas por parte (padrão 5), agentes em paralelo (máximo 5), teto de tempo. O usuário aprova o orçamento antes do início.

5. **Branch.** Confirmar a branch de trabalho, como em todo fluxo.

Sem os cinco fechados, parar e reportar o que falta.

## Modo gabarito (sem referência externa)

Para regra de negócio ou produto novo, não existe concorrente para comparar. Nesse caso a referência é construída antes do loop:

1. Interrogar o usuário sobre toda decisão não resolvida: comportamento em cada caso, o que é erro, o que é sucesso, limites, formatos.
2. Pesquisar ou prototipar até cada ambiguidade virar decisão.
3. Escrever `gauntlet/spec.md` (o que o sistema faz) e `gauntlet/gabarito.md` (lista de verificações objetivas, cada uma com entrada, saída esperada e como medir).
4. Usuário aprova o gabarito. Só então o loop começa.

No modo gabarito, o crítico não compara A com B: verifica a evidência contra cada item do gabarito e reporta PASSA ou FALHA por item.

## Fluxo

### 1. Decompor

Quebrar o objetivo em partes que melhoram de forma independente. Para cada parte, registrar:

```text
Parte      | Evidência                          | Referência                  | Builder
hero       | screenshot 1440x900 via script     | reference/hero-ref.png      | frontend-dev
ranking    | saída de vitest + tempo p95        | gabarito.md itens 1 a 4     | backend-dev
```

Parte sem evidência mecânica ou sem referência não entra no loop.

### 2. Rodada

Para cada parte, repetir até vencer ou esgotar o orçamento:

1. **Builder** recebe: a parte, a referência, a evidência da rodada anterior e a maior lacuna apontada pelo crítico. Nunca recebe o veredito inteiro nem instrução de "melhorar tudo": uma lacuna por rodada.
2. **Captura**: rodar o script de evidência sobre o candidato novo e sobre o melhor candidato atual.
3. **Crítico** (`agents/critic.md`, contexto zerado) recebe só: evidência A, evidência B, referência e checklist. Ordem aleatória, sem rótulo, sem código, sem raciocínio do builder.
4. **Veredito**: vencedor binário e a maior lacuna única do perdedor.
5. **Ratchet**: se o candidato novo venceu, vira o melhor atual. Se perdeu, reverter os arquivos da rodada. Se a evidência foi inválida (captura quebrada, tela cortada), a rodada é anulada, não conta no orçamento, e a captura é refeita.

Partes independentes rodam em paralelo, respeitando o teto de 5 agentes.

### 3. Placar

A cada rodada, mostrar no chat:

```text
Parte     | Rodada | Melhor atual     | Última lacuna
hero      | 3/5    | rodada 2 (venceu)| contraste do título abaixo da referência
ranking   | 1/5    | rodada 1         | p95 em 210 ms, gabarito exige 150 ms
```

### 4. Parada

O loop para quando acontecer o primeiro destes:

- A parte vence a referência (ou passa em todos os itens do gabarito).
- Três rodadas seguidas sem vitória: platô. Parar a parte e reportar a lacuna que não fecha.
- Orçamento de rodadas ou tempo esgotado.
- O usuário mandar parar. O usuário é o freio.

Nunca continuar além do orçamento aprovado sem perguntar.

### 5. Encerrar

- Relatório curto: partes vencidas, partes em platô com a lacuna aberta, rodadas gastas.
- Referência e evidências ficam em `gauntlet/` para a próxima vez.
- Commit só pelo fluxo do `/commit`, com permissão do usuário. Nenhum agente commita.

## Contrato do crítico

O crítico é o centro do método e é onde ele falha quando mal usado. Regras que o lead garante em todo despacho:

- Contexto zerado a cada rodada. O crítico nunca é reaproveitado entre rodadas.
- Recebe só evidência e referência. Nunca código, nunca o raciocínio do builder, nunca qual candidato é o novo.
- Escolha binária forçada. Sem nota de 0 a 10, sem "os dois estão bons": nota numérica sobe sozinha com o tempo e o loop nunca para.
- Nunca inferir comportamento dinâmico a partir de imagem estática. Tempo, animação, ordem de eventos e regra de ciclo de vida só contam com medição ou teste. Sem medição, o item é "não verificável", e não verificável não é vitória.
- Evidência inválida anula a rodada. Screenshot cortado, teste que não rodou, captura fora do tamanho combinado: o crítico declara inválido e o lead refaz a captura.

## Custo real

Um dia de agente para convergir quando existe referência. Contas de centenas de dólares e código inútil quando não existe. Por isso o pré-voo é obrigatório e o orçamento é aprovado antes.

## Inegociáveis

- Sem referência no disco, o loop não começa.
- Builder e crítico nunca são o mesmo agente, e o crítico nunca vê o processo, só o resultado.
- Uma lacuna por rodada para o builder. Lista de dez ajustes vira retrabalho disperso.
- Placar a cada rodada. Loop silencioso é loop fora de controle.
- Orçamento aprovado é teto. Platô de 3 rodadas para a parte.
- Nenhum agente commita, dá push ou cria branch.
