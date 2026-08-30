# Vocabulário curado — países e habilidades

> Dados: [`db/vocabulary/countries.yml`](../db/vocabulary/countries.yml) ·
> [`db/vocabulary/skills.yml`](../db/vocabulary/skills.yml)
> · Rótulos: [`config/locales/vocabulary/pt-BR.yml`](../config/locales/vocabulary/pt-BR.yml)
> · Leitor: [`Vocabulary::Catalog`](../app/models/vocabulary/catalog.rb)
> · Modelos: [`Country`](../app/models/country.rb) · [`Region`](../app/models/region.rb)
> · Specs: [`spec/models/vocabulary/catalog_spec.rb`](../spec/models/vocabulary/catalog_spec.rb)
> · [`spec/models/country_spec.rb`](../spec/models/country_spec.rb)

## Por que o vocabulário é arquivo, e não seed

Boa parte do trabalho de dados não é código: é a lista curada que os modelos
vão consumir. Ela cabe em YAML e pode ser escrita antes do modelo existir — foi
o que aconteceu aqui, e é por isso que a lista de países chegou junto com a
tabela que a carrega, e não dentro dela.

A regra que sustenta isso é uma só: **o YAML é a fonte; o seed lê, não
redigita.** Duas listas divergindo é questão de tempo, e a que ninguém abre é a
que fica errada. `db/seeds.rb` tem uma linha de carga e nenhuma lista.

O caminho é `Country.load_vocabulary!`, com `find_or_initialize_by(iso_code:)`
seguido de `update!` — e não o `find_or_create_by!` que a issue sugeria. A
diferença aparece na segunda carga: a curadoria muda, e marcar um país como
`high_risk` no YAML precisa alcançar a linha que **já existe** no banco. Com
`find_or_create_by!`, a edição só valeria para país novo — e não há país novo.

## Chave em inglês, rótulo no locale

A chave (`iso_code`, `key`) é estável, em inglês, e vira identificador no
banco. O rótulo em português mora em `config/locales/vocabulary/pt-BR.yml`.

O nome do país, portanto, **não é coluna**. `Country#name` resolve
`countries.<iso_code em minúsculas>`. São duas consequências:

- Traduzir para um segundo idioma passa a ser adicionar arquivo de locale, e
  nunca migrar dado.
- Some a divergência clássica entre "Coreia do Norte" e "Coréia do Norte"
  gravadas em linhas diferentes por importações diferentes.

A #61 mostra no corpo um exemplo de `skills.yml` com `label:` dentro do YAML,
e logo abaixo exige que "todo `key` de `skills.yml` tenha entrada em `skills.*`
no locale". As duas coisas não podem valer ao mesmo tempo sem criar exatamente
a divergência que a issue quer evitar, então valeu a regra e não o exemplo: os
YAML de `db/vocabulary/` não têm rótulo nenhum.

Os nomes de país vieram do CLDR (`Intl.DisplayNames` em `pt-BR`), com um punhado
de ajustes editoriais para a forma corrente em português — "República
Democrática do Congo" no lugar de "Congo - Kinshasa", "Hong Kong" e "Macau" sem
o sufixo "RAE da China", "Bahrein", "Mianmar". Os códigos alpha-2, alpha-3 e a
moeda saíram da gem `countries` 8.1, usada **uma vez**, na geração do arquivo:
ela não é dependência da aplicação, e o `Gemfile` não a lista.

## `high_risk` é decisão editorial — e está pendente

`high_risk` marca país onde listar publicamente uma base cristã, com foto e
coordenada, é risco físico para pessoas com nome e endereço (ver
[visibilidade](visibility.md)).

**A curadoria não foi feita, e não foi feita de propósito.** A lista está vazia:
nenhum país está marcado. Quem decide quais são é a equipe, com quem conhece o
campo — não um índice de terceiro, não um agente, não quem escreveu este
arquivo. Um índice de perseguição publicado é a opinião de uma organização
sobre um recorte, e importá-lo sem leitura transformaria a opinião dela na
política de segurança daqui, com a aparência de fato.

Marcar um país é trocar o `false` da linha dele em
`db/vocabulary/countries.yml` e rodar o seed. A decisão precisa de dono e de
data registrados na issue que a tomar, e
`grep -c '^- .*true' db/vocabulary/countries.yml` responde, a qualquer momento,
o tamanho exato da curadoria já feita — hoje, zero.

O mecanismo funciona com a lista vazia — é o que os specs cobram: eles marcam
um país **fictício**, na faixa de uso privado do ISO 3166-1 (`XA`–`XZ`), e
verificam o efeito. Nenhum país real aparece marcado em material de teste; um
fixture com país de verdade se leria como a decisão editorial já tomada.

## `default_sensitivity` — o gancho que só aperta

É a coluna que transforma a decisão de segurança em default em vez de
disciplina: uma obra criada num país marcado nasce `confidential` sem ninguém
lembrar de marcar.

```ruby
before_validation :tighten_default_sensitivity, if: :high_risk?
```

O gancho **só aperta**. Desmarcar `high_risk` não devolve o país ao default
`restricted`, e isso é decisão, não descuido: afrouxar restrição é ato
explícito em toda a plataforma, e "este país deixou de ser perigoso" não é um
fato que a edição de uma linha de vocabulário deva afirmar sozinha. Para
afrouxar, alguém escreve o nível na mão, sabendo o que está fazendo.

### Nada de retroativo

Marcar um país **não** rebaixa obra já gravada. Não há callback em `Country`
que alcance outra tabela, e é por isso que não há: mudança de política é
decisão explícita e auditada — com autor, justificativa e linha em
`sensitivity_changes` —, nunca efeito colateral de um `update` de vocabulário.
Uma obra pública que virasse confidencial por consequência apareceria sem
ninguém para responder por quê, e o caminho inverso é pior ainda.

O exemplo que cobra isso hoje usa `SensitiveTestRecord`, o host de spec do
concern, com um `belongs_to :country` acrescentado só para ele. É o mesmo
raciocínio do `EnumTranslationAudit`: o conjunto real ainda é vazio — o modelo
de base vem em issue própria —, e um guarda que só roda sobre conjunto vazio é
uma afirmação sem evidência. Quando `Field` chegar, o exemplo passa a valer
sobre ele, e o host sai.

## Região: só onde houver obra

`Region` existe para ser a granularidade que sobra quando a base é
confidencial — país sempre, região quando ela não localiza ninguém — e para ser
a chave do agregado anonimizado. O seed **não** carrega a subdivisão
administrativa do mundo: seriam milhares de linhas que ninguém referencia,
dado para manter em dia sem ninguém para reclamar quando envelhecer. Região
nasce junto com a obra que fica nela.

O nome da região, ao contrário do nome do país, é dado normal em coluna: ele
varia com o idioma da equipe em campo e não tem lista fechada de onde sair.

## O guarda, e o que ele comprou

`spec/models/vocabulary/catalog_spec.rb` lê os dois YAML e compara com o
locale **nos dois sentidos**: chave sem rótulo reprova, e rótulo sem chave
também. Além disso cobra o que a estrutura promete — chave duplicada, código
fora do formato, moeda fora do ISO 4217, `position` empatada dentro de uma
categoria.

Isso é o que sustenta a entrada `{countries,skill_categories,skills}.*` no
`ignore_unused` do `config/i18n-tasks.yml.erb`. A chave é montada em tempo de
execução (`I18n.t(iso_code.downcase, scope: :countries)`), então o scanner do
i18n-tasks acusaria as ~250 entradas como órfãs; e as duas alternativas já
foram medidas e não funcionam neste repositório — ver
[i18n](i18n.md#armadilhas). A checagem de "não usada" foi trocada por uma mais
forte, não removida: aqui a lista de chaves e a lista de rótulos precisam ser
iguais, o que a checagem original nem chegava a perguntar.

O arquivo de locale tem arquivo próprio (`config/locales/vocabulary/`) porque
as ~290 chaves de vocabulário são a maior parte das chaves do projeto e nenhuma
delas é texto de tela escrito à mão. Misturadas em `config/locales/pt-BR.yml`,
o arquivo de UI deixaria de ser legível — e é nele que se procura o texto de um
botão.

## Armadilhas

**`NO` é `false` em YAML.** O código da Noruega, sem aspas, é lido como
booleano — nos dois lados: na lista curada (`iso_code: NO`) e na chave do
locale (`no:`). Nada reclama: o arquivo carrega, o país some, e o rótulo passa
a morar sob uma chave que nenhuma busca alcança. Por isso os códigos estão
entre aspas nos dois arquivos, e por isso há um exemplo em
`spec/models/country_spec.rb` que pede o nome da Noruega em particular — é o
único sinal que apareceria. O `bin/i18n-tasks normalize` preserva as aspas, mas
o que garante isso é o spec, não a ferramenta.

**Comentário em arquivo de locale não sobrevive.** O `normalize` reescreve o
YAML a partir da árvore carregada, e comentário não está na árvore. É por isso
que a explicação sobre os rótulos está aqui e no YAML de dados — que não passa
pelo normalize —, e não ao lado das chaves.

**A fonte dos códigos também erra.** A gem `countries` 8.1 dá `IDR` como moeda
de Timor-Leste, que é anterior à independência; o ISO 4217 de lá é `USD`. Está
corrigido no YAML, com o motivo escrito ao lado. Importar lista pronta economiza
digitação, não leitura.

## Receitas

**Marcar um país como de risco:** troque o `false` da linha dele em
`db/vocabulary/countries.yml`, rode `bin/rails db:seed`,
e registre na issue quem decidiu e quando. O spec que afirma "nenhum país
curado ainda" reprova — atualize-o no mesmo commit, para que a mudança apareça
no diff em vez de passar como detalhe de dado.

**Adicionar uma habilidade:** uma linha em `db/vocabulary/skills.yml`, com
`position` livre dentro da categoria (os passos são de 10 justamente para caber
uma nova entre duas sem renumerar), e o rótulo em `skills.<key>` no locale de
vocabulário. Rode `bin/i18n-tasks normalize`.

**Adicionar um país:** não deve acontecer — a lista é o ISO 3166-1 inteiro. Se
acontecer, é código de uso privado (`XA`–`XZ`), e vale o mesmo par: linha no
YAML e rótulo no locale.
