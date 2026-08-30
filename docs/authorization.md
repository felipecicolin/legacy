# Autorização

> Regra curta no [`AGENTS.md`](../AGENTS.md). Aqui está o porquê.

A pergunta que este sistema responde nunca é "que tipo de usuário é este". É
**"esta pessoa pode fazer isto neste objeto"**.

A diferença não é retórica. "Que tipo de usuário" pede uma coluna em `users`, e
uma coluna em `users` obriga a escolher um papel por pessoa — o que o domínio
não permite. A mesma pessoa é dona de uma igreja, representante de uma empresa
e voluntária numa obra, ao mesmo tempo. Ver
[Identidade](identity.md) e [Organizações](organizations.md).

## Onde cada papel mora

| Pergunta | Quem responde |
| --- | --- |
| Pode administrar a plataforma? | `StaffRole#staff_level` |
| Pode editar esta organização? | `Membership#role` na organização dona |
| Pode reportar avanço nesta obra? | `ProjectParticipation#role` (#26) |
| Pode **ver** esta obra? | policy + `sensitivity_level` — ver [Visibilidade](visibility.md) |

Nenhum deles é coluna em `User`. `StaffRole` é tabela separada e não uma coluna
`staff_level` em `users` porque a esmagadora maioria das contas não é da
equipe: com coluna, a resposta para "é staff?" viria de um default, e default é
o que erra calado. Sem linha, a resposta é não, e ela é explícita.

## `Authorization::Context` — quem está perguntando

As policies não recebem um `User`. Recebem um
[`Authorization::Context`](../app/models/authorization/context.rb), que é um
`Data` com a pessoa, o perfil, o papel de plataforma e **os vínculos aceitos**.

Duas razões, e a segunda importa mais que a primeira:

1. O limite de 4 parâmetros do repositório. Uma policy que recebesse
   `(user, profile, memberships, record)` já o estoura.
2. Os vínculos são carregados **uma vez**, na construção do contexto. Sem isso,
   cada `authorize` de um request faria a sua própria consulta a `memberships`
   — e uma listagem de 50 itens faria 50.

`memberships` guarda só os aceitos (`accepted_at` não nulo). Convite pendente
não concede nada, e filtrar na construção evita que cada policy nova precise
lembrar de perguntar. É a mesma decisão que `Membership#effective_role`.

O contexto anônimo é representável (`Authorization::Context.anonymous`), e isso
é o que permite a **mesma policy** responder a quem não entrou. A alternativa —
`user` podendo ser `nil` dentro de cada policy — espalha `&.` por toda regra e
transforma cada esquecimento num `NoMethodError` em produção.

## Fechado por padrão, nas duas pontas

**Na policy.** `ApplicationPolicy` recusa tudo. O default poderia ser "staff
pode tudo", e seria conveniente — mas então esquecer de escrever a regra
concederia acesso, e esse é o erro que não aparece em teste nenhum: a tela
funciona.

**No controller.** `ApplicationController` declara `after_action
:verify_authorized`. Sem ele, uma action nova que esqueça de chamar `authorize`
serve o dado e ninguém percebe. Com ele, o esquecimento levanta
`Pundit::AuthorizationNotPerformedError` no primeiro spec que exercitar a
action.

É a mesma forma da autenticação: `before_action :require_authentication` no
concern `Authentication`, com `allow_unauthenticated_access` para quem abre.
Aqui a saída se chama `skip_authorization_for`, e ela é para actions que **não
têm registro** para autorizar — o formulário de login existe justamente para
quem ainda não é ninguém. Hoje são três: `SessionsController`,
`PasswordsController` e o `HomeController`, que é espaço reservado.

Não é atalho de conveniência. Uma action que tem registro e não quer autorizá-lo
está errada, e o guarda existe para dizer isso.

## Por que Pundit

Policy é objeto Ruby comum: cabe nos limites de tamanho do repositório, é
testável sem controller, e a matriz papel × recurso vira uma tabela de exemplos.
`ActionPolicy` serviria igual. O que **não** serve é `if current_user.admin?`
espalhado por controller — não porque seja feio, mas porque a regra deixa de ter
um lugar, e a próxima tela reescreve uma versão ligeiramente diferente dela.

Não há `ApplicationPolicy::Scope`. A pergunta "quais registros esta pessoa
enxerga" já é respondida por `Sensitive.visible_to(context)`, que existe desde
#23 e devolve uma relação. Um `Scope` do Pundit por cima seria um segundo
caminho para a mesma decisão — e dois caminhos divergem. Quando uma listagem
precisar filtrar por algo que não seja sensibilidade, o `Scope` entra.

## Papel de plataforma e alcance de visibilidade

`Authorization::Context#clearance` traduz papel em nível de visibilidade, e é a
única ponte entre os dois vocabulários:

| Quem | Alcança |
| --- | --- |
| Anônimo | `public` |
| Autenticado sem papel de plataforma | `restricted` |
| `support` | `restricted` |
| `curator` | `restricted` |
| `admin` | `confidential` |

**Só o `admin` alcança `confidential`, e essa é uma decisão de segurança, não
uma consequência de ser da equipe.** Um registro `confidential` descreve base
missionária em país perseguido: expô-lo é risco físico para pessoas reais. Quem
atende chamado (`support`) e quem cura vocabulário (`curator`) não precisam da
coordenada para fazer o próprio trabalho, e alcance que ninguém usa é alcance
que vaza por acidente — por print, por sessão esquecida aberta, por conta
comprometida.

Antes de #21 esse valor era a constante `AuthorizedBlobDelivery::SIGNED_IN_CLEARANCE`,
com um comentário dizendo que esperava por esta issue. O teto de quem
simplesmente entrou não mudou; o que passou a existir é alguém acima dele.

## 404 e 403 respondem igual

`ApplicationController` captura `Pundit::NotAuthorizedError` **e**
`ActiveRecord::RecordNotFound` no mesmo handler, e os dois devolvem `404`.

Isso não é preguiça de escrever duas páginas. Se "não existe" fosse
distinguível de "não pode ver", bastaria varrer ids e observar qual respondia
diferente para enumerar exatamente aquilo que a política de sensibilidade
esconde. A resposta que confirma a existência de uma obra confidencial já é o
vazamento — o conteúdo nem precisa sair.

É a mesma escolha em três lugares do repositório, e vale a pena vê-los juntos:
o login não diz se a conta existe ([Autenticação](authentication.md)), a
recuperação de senha responde igual para e-mail cadastrado e não cadastrado, e
a entrega de blob devolve 404 para foto que existe mas está fora do alcance
([Política de foto](photo-policy.md)).

O `CredentialDocumentsController` mostra a mecânica inteira: ele busca a
credencial **sem filtrar pelo perfil da sessão** — é o que permite a quem
verifica registro profissional alcançar o documento de outra pessoa — e deixa a
policy decidir. Inexistente e não autorizado saem pela mesma porta.

## Quem verifica registro profissional

`CredentialPolicy` libera o documento para o dono e para os níveis
`curator` e `admin`. `support` fica de fora: o documento é CPF, RG e número de
conselho de uma pessoa real, e atender chamado não exige lê-lo.

## Adicionando uma policy

1. `app/policies/<recurso>_policy.rb`, herdando de `ApplicationPolicy`.
2. Sobrescreva só as actions que a regra libera — o resto continua recusando.
3. Pergunte ao contexto, não ao banco: `context.role_in(organization)` já tem a
   resposta carregada.
4. `authorize <registro>` na action. Se ela não tem registro, ela provavelmente
   não devia estar num controller que herda de `ApplicationController`.
5. Spec em `spec/policies/`, com a matriz **papel × action** completa —
   inclusive o default negativo. "Usuário sem papel não é admin por omissão" é
   um exemplo escrito, não uma suposição.
