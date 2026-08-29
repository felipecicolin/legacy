# Organizações e vínculos

> Modelos: [`Organization`](../app/models/organization.rb) ·
> [`Membership`](../app/models/membership.rb)
> · Specs: [`spec/models/organization_spec.rb`](../spec/models/organization_spec.rb)
> · [`spec/models/membership_spec.rb`](../spec/models/membership_spec.rb)
> · Complemento: [Identidade — `Profile`](identity.md)

Igreja, empresa, ONG e agência missionária entram na plataforma como
**organização**. Pessoas se ligam a ela por um `Membership`, que carrega o
papel. É por aqui que uma igreja financia uma obra e envia uma equipe, e é o
que permite que a mesma pessoa represente dois lados sem virar duas pessoas.

O [`Profile`](identity.md) continua sendo quem a pessoa é. Papel é **contexto**,
e contexto mora no vínculo: nenhuma coluna em `profiles` diz "esta pessoa é
dona de alguma coisa".

## Os nomes dos enums, e por que dois deles fogem da issue

A issue #20 especifica `kind` e `status` como colunas. Aqui elas se chamam
`organization_kind` e `organization_status`, e a razão é o
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
*valor*, não do nome do enum: `approved?`, `Organization.approved` e
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
listável. Ele existe em vez de um `where(organization_status: :approved)` solto
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

> Toda organização tem pelo menos um `owner`. Remover o último falha.

A invariante conta **papel**, não aceite. É uma decisão, e a alternativa era
plausível: contar só os owners aceitos, alinhando a invariante com o
`effective_role` acima. Ela foi descartada porque produz um resultado errado no
caso mais comum — a organização recém-criada, cujo único owner ainda não
aceitou, ficaria com esse vínculo **impossível de remover**, já que removê-lo
deixaria zero owners aceitos, que é o estado em que ela já está. A issue
também lista as duas coisas como invariantes separadas, e a segunda fala de
*permissão*, não de posse.

A regra é cobrada em três lugares, e cada um cobre um caminho que os outros
não alcançam:

| Camada | Cobre | O que acontece |
| --- | --- | --- |
| `validate :organization_keeps_an_owner, on: :update` | rebaixar o último owner | erro de formulário em `:base` |
| `before_destroy … prepend: true` | remover o último owner | `destroy` volta `false`; `destroy!` levanta |
| a mesma, isenta na cascata da organização | apagar a organização inteira | passa |

**Rebaixar é remover.** Trocar o papel do último owner para `member` deixa a
organização sem ninguém que responda por ela, exatamente como apagar o vínculo.
Ali é validação, e não callback, porque troca de papel é gravação comum e o
resultado tem de ser erro de campo.

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
destroyed_by_association&.active_record == Organization
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
