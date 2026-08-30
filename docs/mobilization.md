# Mobilização — necessidade, voluntariado e envio

> Regra curta no [`AGENTS.md`](../AGENTS.md). Aqui está o porquê.

## A necessidade pende de duas chaves reais, não de um polimorfismo

`Need` aponta para `mission_base` por FK **obrigatória** e para `project` por FK
**opcional**. A forma tentadora é `belongs_to :needable, polymorphic: true`, e
ela está errada aqui por três motivos concretos:

1. **Toda necessidade pertence a uma base** — a que opera a obra, quando há
   obra. O polimorfismo fingiria que existem dois donos possíveis quando existe
   um só, com um qualificador opcional.
2. **"Necessidades por país" vira um join simples**, em vez de uma consulta de
   dois ramos que alguém vai escrever errado.
3. **A FK é de verdade**, e o banco cobra integridade que o polimorfismo deixa
   para o modelo lembrar.

A necessidade **da base, sem obra**, é o caso que justifica base e obra serem
tabelas diferentes — ver [Campo](field.md). Não é exceção: é metade do produto.

### A invariante de coerência

Quando `project_id` está preenchido, `mission_base_id` **tem** que ser igual a
`project.mission_base_id`. Sem isso o registro aponta para a base A pela coluna
e para a base B pela obra, **os dois rollups discordam, e nada dá erro**. É
validação de modelo com spec que tenta gravar a combinação inconsistente.

`Deployment` carrega a mesma invariante, pelo mesmo motivo.

### `need_status` é derivado, `cancelled` não

O status sai da comparação entre `fulfilled_quantity` e `quantity`, num
`before_save`. Escrevê-lo à mão faria a listagem "o que ainda falta" divergir da
soma dos abatimentos, em silêncio.

`cancelled` escapa da derivação, e é a única exceção: cancelar é decisão humana,
e a aritmética não pode desfazê-la.

O teto vive **no banco**, num `CHECK` — `fulfilled_quantity between 0 and
quantity`. Não é redundância com a validação: é a trava em que o abatimento
concorrente vai se apoiar. Duas alocações simultâneas na última vaga passam
pelas duas validações, e é o `CHECK` que reprova a segunda.

### A habilidade só existe numa espécie, e a regra vale nos dois sentidos

`need_kind: skill` exige `skill_id`; qualquer outra espécie exige que ele seja
nulo. Habilidade ausente numa necessidade de habilidade é necessidade que o
matching nunca encontra; habilidade presente num pedido de material é dado
decorativo que a busca acaba filtrando por engano.

### A ordem é por urgência, não por data

`by_priority` ordena por urgência decrescente, depois prazo, depois `id`.
Necessidade crítica em obra parada tem de subir, e a data de criação não diz
nada sobre isso. O desempate por `id` existe para a ordem ser determinística
quando urgência e prazo empatam.

## Duas camadas de voluntariado, e as duas precisam existir

| | Responde |
| --- | --- |
| `VolunteerEngagement` | o vínculo da pessoa com a **organização** — é voluntária, de que tipo, em que área |
| `ProjectParticipation` | a presença dela numa **obra específica**, com papel técnico |

O material institucional define **quatro modelos**, e **dois deles não passam
por obra nenhuma**: quem trabalha fixo no escritório e quem faz divulgação. São
voluntários ativos com **zero participações**.

Fundir as duas camadas apagaria exatamente esse caso — e é o caso que o deck
descreve primeiro. Um voluntário `project_permanent` tem **um** engajamento e N
participações ao longo do ano; a assimetria é o ponto.

**`communication` — a "divulgação" do material — é área como qualquer outra.**
Aparece nas mesmas listagens que a construção, sem segunda classe. É engajamento
que não põe ninguém no canteiro e ainda assim é trabalho.

### O grupo, e a regra nos dois sentidos

`corporate` é o único modelo que vem em bloco, e é o único que exige
`volunteer_group_id`. Os outros três exigem que ele seja nulo: `corporate` sem
grupo é candidatura em bloco sem bloco, e grupo num modelo individual é vínculo
que ninguém coordena.

### A janela não declarada é uma janela aberta

`VolunteerGroup#available_on?` usa um `Range` sem começo e sem fim quando as
datas não foram declaradas — que é exatamente a semântica de um grupo ainda
combinando quando vai. Excluí-lo do matching o tornaria invisível justamente
para quem poderia convidá-lo.

O escopo `available_on` diz a mesma coisa em SQL, e as duas formas existem
porque as perguntas são diferentes: uma filtra uma lista, a outra decide sobre
um registro que já está na mão.

## Envio de equipe

A anotação de origem é explícita: a plataforma auxilia **e também envia
equipes**. Envio é logística com risco — gente viajando para país que pode ser
hostil, com prazo e custo.

A base é obrigatória e a obra não, pela mesma razão da necessidade: envio para
levantar uma base ainda sem obra aberta é o caso normal.

**Capacidade é do avião e da casa, não uma sugestão.** Passar dela é descobrir
na véspera que falta cama para duas pessoas, então ela é validada.

**Convite não ocupa vaga**, e quem já voltou continua ocupando. A contagem
responde *"quantos lugares foram comprometidos"*, e não *"quantos ainda vão
embarcar"* — são perguntas diferentes, e a primeira é a que decide se cabe mais
alguém. É a mesma decisão do `accepted_at` de `Membership` e do `invited` de
`ProjectParticipation`: convite não é vínculo.

### Não há `TravelDocument`, e é decisão

Passaporte, visto, vacina e seguro digitalizados adicionam superfície de dado
pessoal sensível — com retenção, acesso restrito e LGPD junto — para uma
demonstração que **não vai enviar ninguém a lugar nenhum**. É custo sem retorno,
e na direção errada: uma demo deve carregar *menos* dado sensível, não mais.

## O que falta desta issue

Entregues: `Need`, `VolunteerGroup`, `VolunteerEngagement`, `Deployment` e
`DeploymentMember`. Faltam `Candidacy` e o par
`Assignment`/`NeedFulfillment` — a candidatura e o abatimento com trava de
concorrência, que vão num PR próprio porque a trava é a única parte
genuinamente difícil de #33 e merece revisão dedicada.
