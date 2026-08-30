# ONGs e vínculos

> Modelos: [`Ngo`](../app/models/ngo.rb) ·
> [`Membership`](../app/models/membership.rb)
> · Specs: [`spec/models/ngo_spec.rb`](../spec/models/ngo_spec.rb)
> · [`spec/models/membership_spec.rb`](../spec/models/membership_spec.rb)
> · Complemento: [Identidade — `Profile`](identity.md)

Igreja, escola, moradia, clínica, empresa e associação entram na plataforma
como **ONG**. Pessoas se ligam a ela por um `Membership`, que carrega o papel.
É por aqui que uma igreja financia uma obra e envia uma equipe, e é o que
permite que a mesma pessoa represente dois lados sem virar duas pessoas.

## A fusão: por que não existe mais base missionária

Até esta mudança havia duas tabelas para a mesma realidade. `Organization` era
a instituição — nome, CNPJ, site, quem manda nela — e `MissionBase` era o
lugar — endereço, coordenada, quantas pessoas atende, qual país. A base
apontava para a organização por uma FK opcional chamada "operadora".

Isso fazia sentido enquanto a plataforma descrevia operação **internacional**,
onde uma agência daqui opera uma base lá. Numa operação **local** as duas são
a mesma linha: a ONG é a instituição e é o lugar. Manter as duas tabelas
custava três coisas concretas:

1. **Dois cadastros para uma coisa só.** Criar uma ONG significava criar uma
   organização e depois uma base apontando para ela, e nada obrigava a segunda
   a existir — uma organização sem base era um cadastro que não atende ninguém.
2. **Duas respostas para "quem pode ver isto".** A organização respondia pelo
   estado de aprovação; a base, pela sensibilidade. A mesma pergunta tinha dois
   caminhos, e eles divergiam.
3. **O papel apontava para o lado errado.** `Membership` ligava a pessoa à
   organização, mas quem tem obra, necessidade e envio era a base. Um `owner`
   não era dono de nada que aparecesse em tela.

O que a fusão **preservou**, e é o ponto: as duas perguntas continuam
separadas, só que agora sobre a mesma linha. `ngo_status` responde "isto já é
vitrine"; `sensitivity_level` responde "quem alcança isto". Estar `active` não
abre o registro — a ONG nasce `restricted` como a base nascia, e abrir continua
sendo `promote_visibility!` com autor e justificativa.

E o que ela **descartou**: a FK "organização operadora" da base. Depois da
fusão ela apontaria de ONG para ONG, e não existe operação de uma ONG por
outra num modelo local — quem opera é quem é.

### O vocabulário que sobrou

`ngo_kind` é a união dos dois enums menos o que perdeu sentido. Saíram
`mission_base` (a entidade É o lugar), `ngo` (a entidade É a ONG) e
`mission_agency` (não há agência num modelo local); os três caem em
`association`. Ficaram `church`, `school`, `housing`, `clinic` e `company`.

`ngo_status` junta `approved` e `active`, que eram o mesmo estado com dois
nomes, e mantém `suspended` e `inactive` separados: ONG que encerrou atividade
não é ONG punida, e colapsar as duas apagaria o motivo da diferença.

O [`Profile`](identity.md) continua sendo quem a pessoa é. Papel é **contexto**,
e contexto mora no vínculo: nenhuma coluna em `profiles` diz "esta pessoa é
dona de alguma coisa".

## Os nomes dos enums, e por que dois deles fogem da issue

A issue #20 especifica `kind` e `status` como colunas. Aqui elas se chamam
`ngo_kind` e `ngo_status`, e a razão é o
[vocabulário de enum](i18n.md#enum-na-ui): o rótulo de um enum é a chave
`<enum no plural>.<valor>`, num espaço **compartilhado por todos os modelos**.

`kinds` e `statuses` já são de `PaymentTransaction`. Compartilhar exige que os
dois modelos estejam falando da mesma coisa, e não estão:

| Chave | Já significa | Passaria a significar também |
| --- | --- | --- |
| `kinds.charge` | Cobrança | — |
| `kinds.church` | — | Igreja |
| `statuses.pending` | Pendente (lançamento não processado) | Pendente (organização não aprovada) |
| `statuses.approved` | — | Aprovada, ao lado de `succeeded: Aprovado` |

A terceira linha é a que decide: `pending` é a mesma chave para dois conceitos
diferentes, e o dia em que um dos dois precisar de outro texto não há redação
que sirva aos dois. A quarta é a que fica feia de ler: duas chaves quase
sinônimas, em gêneros diferentes, no mesmo arquivo.

O `docs/i18n.md` já previa a saída e nomeia o remédio — `project_status` e
`invoice_status`, cada um com o seu `<enum>s.*`. É o que está feito.

**O custo é só o nome da coluna.** Os escopos e predicados de enum saem do
*valor*, não do nome do enum: `approved?`, `Ngo.approved` e
`scope :visible, -> { approved }` continuam escritos exatamente como a issue
pede.

**`Membership#role` continua `role`,** porque `roles.*` está vazio hoje. A
mesma pergunta volta na #21 (`StaffRole`) e na #31
(`ProjectParticipation#role`): se o papel de lá não for o mesmo vocabulário —
e `admin` de plataforma não é `admin` de organização —, quem chegar depois
renomeia o próprio enum, como aqui.

## O slug é armazenado, e imutável

URL pública que quebra é dívida permanente: quem já compartilhou o link não tem
como saber que ele mudou, e ninguém do outro lado sabe que existiu.

Duas decisões sustentam isso:

- **Armazenado, não derivado.** O slug nasce de `name.parameterize` num
  `before_validation … on: :create` e depois segue vida própria — é o mesmo
  raciocínio do `display_name` do `Profile`. Derivar em tempo de leitura faria
  a correção de um nome reescrever o endereço de todo mundo que já o tem.
- **`attr_readonly :slug`.** Com o default 8.1, atribuir a coluna num registro
  já persistido levanta `ActiveRecord::ReadonlyAttributeError`. Renomear a
  organização segue possível; mudar o endereço dela não é um update a revisar
  em code review, é uma exceção no lugar onde alguém tentou. O alcance é o
  mesmo do `attr_readonly` de [`PaymentTransaction`](payments.md):
  `update_all` e SQL cru passam por baixo.

A cópia usa `slug.presence ||`, e **não** `||=`, pelo motivo que a #18 já
documentou: campo deixado em branco no formulário chega como `""`, que é
truthy, e o default não correria.

### O sufixo de desempate

Duas "Igreja Batista" produzem o mesmo slug, e o índice único reprovaria a
segunda — com um erro sobre um campo que ninguém preencheu. Por isso, quando o
slug base já existe, entra um sufixo de seis dígitos hex.

Ele **não** fecha a corrida entre dois cadastros simultâneos: a consulta e a
gravação acontecem em momentos diferentes. Quem fecha é o índice único, e a
validação de unicidade existe para a segunda tentativa virar erro de formulário
— e porque o `database_consistency` cobra um validador correspondente a todo
índice único.

## Nascer `pending` é a política, `visible` é o único lugar que a aplica

Organização não aprovada não aparece em busca e não recebe doação. O default da
coluna é `pending`, e o escopo `visible` é a única porta que decide o que é
listável. Ele existe em vez de um `where(ngo_status: :approved)` solto
em cada consulta justamente para que a política tenha um lugar só quando
mudar — e para que "esqueci de filtrar" seja visível na leitura do código.

## Convite pendente não concede nada

`accepted_at` nulo é convite pendente. O que o modelo oferece é
`#effective_role`, e não `#role`:

```ruby
def effective_role = accepted? ? role : nil
```

A pergunta que as policies (#23) fazem é "qual o papel desta pessoa nesta
organização", e enquanto o convite não foi aceito a resposta é **nenhum** — não
"owner ainda não confirmado". Um convite pendente de `owner` que concedesse
permissão de owner faria de todo convite enviado uma concessão imediata.

O `role` cru continua público porque a tela de convites precisa dizer *para
qual papel* alguém foi convidado. A separação é essa: `role` é o que o convite
promete, `effective_role` é o que ele concede.

## O último owner

> Uma organização não perde o `owner` que tem. Remover, rebaixar **ou mover**
> o último falha.

O enunciado é sobre **perda**, e não sobre existência: nada obriga uma
organização a nascer com dono. `Ngo.create!` sem nenhum `Membership`
passa em todas as camadas abaixo, porque não há vínculo para elas olharem —
quem cria uma organização e não cria a posse junto fica com uma órfã, e o
lugar de fechar isso é o fluxo de cadastro (#23 em diante), não o modelo.

A invariante conta **papel**, não aceite. É uma decisão, e a alternativa era
plausível: contar só os owners aceitos, alinhando a invariante com o
`effective_role` acima. Ela foi descartada porque produz um resultado errado no
caso mais comum — a organização recém-criada, cujo único owner ainda não
aceitou, ficaria com esse vínculo **impossível de remover**, já que removê-lo
deixaria zero owners aceitos, que é o estado em que ela já está. A issue
também lista as duas coisas como invariantes separadas, e a segunda fala de
*permissão*, não de posse.

**O preço dessa escolha, dito por inteiro:** uma organização cujo único owner
nunca aceitou o convite fica com **zero `effective_role`** — ninguém responde
por ela para efeito de policy — e o vínculo pendente **não pode ser removido**,
porque é o último owner. Sair desse estado é aceitar o convite, promover outra
pessoa a owner, ou apagar a organização. Isso é aceitável enquanto o convite é
recente, que é o caso que a decisão acima otimiza; se um dia a plataforma
precisar recuperar organizações abandonadas nesse estado, o lugar é um fluxo de
transferência de posse (#23), não um afrouxamento desta regra — afrouxá-la
devolve o buraco de deixar a organização sem dono nenhum.

A regra é cobrada em três lugares, e cada um cobre um caminho que os outros
não alcançam:

| Camada | Cobre | O que acontece |
| --- | --- | --- |
| `validate :organization_keeps_an_owner, on: :update` | rebaixar **ou mover** o último owner | erro de formulário em `:base` |
| `before_destroy … prepend: true` | remover o último owner | `destroy` volta `false`; `destroy!` levanta |
| a mesma, isenta na cascata da organização | apagar a organização inteira | passa |

**Rebaixar é remover, e mover também.** Trocar o papel do último owner para
`member` deixa a organização sem ninguém que responda por ela, exatamente como
apagar o vínculo. Mover o vínculo para outra organização faz o mesmo — e esse
caminho **não passa por `role`**: com o papel intacto, `role_changed?` é falso,
e uma guarda que só perguntasse por ele deixaria um `update!(organization:)`
esvaziar a organização de origem sem um único erro.

Ali é validação, e não callback, porque as duas são gravação comum e o
resultado tem de ser erro de campo.

**A contagem sai da organização de ORIGEM.** É por isso que `#other_owners`
consulta `organization_id_was`, e não a associação `organization`: num update
que troca de organização, `organization` já é a de destino, e contar os owners
de lá aprovaria justamente a gravação que deixa a de origem vazia. Sair da
associação tem um segundo efeito: `organization_id_was` nunca é `nil` num
registro persistido, enquanto `organization` é — um PATCH que limpasse
`organization_id` levantava `NoMethodError` no meio do request, porque a
validação de presença do `belongs_to` registra o erro mas não interrompe as
outras validações.

**A remoção em massa não passa por baixo.** `organization.memberships.destroy_all`
instancia cada registro e chama `destroy!` — o `throw(:abort)` do callback vira
`ActiveRecord::RecordNotDestroyed`, e a transação inteira volta. O que
**continua fora do alcance** é `delete_all` e SQL cru: eles montam o DELETE sem
passar pelo registro, e nenhum callback roda no caminho. É o mesmo limite que o
`attr_readonly` de `payments.md` documenta, e a trava que pegaria isso no banco
seria trigger — que aquele documento já recusou pelas mesmas razões.

**Apagar a organização é a exceção, e a checagem é pela classe que destrói.**
Quando a organização vai embora, a posse vai junto: recusar seria impedir de
apagar a própria coisa possuída. O Rails marca cada dependente com
`destroyed_by_association`, e o callback pergunta pela classe:

```ruby
destroyed_by_association&.active_record == Ngo
```

A versão curta — `destroyed_by_association.present?` — é o furo. A cascata que
vem do `Profile` (`has_many :memberships, dependent: :destroy`) preenche o
**mesmo** atributo, então tratá-la como isenta apagaria em silêncio o único
dono de uma organização que continua existindo.

### Apagar a pessoa reprova, e a mensagem fica no vínculo

Com a checagem pela classe, `profile.destroy` de quem é último owner volta
`false` e desfaz tudo — a pessoa não some e a organização não fica órfã. Isso
sobe pela cadeia: `user.destroy` reprova igual, porque `User` apaga o `Profile`
em cascata.

O que **não** acontece é a mensagem chegar junto: os erros ficam no
`Membership` que recusou, e `profile.errors` volta vazio. Quem for construir a
tela de exclusão de conta (#22 em diante) precisa perguntar antes — "estas
organizações ficariam sem dono" — em vez de tentar apresentar o erro depois.
Registrado aqui porque é exatamente o tipo de silêncio que se descobre em
produção.

## O que ficou de fora, e onde chega

| Campo / decisão | Por que não está aqui | Issue |
| --- | --- | --- |
| `country` | a tabela `countries` não existe, e coluna com `foreign_key: true` para tabela inexistente não migra | #25 |
| quem pode aprovar uma organização | é policy, não modelo | #23 |
| qual papel enxerga o quê | idem | #23, #24 |
| papel de staff da plataforma | outro vocabulário, outra tabela | #21 |
| telas de convite e de gestão de equipe | trilha de UI | — |

A `country` segue o precedente da #18, que deixou o mesmo campo de fora do
`Profile` pela mesma razão: declarar a associação antes de existir o outro lado
não é adiantar trabalho, é deixar o modelo quebrado esperando conserto.
