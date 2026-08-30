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

## O levantamento é entregável, não só um estado

`LEVANTAMENTO` é um dos cinco estados da obra, mas levantamento é **trabalho com
produto**: visita, medição, diagnóstico, estimativa. Modelar só como enum jogaria
fora justamente o que o engenheiro voluntário produz remotamente, antes de
qualquer equipe viajar — que é a metade diferenciada deste produto.

Por isso `SiteSurvey` existe, com `findings` e `recommendations` em Action Text
e as plantas e laudos em `has_many_attached :documents`.

**Obra em levantamento com zero `SiteSurvey` é estado legítimo.** A obra entra no
estado antes de alguém visitar — exigir o contrário obrigaria a inventar um
levantamento vazio para poder abrir a obra.

O ciclo é `draft` → `submitted` e para aí. Workflow de aprovação com revisor e
recusa é v2: um fluxo que ninguém opera é estado morto no banco.

## Papel na obra é contexto, e a coordenação é invariante

`ProjectParticipation` é onde "papel é contexto, não tipo de usuário" fica
concreto: a mesma pessoa é coordenadora numa obra, voluntária em outra e
anfitriã local na terceira.

**O índice único é `[project, profile, role]`, e o `role` está lá de propósito.**
A mesma pessoa pode ser `technical_lead` **e** `local_host` na mesma obra;
deixar o papel fora do índice proibiria um caso real.

**Toda obra em execução tem coordenação**, e a regra é cobrada **na transição
para `in_progress`**, não na criação — obra em levantamento ainda não tem
equipe. Ela vive no `Project`, ao lado da validação de transição, porque é lá
que a mudança de estado é visível.

Diferente da transição, esta regra **não** tem guarda que levanta: um
`save(validate: false)` aqui não abre porta de segurança nenhuma, só deixa a
obra sem quem responda por ela — problema de processo, que aparece na primeira
tela.

`invited` não concede nada. É a mesma decisão do `accepted_at` de `Membership`:
convite não é vínculo. Quem pergunta é `may_report?`, não `role` solto.

### O vazamento pelo perfil

A obra confidencial está protegida por `Sensitive`. Mas **o CV do voluntário
contaria onde ele esteve** — e esse é o caminho lateral que se esquece, porque a
proteção parece completa do lado da obra.

`Profile#visible_participations(context)` filtra pela sensibilidade **da obra**,
não da participação: a participação não tem nível próprio, e dar um a ela
criaria uma segunda verdade para divergir da primeira.

> O que falta aqui é a metade de resposta: a issue pede um spec que **greppe a
> resposta HTTP** procurando o código e o nome da obra. Isso é devido a quem
> construir a tela de perfil — hoje não existe resposta para greppar. O que
> está entregue é a garantia no nível da consulta.

## A foto: EXIF sempre, bytes conferidos, crédito condicional

`ProjectPhoto` usa `attaches_scrubbed_photo :image`, e portanto **o EXIF é
destruído na ingestão sempre** — não só em obra confidencial. Regra única é
regra que não se esquece, e a obra pode ser promovida a confidencial depois de
a foto já estar guardada. Ver [Política de foto](photo-policy.md).

**A validação de formato olha os bytes, não o content-type declarado.** Um
arquivo renomeado para `.jpg` chega ao servidor com `image/jpeg` no formulário;
confiar nisso é confiar no cliente. A whitelist de content-type é a primeira
peneira, e a segunda é a libvips recusar abrir o que não é imagem. Whitelist e
não blacklist, pelo motivo de sempre: o formato desconhecido fica de fora por
default, em vez de o próximo formato ruim passar.

O limite de tamanho é 12 MB — foto de celular cabe, PDF de planta e vídeo não, e
é o upload acidental desses que enche o storage sem ninguém ver.

As variantes não são declaradas aqui: as três larguras do `srcset` vivem em
`ImageFrameComponent::WIDTHS` (480/960/1440), e é o componente que as monta. O
modelo só garante que o arquivo é processável.

**O crédito da foto some quando o leitor não alcança a obra.** `credit_for` pede
o contexto e responde `nil` fora de alcance: nomear quem tirou a foto ao lado de
uma obra confidencial é exatamente o que a política de identidade evita — e
quem decide é o recurso, não o perfil.

## Seed mínimo — o que ele é e o que ele não é

`db/seeds/development/` carrega em qualquer ambiente que não seja produção
(**teste incluído**, e é lá que o seed prova que roda). Ele **não** é a
demonstração: #48 é a demonstração completa e só fecha no fim, quando todos os
modelos existirem. Este é o mínimo, e ele **cresce em camadas** — cada issue de
modelo acrescenta a sua.

Cada arquivo do diretório apenas **define** um módulo com `load!`; quem invoca é
o `db/seeds.rb`, via `DevelopmentSeeds.load_all!`. A separação não é cerimônia:
com a chamada dentro do arquivo, carregá-lo para inspecionar — num spec, no
console — já gravaria no banco.

Três propriedades, e as três são cobradas por spec:

- **Idempotente.** Roda de novo toda vez que alguém recarrega a demo. Chave
  natural (`slug` da base, `title` da obra dentro dela), nunca `create!` solto.
- **Determinístico.** Sem `rand` sem semente. Demo que muda a cada carga é demo
  que não dá para ensaiar.
- **Datas relativas a hoje.** Fixas envelhecem, e em um mês toda obra está no
  passado.

Duas escolhas que valem explicar:

**A obra chega ao estado por transição**, não por atribuição direta. É o caminho
que a aplicação usa, e um seed que o contornasse deixaria de exercitar a matriz.
Como quase toda rota passa por `in_progress`, a coordenação entra antes de
qualquer transição.

**Uma base é aberta ao público por `promote_visibility!`**, com autor e
justificativa — e não por `update`. Sem uma base aberta, o visitante anônimo
enxerga zero e a listagem não prova nada; e abrindo pela porta de verdade, o
seed exercita a auditoria em vez de contorná-la.
