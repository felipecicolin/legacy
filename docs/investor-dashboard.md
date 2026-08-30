# Dash do investidor

> Regra curta no [`AGENTS.md`](../AGENTS.md). Aqui está o porquê.
> Presenter: [`InvestorDashboard`](../app/presenters/investor_dashboard.rb)
> · Spec: [`spec/presenters/investor_dashboard_spec.rb`](../spec/presenters/investor_dashboard_spec.rb)
> · Complemento: [Visibilidade](visibility.md) · [Arrecadação](funding.md)

A primeira das três dashes. Ela responde quatro perguntas: quanto a pessoa
aportou, em que obras isso entrou, quantas pessoas essa fatia alcança por ano, e
qual o multiplicador que resume as duas últimas.

Três das quatro já derivavam do que existia. A quarta não, e é onde está a
única coluna nova.

## Por que `estimated_annual_reach` é coluna nova

A tentação é reaproveitar `ngos.people_served`. Ela não serve, por duas razões
que se somam:

1. **É da ONG inteira, não da obra.** Somá-la pelas obras de uma mesma ONG
   contaria as mesmas pessoas tantas vezes quantas obras existirem.
2. **Não tem dimensão de tempo.** "Pessoas atendidas" é um acumulado sem
   janela; "15.000 por ano" é uma taxa. Dividir uma pela outra não produz nada
   com significado.

A coluna nasce **nulável** de propósito: obra em levantamento ainda não tem
estimativa, e um zero mentiria dizendo que ela não alcança ninguém. Quem não
tem estimativa aparece na lista com alcance zero atribuído — presente, e sem
inventar número.

## A atribuição é proporcional, e sobre a META

```
alcance atribuído = estimativa_anual × (centavos aportados ÷ meta_da_obra)
```

**Por que proporcional e não a obra inteira.** Creditar as 15.000 pessoas da
obra a cada pessoa que a financiou produz um número que cresce com o número de
financiadores sem que ninguém tenha alcançado mais ninguém. O teste é somar dois
painéis: com atribuição proporcional a soma bate com a obra; com atribuição
integral ela estoura em 50×.

**Por que a meta e não o arrecadado.** O arrecadado se move toda vez que outra
pessoa doa. Dividir por ele faria o alcance creditado a quem já deu **encolher**
sozinho, sem nenhuma mudança na obra — a pessoa abriria o painel no mês seguinte
e veria seu impacto diminuir por causa da generosidade alheia. A meta é estável
e é o compromisso que a obra assumiu.

**A divisão por zero.** `funding_target_cents` tem default `0` e a CHECK permite
zero. Obra sem meta atribui alcance zero, e essa guarda vem antes da divisão —
é a primeira coisa que quebraria.

## O multiplicador

```
pessoas por ano a cada R$ 1.000 = alcance atribuído × 100.000 ÷ centavos em obra
```

A base de R$ 1.000 (`MULTIPLIER_BASE_CENTS`) existe por legibilidade: "0,047
pessoas por real" e "47 pessoas a cada R$ 1.000" são o mesmo número, e só o
segundo se lê.

O denominador é **o que entrou em obra**, não o total aportado. Dinheiro que foi
para campanha sem obra vinculada não tem alcance para dividir; mantê-lo embaixo
faria o multiplicador cair sem que obra nenhuma tivesse mudado.

## O que a visibilidade faz com cada número

O [`docs/visibility.md`](visibility.md) já tinha decidido a tensão: o investidor
não vê *todas* as obras, vê **todas as que tem direito de ver**, e recebe
agregado anonimizado no lugar das outras. Aqui isso se reparte em três
comportamentos diferentes, e a diferença importa:

| Número | O que a visibilidade faz | Por quê |
| --- | --- | --- |
| **Total aportado** | Nada. Sempre exato. | O dinheiro é dele. Esconder o próprio extrato não protege ninguém. |
| **Lista de obras** | Só as que ele alcança. | Nome, ONG e código de obra confidencial são exatamente o que o nível esconde. |
| **Alcance e contagem** | Agregado, e só acima do piso. | Um agregado de uma obra só *é* a obra. |

O piso é `Campaign::MINIMUM_AGGREGATE_COUNT`, reaproveitado e não redefinido: o
repositório tem **um** número para "poucos demais para anonimizar", e um segundo
divergiria do primeiro na primeira vez que alguém mexesse em um deles.

**Abaixo do piso, os números encolhem — e a tela diz isso.** `hidden_withheld?`
existe só para isso. Número menor sem explicação não se lê como "há algo
protegido aqui": se lê como conta errada, e a pessoa vai procurar o dinheiro que
sumiu.

## O aporte sem obra

Contribuição numa campanha com `project_id` nulo financia a ONG, não uma obra.
Ela conta no total e não tem alcance. A tela mostra a linha separada, porque as
duas alternativas são piores: dobrá-la nas obras infla a conta, e omiti-la faz a
soma das partes não bater com o total — que é o jeito mais rápido de a pessoa
deixar de confiar no painel inteiro.

## O que ainda não está decidido

O alternador entre as três dashes. Ele só passa a fazer sentido quando existir a
segunda, e construí-lo agora seria um seletor de uma opção só. Hoje a rota é
`/investidor` e a raiz continua com o placeholder.
