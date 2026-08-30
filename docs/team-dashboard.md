# Dash do time da obra

> Regra curta no [`AGENTS.md`](../AGENTS.md). Aqui está o porquê.
> Presenter: [`TeamDashboard`](../app/presenters/team_dashboard.rb)
> · Spec: [`spec/presenters/team_dashboard_spec.rb`](../spec/presenters/team_dashboard_spec.rb)
> · Complemento: [Campo](field.md) · [Arrecadação](funding.md)

A segunda das três dashes. Ela responde, obra por obra: em que pé está o
cronograma, quanto do orçamento já foi executado, quanto a obra arrecadou, e
para quando é a entrega.

Os quatro números que ela lê de uma obra saem do `ProjectAccounting`, e não do
painel: quem sabe orçar, gastar e arrecadar é a obra — o painel só arruma na
tela. É a mesma razão de `Project#reach_for` existir do lado do investidor.

Nenhuma coluna nova. Tudo já existia — `Project` guarda as quatro datas e o
avanço, `Budget`/`BudgetLine` o orçado, `Expense` o gasto, `Campaign` o
arrecadado. O que faltava era juntar.

## Vínculo não é chave

A obra que o leitor não alcança **não aparece, mesmo que ele esteja nela**.
`TeamDashboard#reachable` filtra as participações por `Project.visible_to`
antes de montar qualquer painel.

Parece contraintuitivo — quem trabalha na obra não a veria? — e é deliberado.
`ProjectParticipation` responde "esta pessoa faz parte"; `sensitivity_level`
responde "esta pessoa alcança". As duas perguntas são diferentes, e deixar a
primeira responder pela segunda transformaria o vínculo numa porta lateral em
volta da política de visibilidade. Quem precisa alcançar recebe alcance — pela
promoção auditada, não pelo crachá.

## Convite não põe obra no painel

`participations` usa o escopo `effective`, que é `active`. Um convite pendente
não concede nada em lugar nenhum deste repositório, e aqui não seria diferente:
o painel responde "onde você trabalha", não "onde te chamaram".

## Orçamento: o aprovado, e o rascunho como segunda opção

`budget_for` procura o orçamento **aprovado** de maior versão e, não achando,
cai no rascunho mais recente.

O fallback não é preguiça. Orçamento aprovado é imutável neste domínio, então a
revisão em curso vive como rascunho — e é justamente ela que o time está
olhando quando abre o painel. Mostrar zero enquanto ninguém aprovou esconderia
o trabalho em andamento e faria a tela parecer quebrada.

Do lado do gasto, `spent_for` exclui `rejected`: despesa recusada não saiu do
caixa, e somá-la inflaria a execução.

## A barra de gasto precisou de um tipo novo

`ProgressBarComponent` tinha `physical` e `funding`. Usar `funding` para o
orçamento produzia duas mentiras de uma vez: a barra se anunciava como
"Recursos arrecadados", e o componente formata **reais** — passar centavos
mostrava R$ 233.000,00 no lugar de R$ 2.330,00.

O tipo `spending` reaproveita a razão e o valor de `funding` — a matemática de
"quanto de um alvo" é a mesma — e muda só a cor e o rótulo. A cor é `warning` e
não `accent` de propósito: gasto contra orçamento é leitura de **atenção**,
não de conquista. 90% arrecadado é boa notícia; 90% do orçamento executado com
40% de avanço físico não é.

## O que ainda não está aqui

O **fórum técnico da obra** — tópicos e mensagens, restritos a quem tem
participação ativa mais a ONG dona. É domínio novo inteiro e vem em peça
separada; nada dele existe hoje.
