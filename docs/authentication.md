# Autenticação

> Concern: [`app/controllers/concerns/authentication.rb`](../app/controllers/concerns/authentication.rb)
> · Modelos: [`User`](../app/models/user.rb) · [`Session`](../app/models/session.rb) · [`Current`](../app/models/current.rb)
> · Specs: [`spec/requests/sessions_spec.rb`](../spec/requests/sessions_spec.rb) · [`spec/requests/passwords_spec.rb`](../spec/requests/passwords_spec.rb)

Autenticação nativa do Rails 8.1 (`bin/rails generate authentication`), reescrita
para caber nas regras deste repositório. Sem gem de autenticação: o código fica
aqui, onde os linters e a cobertura alcançam.

## Para quem é

Para todo mundo — e é de propósito que não dá para perguntar "que tipo de
usuário é este".

O `User` guarda **credencial e sessão, nada de pessoa**. Nome, bio, país,
pseudônimo e foto vão para o `Profile` (#18), que é dado de negócio com política
de visibilidade própria: em base sensível o nome exibido não é o nome legal.
Misturar os dois obrigaria a filtrar credencial toda vez que se serializa
pessoa.

Papel também não mora aqui. Não existem tabelas `Volunteer`, `Investor` ou
`Missionary`, porque o domínio descreve gente que é as três coisas ao mesmo
tempo — o engenheiro que também doa, o missionário que também capacita. Papel é
**contexto**, e a pergunta que o sistema responde é sempre "esta pessoa pode
fazer isto neste objeto":

| Pergunta | Onde é respondida | Issue |
| --- | --- | --- |
| É da equipe da plataforma? | `StaffRole` | #21 |
| Pode editar esta organização? | `Membership#role` | #20 |
| Pode reportar avanço nesta obra? | `ProjectParticipation#role` | #31 |
| Pode **ver** esta obra? | policy + `sensitivity_level` | #23 |

"Visão do investidor" e "visão do voluntário" são projeções autorizadas sobre os
mesmos dados, não tipos de registro.

## Fechado por padrão

O concern instala `before_action :require_authentication` em **todo** controller.
Abrir uma action é uma decisão explícita:

```ruby
allow_unauthenticated_access only: %i[new create]
```

O inverso — abrir tudo e lembrar de fechar — erra calado, e o erro é uma página
autenticada servida a quem não entrou. Assim o esquecimento erra para o lado que
pede login.

> **Decisão em aberto, registrada aqui para não ser descoberta em seis telas.**
> Há indício nas issues de que parte da plataforma deve ser **pública**: a #23
> pede o teste "`visible_to` com contexto anônimo retorna só `public`", e a #51
> exige que obra confidencial não apareça na busca "nem como *sem permissão*".
> Isso só faz sentido se alguém navega sem entrar. Quando as telas de vitrine
> chegarem (#51, #52, #53), abrir cada uma é um `allow_unauthenticated_access`
> — e a decisão deve ser tomada olhando esta nota, não por omissão.
>
> A #23 já entrou, e trouxe o lado do modelo: `Visibility::Context.anonymous`
> é o leitor sem sessão, com teto no nível `public`. O que ela **não** decidiu
> é quais controllers abrem — ver [Visibilidade](visibility.md).

## Sessão é linha no banco

O cookie guarda o id de uma linha em `sessions`, e **não** o id do usuário
assinado. A diferença aparece no logout: encerrar sessão é apagar a linha, então
reapresentar o cookie antigo depois disso não reautentica ninguém. Com um cookie
auto-contido, "sair" seria só apagar o cookie do lado do cliente — e quem
tivesse copiado o valor continuaria dentro.

O mesmo vale para o WebSocket: o `ApplicationCable::Connection` lê a mesma
linha, então sair pela web também derruba o cable.

## As duas decisões de segurança que custam explicação

### Não vazar quem tem conta

Login e recuperação de senha respondem **a mesma coisa** exista ou não o
e-mail — mesma mensagem, mesma rota, mesmo status. Distinguir "senha errada" de
"e-mail não existe" transforma o formulário num verificador de contas: dá para
varrer uma lista de e-mails e descobrir quem está cadastrado.

O tempo também não distingue, e isso não é mérito nosso: o `authenticate_by` do
Active Record calcula um digest descartável no ramo em que não encontrou
ninguém, justamente para o custo do bcrypt aparecer nos dois casos. Um
`find_by` seguido de `authenticate` escrito à mão não teria essa propriedade —
a resposta voltaria visivelmente mais rápido para e-mail inexistente.

Os specs cobram isso comparando as três respostas (`status`, `location`,
`flash`), e **não** medindo tempo de parede: cronômetro em suíte paralela é
teste intermitente, e a propriedade de tempo vive no `authenticate_by`, não no
nosso código.

### Trocar a senha derruba as sessões

`user.sessions.destroy_all` depois da troca. Se a troca veio de uma conta
comprometida, quem estava dentro não continua dentro.

O token de recuperação vem do `has_secure_password`, expira em **15 minutos** e
carrega o digest da senha — então trocar a senha invalida o próprio link, e o
mesmo e-mail não serve para uma segunda troca.

## Rate limit: onde ele conta importa

O `rate_limit` nativo do Action Controller, 10 tentativas em 3 minutos, no login
e no pedido de recuperação.

Ele conta num `ActiveSupport::Cache`, e é aí que mora a armadilha: o
`config/environments/test.rb` define `cache_store = :null_store`, e sobre o null
store o `increment` devolve `nil`. O contador nunca sobe, o limite nunca dispara,
e o teste "11ª tentativa bloqueada" fica **verde sem nunca ter bloqueado nada**.

A correção é cirúrgica de propósito:

```ruby
# config/environments/test.rb
config.action_controller.cache_store = :memory_store
```

Só o store do Action Controller. O `Rails.cache` continua `:null_store`, que é o
que se quer no resto da suíte. Em produção nada muda: o store cai no
`Rails.cache`, que é o Solid Cache — compartilhado entre processos, que é o que
um limite de força bruta precisa para não virar "10 tentativas por worker".

O contador sobrevive ao exemplo, então `spec/support/rate_limiting.rb` limpa o
store antes de cada um. Sem isso, o spec que gasta as dez tentativas deixa o
contador cheio para quem rodar depois no mesmo processo — e a ordem aleatória do
RSpec faz isso reprovar de forma intermitente, no arquivo errado.

## O placeholder que precisa sobreviver

`root "home#show"` e o `HomeController` são espaço reservado. O
`after_authentication_url` cai em `root_url` quando não havia destino guardado,
então **sem uma rota raiz um login bem-sucedido levanta** — a autenticação não
fecha o ciclo sozinha.

O `#8` traz o shell de layout e o `#57` traz as rotas e controllers de verdade.
O que não pode sumir nessas duas issues é a rota `root` existir. O cabeçalho com
"Sair" no layout tem a mesma natureza: sair precisa existir em toda página
autenticada, não só na de chegada.

## Fora de escopo

Papéis e autorização (#21), OAuth e login social, convite e onboarding.
