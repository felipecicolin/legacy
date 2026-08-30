# Campo — base, obra e avanço

> Regra curta no [`AGENTS.md`](../AGENTS.md). Aqui está o porquê.

## Base não é obra

Uma **base** — base missionária, ONG, escola, moradia, igreja, clínica — é um
**lugar durável**. Ela acumula várias obras ao longo dos anos e tem necessidade
mesmo quando nenhuma obra está acontecendo. Uma **obra** é **episódica**: tem
escopo, prazo e orçamento próprios, começa e termina.

Fundir as duas é o erro tentador. "A obra *é* a base" simplifica o modelo hoje e
quebra três coisas depois, todas caras:

1. **A candidatura do voluntário.** Ele se candidata a uma necessidade da base
   — "precisamos de um engenheiro para avaliar a estrutura" — e essa
   necessidade existe antes de qualquer obra ser aberta.
2. **A necessidade recorrente.** "Material de construção" é necessidade da base,
   não de uma obra específica, e ela volta.
3. **O rollup por país.** Contar obras por país e contar lugares por país são
   perguntas diferentes, e a fusão só sabe responder uma.

O campo de busca do próprio design system já separa: *"obra, base ou país"*. O
desenho de dados segue o que a interface já dizia.

É por isso que `Need` (#33) aponta para a base por FK **obrigatória** e para a
obra por FK **opcional** — e não por associação polimórfica. Necessidade sem
obra é o caso normal, não a exceção.

## A sensibilidade desce, e só aperta

Três níveis encadeados, e a herança tem uma direção só:

```
Country#default_sensitivity  →  MissionBase#sensitivity_level  →  Project#sensitivity_level
```

Um país marcado como `high_risk` faz toda base criada nele nascer
`confidential`, sem ninguém lembrar de marcar. A obra herda o nível da base.

**A herança nunca afrouxa.** Uma base num país `public` **não** nasce `public`:
ela mantém o `restricted` que o `Sensitive` dá como default. Abrir um registro é
promoção, e promoção passa por `promote_visibility!`, que exige autor e
justificativa — ver [Visibilidade](visibility.md). Deixar a herança abrir
transformaria "o país não é perigoso" numa decisão de exposição tomada por
ninguém.

E o piso da obra em relação à base **vale para sempre**, não só na criação. A
base pode ser apertada meses depois; se a obra continuasse mais aberta que ela,
seria exatamente a porta que a promoção da base tentou fechar. É validação, e o
spec que a cobra aperta a base por `update_column` — pelo caminho que pula os
callbacks — e verifica que a obra passa a reprovar.

## `Project#code` — coluna gerada, não callback

O código da obra (`OB-0247`) é sequencial. Duas decisões, e as duas são sobre
correção e não sobre elegância:

**O número vem de uma sequence do Postgres**, e não de `maximum(:code) + 1` em
Ruby. Duas criações simultâneas leem o mesmo máximo e produzem o mesmo código; o
índice único transforma isso em exceção de driver no meio do request. A sequence
é atômica e não bloqueia.

**A sequence é o default da coluna `code_number`**, e não uma sequence avulsa
criada com `execute "CREATE SEQUENCE"`. Isso não é estilo: o dumper Ruby do
Rails **não escreve sequence avulsa no `db/schema.rb`**, e o banco de teste
nasce do schema, não das migrations. Uma sequence solta some entre a migration e
a CI, e toda criação de obra falha lá — num erro que aponta para o spec, não
para a causa.

**`code` é coluna `GENERATED ALWAYS AS ... STORED`.** Ela é indexável e buscável
como qualquer string, e a imutabilidade não depende de `attr_readonly` nem de
callback: o Postgres recusa escrita em coluna gerada por **qualquer** caminho,
inclusive `update_all` e SQL cru — que é justamente onde o `attr_readonly` de
`Organization#slug` e o de `PaymentTransaction#simulated` não alcançam.

## Avanço é log de eventos, não coluna

O design system pede "62%" com foto e legenda de data e responsável. Isso é um
**relatório**, não um número: percentual, data, autor, anexos.

Uma coluna mutável dá o número sem procedência — não responde quem disse 62%,
quando, nem com que foto. E não responde "a obra parou há quanto tempo?", que é
a pergunta que o investidor faz.

`Project#physical_progress` existe mesmo assim, como **cache**, para ordenar e
filtrar 50 obras sem N+1. O que faz o cache não virar uma segunda verdade:

- **Um escritor só.** `Project#recalculate_physical_progress`, chamado pelo
  `after_save` do `ProgressReport`. Nenhum controller escreve a coluna.
- **Só relatório `approved` a move.** Rascunho e submissão são trabalho em
  curso; se movessem, a listagem mostraria número que ninguém conferiu.
- **O valor é o do relatório mais recente, não o maior.** Obra tem retrabalho, e
  62% → 55% é um fato que o cache tem de refletir.
- **Um spec corrompe a coluna à mão e verifica que o recálculo a conserta.** É o
  que prova que ela é derivada, e não fonte.

### Regressão é permitida; mentir não é

Bloquear a queda de percentual obrigaria quem reporta a mentir no relatório. O
que a regra exige é a **explicação** — que é a mesma que a submissão já exige,
então não há duas regras: relatório submetido tem `summary`.

E "tem `summary`" é medido por `body.to_plain_text.strip.present?`, não por
`body.present?`. O Trix envia `<div><br></div>` quando ninguém digitou nada, e
`present?` acha que isso é conteúdo. Ver [Action Text](action-text.md).

### Relatório aprovado é imutável

Correção é relatório novo. Trilha reescrita não é trilha.

A sutileza que quebra a implementação ingênua: **a aprovação é um `update`** —
ela grava `approved_by` e `approved_at`. Um `before_update { raise if
approved? }` bloquearia a própria aprovação. A guarda pergunta pelo estado
**anterior** (`status_was`), não pelo atual.

## `latest_per_project` e o `DISTINCT ON`

O card mostra percentual **e** data. Para 50 obras, isso não pode virar N+1:

```ruby
scope :latest_per_project, lambda {
  approved.select("DISTINCT ON (project_id) *").order(:project_id, reported_on: :desc, id: :desc)
}
```

`DISTINCT ON` é do Postgres, e o projeto é Postgres 18. A alternativa portátil —
subconsulta correlacionada com `MAX` — custa uma varredura por obra, que é
exatamente o N+1 que o escopo existe para evitar.

**O `order` faz parte do escopo e não pode ser trocado por quem chama:** o
Postgres exige que a primeira expressão do `ORDER BY` case com o `DISTINCT ON`.
Reordenar do lado de fora reprova a consulta.

O desempate por `id` não é decoração: dois relatórios no mesmo dia são normais, e
sem ele a resposta dependeria da ordem física das linhas.

## Os cinco estados, e por que a transição levanta

```
surveying → in_progress | paused
in_progress → paused | urgent | completed
paused → in_progress | urgent
urgent → in_progress | paused | completed
completed → (terminal)
```

`completed` é terminal: reabrir obra é criar obra nova, senão o mesmo código
responde por dois ciclos com orçamentos diferentes e a prestação de contas fica
ambígua.

A regra é cobrada **duas vezes**, e é o mesmo padrão do `Sensitive`: uma
validação, que transforma o formulário em erro de campo, e um `before_save` que
**levanta** — porque `save(validate: false)` e `update_attribute` gravam sem
validar, e um estado forçado por ali não teria como ser percebido depois.

A matriz é testada inteira, 5×5, e não por amostra: é ela que pega um estado
novo cujo grafo de transições ninguém lembrou de atualizar.

## O que ainda falta desta issue

Entregues: `MissionBase`, `Project`, `ProgressReport`. Faltam `SiteSurvey`,
`ProjectParticipation`, `ProjectPhoto` e os seeds mínimos — ver #26.
