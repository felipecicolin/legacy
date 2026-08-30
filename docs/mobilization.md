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

## A candidatura, e o oráculo que ela não pode virar

`Candidacy`, e não `Application`: dentro de `module Legacy` um `Application`
pelado resolve para `Legacy::Application` — a própria classe da aplicação Rails
— antes de chegar no modelo. É colisão de constante esperando um job
namespaced para acontecer.

**Exatamente um candidato**, pessoa **ou** grupo, com `CHECK` no banco além da
validação. E os índices únicos são **parciais** (`where: "profile_id is not
null"`): um índice sobre as duas colunas juntas deixaria passar duas
candidaturas de grupo à mesma necessidade, porque `profile_id` seria nulo nas
duas e o par ficaria distinto.

**O gate de registro profissional é da NECESSIDADE**, não do papel: quem decide
se aquela vaga exige CREA é quem a abriu (`Need#requires_professional_registration`).
Candidatura de grupo não é gateada — quem responde pelo registro é a pessoa
alocada, e a alocação é individual.

**Recandidatar depois de desistir reabre o mesmo registro.** O índice único
garante um por par, e `reapply` limpa a decisão anterior. A alternativa — uma
segunda linha — produziria duas candidaturas da mesma pessoa à mesma
necessidade, discordando sobre o estado.

## O abatimento: uma origem, uma trava

`NeedFulfillment` é polimórfico, e é **a única vez que este repositório escolhe
polimorfismo**. A diferença para o caso que `Need` recusou está em quantos
donos existem: lá havia um dono real (a base) com um qualificador opcional (a
obra); aqui são três tipos genuinamente distintos — alocação, doação em
espécie, contribuição — e **nenhum deles é "o" dono**. Três origens com um
mecanismo só, senão cada espécie de necessidade ganha a sua própria
contabilidade e elas divergem.

`Need#fulfill` é a porta única, e a trava mora nela:

```ruby
def fulfill(source:, quantity: 1, fulfilled_at: Time.current)
  with_lock do
    fulfillment = need_fulfillments.create!(...)
    recount_fulfilled
    fulfillment
  end
end
```

`with_lock` faz `SELECT ... FOR UPDATE` **e recarrega**. Duas alocações
simultâneas na última vaga viram duas transações em fila: a segunda só lê a
quantidade depois de a primeira ter gravado, então enxerga zero vagas e reprova
— em vez de as duas lerem o mesmo número antigo e passarem, que é o bug
clássico.

`fulfilled_quantity` é **derivado** da soma, e `recount_fulfilled` é o único
escritor dele. O `CHECK` `fulfilled_quantity between 0 and quantity` é a rede
para quem abater sem passar pela porta.

### Como a corrida é testada sem `Thread.new`

A issue pedia um spec com duas threads. O `ThreadSafety/NewThread` reprova
`Thread.new` neste repositório, e um teste de corrida que depende de
escalonamento é **intermitente por construção**: ele passa quando o
escalonador coopera, e um dia falha sem que nada tenha mudado.

O que se testa no lugar é o **mecanismo**, de forma determinística: uma
assinatura em `sql.active_record` confirma que a leitura da quantidade acontece
com a linha travada (`FOR UPDATE` presente), na alocação **e** no estorno. Mais
os dois efeitos observáveis em sequência — a segunda alocação enxerga o que a
primeira gravou, e o `CHECK` reprova um abatimento escrito por SQL cru.

É uma troca explícita: perde-se a demonstração da corrida, ganha-se um teste
que não mente quando passa.

### Um caminho só até a equipe

Alocar abate a necessidade **e** põe a pessoa na equipe da obra, no mesmo
callback. Dois caminhos separados produziriam voluntário alocado que não
aparece na equipe — e ninguém descobriria até a obra começar. Cancelar desfaz
os dois.

Necessidade de base não tem obra, e aí não há equipe em que entrar: é o caso
normal da necessidade que existe sem obra ativa. Candidatura de grupo também
não produz participação, porque quem participa da obra é pessoa.

> **A armadilha que quase passou:** `participation_scope.blank?` é `true` para
> uma relation **vazia** — e a relation é vazia exatamente no caso comum, o da
> pessoa que ainda não está na equipe. Com `blank?` a participação nunca era
> criada, e nada dava erro. A guarda pergunta `unless scope`.

## A visão do voluntário — a tela que fecha o produto

Sem ela a plataforma mostra obras e **não conecta ninguém**. Ela responde três
perguntas na ordem em que importam: *o que eu posso servir*, *o que eu já pedi*,
e *o que falta em mim para poder pedir*.

### O que trava a candidatura fica visível antes da tentativa

Quem tem credencial pendente precisa saber que é **isso** que trava — e não
descobrir por um erro de formulário depois de escrever a motivação. O requisito
aparece no card da necessidade, na página dela e no perfil de voluntário, e só
então a validação recusa.

É a mesma ideia por trás do estado vazio de quem não cadastrou habilidade: uma
lista vazia se lê como *"não há o que fazer"*, quando o que falta é um passo da
própria pessoa.

### O casamento respeita o alcance, e não diz que respeitou

`matched_needs` passa pelo `visible_to` do leitor. Necessidade fora do alcance
**não aparece nem como negada** — a mesma regra do oráculo da [Busca](search.md).

Isso se estende ao envio: `Deployment` não tem nível de sensibilidade próprio, e
listar um cujo destino é base confidencial contaria que ela existe **pelo
destino da viagem**. A lista filtra por base alcançável.

### A corrida do abatimento chegando à interface

A vaga pode acabar entre a renderização do formulário e o envio. A validação
`need_is_still_open` da `Candidacy` recusa, e a recusa vira **erro de
formulário** — nunca 500. É o mesmo caso de concorrência que a trava de
`Need#fulfill` resolve no banco, visto do outro lado.

### Candidatura de grupo sai do coordenador

`CandidacyPolicy#create?` pergunta pelo **coordenador do grupo** quando há
grupo. Inscrever a turma inteira é decisão de quem responde por ela; um membro
comum se candidata por si, pelo caminho individual.

### O perfil é obrigatório no painel, e a decisão é do controller

`VolunteerDashboard` **exige** um perfil. Um painel de voluntário sem pessoa não
tem o que responder, e aceitar `nil` viraria quatro guardas espalhadas pelos
métodos — o `RepeatedConditional` do reek apontou exatamente isso. Quem entrou
sem perfil é tratado uma vez, no controller, com uma tela própria.

### O que a issue pede e o domínio não tem

A #55 pede *"requisito de documento; alerta quando o passaporte vence antes do
retorno"*. **Não há `TravelDocument` neste domínio**, e isso é decisão
registrada — ver a seção do envio acima. Implementar o alerta exigiria criar
justamente a superfície de dado pessoal que a decisão recusa.

A lista de envios mostra datas e vagas. O alerta de documento fica de fora, e
ele só volta se a decisão sobre `TravelDocument` for revista.

## Uma armadilha de factory que custou uma volta de CI

**O FactoryBot gera uma trait para cada valor de enum.** `Need#need_kind` tem o
valor `skill`, então existe uma trait `:skill` que ninguém escreveu.

Dentro de uma trait, um nome pelado resolve para a **trait homônima** antes de
ser considerado associação. Então isto:

```ruby
trait :skilled do
  need_kind { :skill }
  skill          # ← aplica a trait :skill do enum, NÃO monta a associação
end
```

produzia um registro com `skill_id` nulo, em silêncio. O erro aparecia na
validação — apontando para o modelo, e não para a fixture que o montou errado.

Duas regras saíram daí, e valem para todo factory deste repositório:

1. **Trait não repete nome de valor de enum.** `:corporate` e `:office` viraram
   `:in_a_group` e `:at_the_office`.
2. **Associação dentro de trait é explícita:** `skill { association :skill }`.

### E a validação pergunta pelo objeto, não pelo id

O mesmo episódio expôs outra coisa: `skill_id.present?` é falso num registro
ainda **não salvo** cuja associação já está montada. Uma validação escrita sobre
o id reprova um registro perfeitamente válido, com uma mensagem sobre um campo
que quem preencheu o formulário preencheu. `Need` e `VolunteerEngagement`
perguntam pelo objeto.

