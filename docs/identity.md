# Identidade — `Profile`

> Modelo: [`Profile`](../app/models/profile.rb) · [`User`](../app/models/user.rb)
> · Spec: [`spec/models/profile_spec.rb`](../spec/models/profile_spec.rb)
> · Complemento: [Autenticação](authentication.md)

O `User` guarda credencial e sessão. A **pessoa** mora no `Profile`: nome legal,
nome público, chamada, telefone, locale, fuso e foto.

## Uma pessoa, muitos papéis

Não existem tabelas `Volunteer`, `Investor` e `Missionary`. O domínio descreve
gente que é as três coisas ao mesmo tempo — o engenheiro que também doa, o
missionário que também capacita. Separar em tabelas obrigaria a duplicar a
pessoa e depois reconciliar duas linhas que são o mesmo ser humano; a primeira
consequência prática seria "com qual das duas ela faz login?".

"Visão do investidor" e "visão do voluntário" são **projeções autorizadas sobre
os mesmos dados**, não tipos de registro. A pergunta que o sistema responde é
sempre "esta pessoa pode fazer isto neste objeto", e ela é respondida por
contexto — `Membership#role` (#20), `StaffRole` (#21),
`ProjectParticipation#role` (#31) —, nunca por uma coluna `type` em `profiles`.

## Nome legal e nome público

Duas colunas, as duas `NOT NULL`:

| Coluna | O que é | Quem vê |
| --- | --- | --- |
| `legal_name` | o nome do documento | staff autorizado |
| `display_name` | o que a UI mostra | quem a política de visibilidade permitir |

A separação é pré-requisito da política das bases sensíveis (#24): em país
perseguido, o nome que aparece ao lado de uma obra não pode ser o do documento.

**`display_name` é armazenado, não derivado.** Ele nasce copiando `legal_name`
num `before_validation … on: :create`, e depois segue vida própria. A
alternativa — devolver `legal_name` quando o público estiver vazio — parece
mais simples e é pior: a correção de um nome legal (casamento, grafia, ordem de
sobrenomes) reescreveria **retroativamente** todo o histórico já exibido, em
telas que outras pessoas já leram. O spec cobra os dois lados: criar sem nome
público copia o legal, e alterar o legal depois não mexe no público.

## `legal_name` não sai por serialização

Duas defesas no modelo, e as duas são incondicionais:

- `to_s` devolve `display_name`. Basta um `"#{profile}"` esquecido numa
  listagem para uma interpolação virar vazamento — então a interpolação sai
  certa por padrão.
- `serializable_hash` remove `legal_name` **depois** de chamar `super`, o que
  cobre `as_json`, `to_json` e qualquer serializer que passe por ali.

O `depois de chamar super` é a parte que precisa de explicação. A forma
aparentemente equivalente — devolver `except: %w[legal_name]` como opção padrão
— tem um furo: no `serializable_hash` do Active Model o `only:` é avaliado
**antes** e tem precedência sobre o `except:`, então um
`as_json(only: [:legal_name])` atravessaria a defesa inteira. É exatamente o
caminho que um serializer distraído escreveria. O spec exercita esse caso, e
não só o feliz — sem ele, o exemplo passaria também para a implementação fraca.

Isto é o piso, não a política. Qual dos dois nomes aparece em qual contexto é
decisão de policy e chega na #24 (`presenter.name_for(context)`).

## Um perfil por pessoa: índice **e** validação

`profiles.user_id` é `NOT NULL` com índice único. Quem garante a unicidade sob
concorrência é o índice — uma validação de unicidade perde a corrida entre dois
requests simultâneos, porque consulta e grava em momentos diferentes.

A validação existe assim mesmo, por dois motivos: a segunda tentativa vira erro
de formulário em vez de exceção de driver, e o `bundle exec
database_consistency` **reprova** um índice único sem validador correspondente
(`UniqueIndexChecker`). Os dois estão cobertos por specs separados; o do índice
grava com `save(validate: false)` e precisa preencher `display_name` à mão,
porque pular a validação pula também o callback que o preencheria — e aí quem
dispara primeiro é o `NOT NULL`, não o índice.

## Active Storage entra aqui

`has_one_attached :avatar` precisa das tabelas do Active Storage, e elas ainda
não existiam: o `config/application.rb` já carregava a engine e o
`config/storage.yml` já estava configurado, mas ninguém tinha rodado
`bin/rails active_storage:install`. Esta issue roda.

A instalação só deposita uma migration — nenhum ERB, então o `bin/herb_lint`
não entra na conversa (os partials que dão trabalho vêm do `action_text:install`,
que é a #32). O `record` polimórfico de `active_storage_attachments` não tem FK,
como todo polimórfico, e o `database_consistency` **não** reclama disso — foi
verificado antes de escrever o modelo, e não depois.

Processamento de imagem (variantes, remoção de EXIF, entrega autorizada) é #30 e
#24. Aqui o anexo só existe.

## O que ficou de fora, e onde cada coisa chega

| Campo / associação | Por que não está aqui | Issue |
| --- | --- | --- |
| `bio` (`has_rich_text`) | Action Text ainda não instalado | #32 |
| `country` | a tabela `countries` não existe; coluna sem FK contradiz o gate de consistência | #25 |
| `skills` / `profile_skills` | taxonomia curada, escopo próprio | #19 |
| `memberships` / `organizations` | escopo próprio | #20 |
| papéis e autorização | papel é contexto | #20, #21, #31 |
| qual nome aparece em qual contexto | é policy, não modelo | #23, #24 |

As associações voltam ao `Profile` junto com a issue que cria o outro lado —
declarar `belongs_to :country` antes de existir `Country` não é adiantar
trabalho, é deixar o modelo quebrado esperando alguém consertar.
