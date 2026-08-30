# Visibilidade

> Concern: [`app/models/concerns/sensitive.rb`](../app/models/concerns/sensitive.rb)
> · Modelos: [`Visibility::Context`](../app/models/visibility/context.rb) ·
> [`SensitivityChange`](../app/models/sensitivity_change.rb) ·
> [`SensitivityPromotion`](../app/models/sensitivity_promotion.rb)
> · Specs: [`spec/models/concerns/sensitive_spec.rb`](../spec/models/concerns/sensitive_spec.rb)

## Por que isto existe antes dos modelos de obra

A dor que originou a plataforma é o abandono das bases missionárias **em países
perseguidos**. Uma plataforma que lista publicamente uma base cristã nesses
países — com foto, coordenada e nome do responsável — não é um vazamento de
dados: é risco físico para pessoas com nome e endereço.

Isso colide de frente com "o investidor precisa ver as obras que financia". A
resolução é que ele não vê *todas* as obras, vê **todas as que tem direito de
ver**, e recebe agregado anonimizado no lugar das outras ("3 obras na região X ·
R$ 240.000 · 71% médio"). A prestação de contas continua; a base não vira alvo.

O concern vem **antes** das migrations de obra de propósito. Chegando depois,
alguém teria de fazer backfill de coluna e retrofit de escopo em cada consulta
já escrita — e esquecer uma consulta é o único erro que importa aqui.

## Os três níveis

| Nível | Significa | Guarda coordenada? |
| --- | --- | --- |
| `public` | Vitrine. Qualquer pessoa, logada ou não. | Sim |
| `restricted` | Quem tem vínculo com a obra. **Default.** | Sim |
| `confidential` | País perseguido, equipe exposta. | **Não** |

### Default `restricted`, e não `public`

Obra nasce fechada e é aberta por decisão explícita. Um default aberto faz o
esquecimento vazar; um default fechado faz o esquecimento apenas atrapalhar —
alguém reclama que não está vendo a obra, e ninguém é preso.

O default vale inclusive na criação: `create!(sensitivity_level: :public)`
**reprova**. Nascer aberto é promoção como qualquer outra e passa pela mesma
auditoria (`promote_visibility!` funciona num registro ainda não gravado).

## Granularidade de localização: o que não se persiste

O ponto que é fácil errar: para um registro `confidential`, "não mostrar a
coordenada" **não é filtro de exibição**. É o que se grava.

```ruby
PRECISE_LOCATION_ATTRIBUTES = %i[address latitude longitude].freeze
```

Registro confidencial guarda país e, no máximo, região administrativa. Endereço
e coordenada não entram no banco. A diferença é a lista de coisas que podem
falhar: um filtro de exibição ainda vaza por bug de view, por serializer novo,
por export CSV, por linha de log, por dump de backup e por acesso direto ao
banco. **Dado que não existe não vaza por nenhum desses.**

O concern cobra isso em três camadas, e as três são de propósito:

1. Uma **validação**, que é o caminho normal: o formulário recebe o erro e
   `save!` levanta `ActiveRecord::RecordInvalid`.
2. Um **`before_save` que levanta `Sensitive::PreciseLocationForbidden`**, que
   pega o caminho que pula validação (`save(validate: false)`). Uma gravação que
   escapa da primeira camada é um bug, e um bug aqui é uma pessoa localizável —
   então ele explode em vez de gravar.
3. Uma **CHECK constraint no banco**, que é a única que alcança `update_column`,
   `update_all` e `insert_all`. Callback se pula por definição; o banco não.

### A constraint, e por que ela precisa de `btrim`

Toda migration de modelo que inclui o concern declara a coluna e a constraint:

```ruby
t.integer :sensitivity_level, null: false,
                              default: Sensitive::LEVELS.fetch(Sensitive::DEFAULT_LEVEL)
t.check_constraint Sensitive::PRECISE_LOCATION_CHECK,
                   name: "fields_confidential_has_no_location"
```

`PRECISE_LOCATION_CHECK` nomeia as **três** colunas. A camada Ruby não exige as
três — `precise_location_attributes` intersecta com o `column_names`, e uma
tabela só com `latitude`/`longitude` é perfeitamente válida para ela. A
constraint não: aplicada a uma tabela sem `address`, a migration levanta
`PG::UndefinedColumn`. Falha barulhenta na hora certa, mas escreva a expressão à
mão nesse caso, com as colunas que a tabela tem.

O `null: false` não é decoração. `visible_to` e `hidden_from` são complementares
apenas porque a coluna nunca é nula: `where.not` não devolve linha com `NULL`,
então uma linha sem nível somem das **duas** consultas — inclusive do agregado
anonimizado, que passaria a subnotificar em silêncio. E não conte com o
`database_consistency` para pegar isso: o `validate: true` do enum gera
validação de *inclusão*, não de presença, e é presença que ele procura.

A expressão usa `nullif(btrim(coluna::text), '') is null`, e o `btrim` é a parte
que importa: o Ruby considera `"   "` ausente (`present?` é falso), então um
endereço com espaços **passa na validação**. Uma constraint que só testasse
`IS NULL` reprovaria no banco uma gravação já validada — erro 500 no lugar de
erro de campo. A regra do banco tem de ser exatamente tão frouxa quanto a do
Ruby, nunca mais rígida.

`precise_location_attributes` intersecta a lista com `column_names`: o concern é
abstrato e cada modelo concreto guarda as colunas que guarda. O outro lado dessa
moeda é uma armadilha: uma tabela que chame suas colunas de `street`, `lat` ou
`geom` sai inteira do alcance do concern, sem erro nenhum — as três camadas
passam a proteger um conjunto vazio. Coluna de localização usa os nomes de
`PRECISE_LOCATION_ATTRIBUTES`, ou a lista cresce junto.

### `inspect` também é um caminho de vazamento

Registro `public` e `restricted` guardam coordenada de verdade, e ela sai por
**duas** portas de log, não uma:

| Porta | Quem filtra | O que aparece sem o filtro |
| --- | --- | --- |
| `inspect` do modelo — linha de log de exceção, rastreador de erros | `filter_attributes`, fixado por modelo no concern | `latitude: -0.229e2` |
| `Parameters: {…}` da requisição, que não passa por modelo nenhum | `filter_parameters`, no initializer | `"latitude" => "-22.9"` |

A lista default do `filter_parameters` — `passw`, `token`, `secret` — não conhece
nome de localização, e é dela que o Rails alimenta o `filter_attributes`. Por
isso os nomes entram nos dois lugares. No concern é `|=`, não `+=`: os dois se
sobrepõem de propósito, e a garantia por modelo viaja com o concern mesmo que
alguém enxugue a lista do initializer.

Isso alcança `inspect`, e não `to_json` — de propósito. Serialização é resposta
para alguém, e quem decide o que ela carrega é o `visible_to`; se `filter_attributes`
mexesse nela, o spec de vazamento passaria a medir a máscara em vez do escopo.

### `location_label`

```ruby
def location_label(context)
  return country_label unless context.can_see_precise_location?(self)

  [region_label, country_label].compact_blank.join(" · ")
end
```

O modelo concreto responde `country_label` e `region_label`. As tabelas de país
e de região são de outra issue, e o concern não precisa conhecê-las — o que ele
precisa saber é que país sempre aparece e o resto depende de quem pergunta.

## Promoção auditada

Afrouxar a restrição só acontece por uma porta:

```ruby
field.promote_visibility!(level: :public, author: current_user,
                          justification: "Consentimento da equipe local")
```

Um `update(sensitivity_level: :public)` direto **reprova na validação**. O
caminho contrário — tornar mais restritivo — não pede cerimônia nenhuma:
fechar uma obra em emergência não pode depender de preencher formulário.

A regra de exposição tem as mesmas duas camadas da regra de coordenada, e pelo
mesmo motivo. A validação pega o caminho normal; um `before_save` que levanta
`Sensitive::UnauditedDisclosure` pega `update_attribute` e `save(validate: false)`,
que gravam sem validar. Sem essa segunda camada, um
`base.update_attribute(:sensitivity_level, :public)` transforma uma base
confidencial em vitrine **sem uma única linha de auditoria** — e `update_attribute`
não é uma chamada exótica: é o que se escreve quando "só" se quer mudar um campo.

Fora do alcance continuam `update_column`, `update_all` e `insert_all` sobre a
própria coluna `sensitivity_level`: a regra compara com o valor anterior — que
no `insert_all` nem existe — e a constraint só enxerga a linha final. Fechar
isso exigiria trigger. Sobre modelo com o concern, os três continuam proibidos:
um `insert_all` cria linha `public` sem nenhuma linha de auditoria.

### A linha de auditoria é imutável

`SensitivityChange` levanta `SensitivityChange::Immutable` em qualquer `update`
de linha já gravada. Apagar a linha deixa uma lacuna visível; **reescrevê-la
deixa uma resposta errada com cara de legítima**, que é pior — um
`change.update!(author: outra_pessoa)` troca quem responde pela exposição sem
deixar sinal. Ela levanta em vez de devolver `false` porque gravação de
auditoria que falha calada é o mesmo que auditoria nenhuma.

Isso não alcança `SensitivityChange.update_all` nem `delete_all`, que pulam
callback como sempre.

Cada promoção grava uma linha em `sensitivity_changes` (registro polimórfico,
autor, nível de origem, nível de destino, justificativa, data). É a existência
dessa linha que separa uma decisão de um esquecimento, e é ela que permite
perguntar depois "quem abriu esta obra, e com base em quê".

### Quando o log morre, e quando ele impede

As duas pontas do `sensitivity_changes` têm política oposta de propósito:

| Some quem | Política | Por quê |
| --- | --- | --- |
| A obra | `dependent: :destroy` | Apagar a obra é a **direção segura**: o dado que expunha gente deixa de existir, e o log fica sem sujeito. Travar a exclusão obrigaria a base perigosa a continuar no banco. |
| O autor | `dependent: :restrict_with_error` | Apagar a conta não tira risco de ninguém. Só tiraria o rastro de quem decidiu expor — remover usuário viraria o jeito barato de apagar o próprio histórico. |

O `from_level` de uma obra que já nasce promovida é sempre `restricted`, o
default: o registro não existia antes, e o que a auditoria descreve é a
distância entre "o que teria acontecido sozinho" e "o que alguém decidiu".

O que distingue a chamada auditada do `update` direto é uma variável de
instância transitória (`@sensitivity_promotion`), lida pela validação, pelo
`before_save` e pelo `after_save` da mesma gravação. Ela não é atributo público
de propósito: um atributo convidaria a "setar agora e salvar depois", que é
justamente o `update` direto de novo, com um passo a mais.

Apagá-la é trabalho de um `ensure`, e não do fim do caminho feliz: uma promoção
que reprovou por outro motivo — nome em branco, digamos — deixaria a autorização
pendurada no objeto, e o `update` seguinte do mesmo objeto, que deveria
reprovar, passaria e gravaria a auditoria com a justificativa da tentativa
anterior. "Vale por uma gravação" tem de valer também quando a gravação falha.

## `visible_to`, `hidden_from` e o agregado anonimizado

```ruby
scope :visible_to, ->(context) { where(sensitivity_level: context.allowed_levels) }
scope :hidden_from, ->(context) { where.not(sensitivity_level: context.allowed_levels) }
```

Os dois devolvem **relação**, não array. É isso que deixa o agregado anonimizado
por região sair de

```ruby
Project.hidden_from(context).joins(:mission_base).group("mission_bases.country_id", "mission_bases.region_id")
```

sem um segundo caminho de SQL. Um caminho paralelo é onde a divergência mora:
duas consultas que decidem visibilidade em lugares diferentes divergem no dia em
que só uma é atualizada.

### `AnonymizedRollup` (#50)

> [`app/queries/anonymized_rollup.rb`](../app/queries/anonymized_rollup.rb) ·
> [`spec/queries/anonymized_rollup_spec.rb`](../spec/queries/anonymized_rollup_spec.rb)

É quem implementa o piso de k-anonimato que o parágrafo acima citava como
pendente: `MINIMUM_GROUP_SIZE = 3` — uma região com uma ou duas obras ocultas
some do resultado em vez de aparecer com "1 obra · X% médio", que seria a
própria obra com outro nome. A chave de agrupamento é `[country_id, region_id]`
lido direto de `mission_bases` (não de `regions`), porque `region_id` é
opcional e nulo não pode juntar bases de países diferentes no mesmo grupo.

**O que o agregado soma hoje: contagem de obras e progresso físico médio, só.**
A soma de dinheiro arrecadado — o "R$ 240.000" do exemplo lá em cima — espera
`Campaign#raised_cents` (issue #39, Arrecadação, ainda não existe). Quando
existir, entra como mais uma coluna agregada na mesma consulta; a estrutura
(agrupar sobre `hidden_from`, suprimir grupo pequeno, resolver nome de país e
região em duas queries à parte) não muda.

A defesa contra o **ataque do complemento** — subtrair os grupos publicados do
total geral para reconstruir o grupo suprimido — fica de fora de propósito.
Resolver isso direito exige orçamento de privacidade formal, e a issue que
introduziu o rollup já registrou isso como risco aceito para v2, não como
esquecimento.

`Visibility::Context` é a autorização **já resolvida** em nível, e não o
usuário: `visible_to` não precisa conhecer papel, política nem sessão, e o
contexto anônimo (`Visibility::Context.anonymous`, teto `public`) é
representável sem inventar um usuário falso. Isso conversa com a nota de
["Fechado por padrão"](authentication.md) — as telas de vitrine que abrirem com
`allow_unauthenticated_access` navegam com esse contexto.

## O spec de vazamento

Além dos testes por comportamento, o spec serializa uma coleção **mista** como
um leitor anônimo e procura na saída o nome, o código e as coordenadas dos
registros que ele não alcança:

```ruby
payload = SensitiveTestRecord.visible_to(anonymous).to_json
expect(payload).not_to include(confidential.name, confidential.code, "-22.9")
```

Ele existe porque os testes por comportamento verificam a regra que lembramos de
escrever, e este verifica o resultado: qualquer coluna nova que entre no
serializer e carregue identificação passa a ser coberta sem ninguém editar o
teste.

## Por que o host dos testes é um modelo de spec

O concern é abstrato e os modelos de obra ainda não existem. O host dos specs é
`SensitiveTestRecord`, definido em
[`spec/support/sensitive_test_record.rb`](../spec/support/sensitive_test_record.rb)
sobre uma tabela criada no `before(:suite)` do banco de teste.

Um modelo em `app/models/` criado só para o teste passaria a existir de verdade:
apareceria no autoload, exigiria migration e `db/schema.rb`, seria varrido pelo
`database_consistency` e teria de ser removido quando `Field` chegasse — com a
chance de não ser. Um host de teste some junto com o banco de teste.
