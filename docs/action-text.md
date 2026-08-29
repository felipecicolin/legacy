# Action Text

O `config/application.rb` já pedia `action_text/engine` desde o primeiro commit,
mas o Action Text não estava instalado: sem migration, sem partial, sem `trix`
no importmap. A #32 instalou — e instalar aqui não é rodar o generator e seguir,
porque o generator deposita ERB dentro de `app/views/`, e neste repositório todo
ERB é lintado.

Este documento é o **porquê**. As regras em uma linha estão no
[`AGENTS.md`](../AGENTS.md).

## O que ficou instalado

| Arquivo | O que é |
| --- | --- |
| `db/migrate/*_create_action_text_tables.action_text.rb` | A tabela `action_text_rich_texts` |
| `app/views/active_storage/blobs/_blob.html.erb` | Como um anexo é renderizado — reescrito |
| `app/views/layouts/action_text/contents/_content.html.erb` | O envelope `.trix-content` |
| `app/assets/stylesheets/actiontext.css` | O CSS do Trix, **verbatim** |
| `app/assets/tailwind/action_text.css` | As sobreposições do projeto, com token |
| `config/initializers/action_text.rb` | A política de anexo |
| `app/javascript/trix_locale.js` | A barra de ferramentas em pt-BR |
| `app/javascript/controllers/rich_text_controller.js` | Recusa de anexo no navegador |
| `vendor/javascript/trix.js` | O Trix baixado, não apontado para CDN |

## A política de anexo, e por que ela existe

O Trix embute imagem criando um blob do Active Storage e referenciando-o por um
elemento `action-text-attachment`. Esse caminho **não passa** pelo processamento
de foto da plataforma — nem limpeza de EXIF, nem entrega autorizada. Num campo
de texto rico de recurso confidencial isso é uma porta lateral: quem escreve o
texto publica uma imagem por uma rota que ninguém audita, porque ninguém procura
uma rota de upload dentro de um editor de texto.

A #32 ofereceu duas saídas — desligar o anexo embutido, ou rotear o upload do
Trix pelo mesmo processamento das demais fotos. A escolha foi **desligar**, por
duas razões: o pipeline de foto ainda não existe (é a #18), e rotear o upload
para um pipeline inexistente teria virado uma promessa sem cobrança. Quando
houver um caso concreto que precise de imagem dentro do texto, a decisão se
revisita — com o pipeline pronto do outro lado.

Ela é cobrada em duas camadas, e as duas são deliberadas.

### No servidor — a que vale

```ruby
ActionText::ContentHelper.sanitizer = sanitizer.new(prune: true)
ActionText::ContentHelper.allowed_tags = sanitizer.allowed_tags + %w[figure figcaption]
```

A lista de tags permitidas do Action Text é a lista padrão do sanitizador
**mais** `action-text-attachment`, `figure` e `figcaption`. O que a linha acima
faz é devolver a lista sem o elemento de anexo.

Sozinha, ela não bastaria — e é aqui que mora a armadilha. O `PermitScrubber`
do `rails-html-sanitizer` **desembrulha** uma tag não permitida por padrão: ele
tira o elemento e mantém os filhos. E o Action Text renderiza o conteúdo do
anexo (o `_blob.html.erb`, com o `img` e a URL do blob) **antes** de sanitizar.
O resultado seria o elemento de anexo sumindo e a imagem ficando — exatamente o
que a política quer impedir, com a aparência de estar funcionando.

`prune: true` troca desembrulhar por podar: o nó vai embora com os filhos. Medido
neste repositório, com um anexo real:

```
sem prune:  <div>obra</div><action-text-attachment …><figure …><img src="/rails/active_storage/…">…
com prune:  <div>obra</div>
```

O `prune` vale para toda tag não permitida, e é uma melhora fora do anexo
também: `<script>alert(1)</script>` some inteiro, em vez de deixar o texto
`alert(1)` para trás.

**Onde o gancho é registrado importa.** A `ActionText::Engine` atribui o
sanitizador dela num `config.after_initialize` seguido de
`ActiveSupport.on_load(:action_view)`. Um `to_prepare` — que é o reflexo natural
— roda **antes** disso e é sobrescrito sem erro nenhum: `allowed_tags` fica de
pé, `sanitizer` volta ao padrão, e a política some pela metade. Foi o que
aconteceu na primeira tentativa, e o sintoma era o `<script>` deixando `alert(1)`
para trás. O initializer usa o mesmo par de ganchos que a engine, registrado
depois dela.

### No navegador — a que evita oferecer o que vai ser recusado

`app/javascript/controllers/rich_text_controller.js` cancela `trix-file-accept`,
que é o único ponto por onde arquivo entra no Trix: botão de anexar, arrastar e
soltar, e colar do clipboard passam todos por ele. O
`app/assets/tailwind/action_text.css` esconde o grupo de ferramentas de arquivo
da barra, para o botão nem aparecer.

Nada disso é garantia — é JavaScript e CSS no cliente. A garantia é o servidor.

### O que continua aberto

O endpoint de upload direto do Active Storage (`/rails/active_storage/direct_uploads`)
segue montado, porque a foto de perfil da #18 precisa dele. Quer dizer: a
política fecha a porta do **texto rico**, não a da criação de blob. Um blob
criado à mão continua possível para quem tem sessão; ele só não tem como ser
referenciado de dentro de um corpo de texto rico renderizado.

## A barra de ferramentas em pt-BR, e a corrida que ela perde

Os rótulos do Trix não passam pelo `t()` do Rails: a barra é montada em
JavaScript, a partir de `Trix.config.lang`. Nenhum dos três linters de i18n do
repositório enxerga esses textos.

Duas coisas quebram em silêncio aqui.

**`Object.assign`, não atribuição.** O gerador do HTML padrão da barra fecha
sobre o *objeto* de lang, não sobre `config.lang`. Trocar o objeto
(`Trix.config.lang = {...}`) deixa o gerador lendo o antigo, em inglês.

**A ordem.** `Trix.config.lang` precisa estar traduzido antes de o custom
element `trix-editor` ser definido — o `getDefaultHTML()` só é chamado uma vez
por barra, quando o elemento sobe. O Trix registra o `customElements.define`
dentro de um `setTimeout`, então qualquer código **síncrono** do
`application.js` chega primeiro. Um `connect()` de Stimulus, que espera o DOM,
chega tarde demais.

Isso foi medido, não deduzido: trocar `localizeTrix()` por
`setTimeout(localizeTrix, 0)` no `application.js` reprova dois exemplos de
`spec/system/rich_text_editor_spec.rb` — e não reprova mais nada em lugar
nenhum. Por isso as duas decisões de navegador têm spec de sistema: são
invisíveis para o `bin/stimulus_lint`, que não lê o Trix, e para o
`bin/herb_lint`, que não lê CSS compilado.

## Os partials reescritos

O `bin/herb_lint` roda sobre o repositório inteiro, então os dois partials do
generator precisam passar como qualquer template do projeto.

Vale registrar o que **não** aconteceu, porque a #32 previa: o `_blob.html.erb`
do generator **não** dispara `no-hardcoded-string`, `no-color-scale-utility` nem
`no-arbitrary-tailwind`. Todo texto visível dele sai de `<%= %>`, e o `class` da
`figure` é interpolado — o que faz `getStaticAttributeValueContent` devolver
nulo e as duas regras de Tailwind nem olharem. O que ele dispara são três avisos
do catálogo embutido do herb: `erb-no-interpolated-class-names` (duas vezes) e
`html-img-require-alt`. Como o `failLevel` é `error`, avisos não reprovam a CI —
o partial original passaria, sujo.

A reescrita resolve os três: as classes saem de `class_names`, num nó ERB só, e
a imagem ganha `alt` com o nome do arquivo.

O vocabulário `attachment`, `attachment__caption`, `attachment--preview`
continua. Não é Tailwind: são as âncoras do `actiontext.css`, as mesmas que o
editor usa. Renomeá-las para token semântico desligaria o CSS do Trix sem trocar
nada em lugar nenhum. Token semântico entra onde é cor da aplicação
(`text-muted-foreground` na legenda), não no chrome do editor.

Na política atual esse partial não chega a ser alcançado de dentro de texto
rico: o sanitizador poda o anexo antes. Ele fica porque é o que o Action Text
renderiza se a política mudar, e porque um template no repositório que não passa
no linter é dívida, esteja ele no caminho quente ou não.

## Por que o `actiontext.css` fica verbatim

Ele tem hex e SVG embutido em toda linha, e nada disso passaria pelas regras de
token — se as regras alcançassem CSS, que não alcançam: o herb lê ERB.

Mesmo assim o arquivo ficou **intocado**, e é uma escolha. Ele estiliza o chrome
de um web component de terceiro, e é gerado a partir do `trix.css` upstream.
Mantê-lo idêntico ao que o Rails deposita é o que permite re-sincronizá-lo num
upgrade sem reler diff. Uma cópia editada à mão de um arquivo upstream é pior
que a cópia inteira: ninguém sabe mais o que é customização e o que é atraso.

O que é decisão deste produto vive em `app/assets/tailwind/action_text.css`, com
`@apply` sobre os tokens semânticos — assim trocar a identidade visual segue
sendo editar só o `tokens.css`.

As duas folhas trazem regra **sem camada** para `trix-editor`, e sem camada quem
vence é a ordem de carga. Por isso o `stylesheet_link_tag "actiontext"` vem
antes do `"tailwind"` nos dois layouts.

## O `database_consistency` e o polimórfico

`action_text_rich_texts.record` é polimórfico, logo não tem FK. A #32 pedia para
verificar isso antes de escrever o resto, e a verificação foi feita: o
`database_consistency` **não reclama**, e nenhuma configuração foi necessária.

O motivo é que ele só olha modelos do projeto (`Helper.project_klass?`), e
`ActionText::RichText` e `ActiveStorage::Attachment` vêm de gem. Que a tabela em
si é alcançável foi confirmado por sonda: um modelo temporário apontado para
`action_text_rich_texts` produz cinco ofensas na hora. Ou seja, o silêncio é
escopo, não ferramenta desligada.

Se um dia um modelo do projeto herdar dessas tabelas, a saída é configurar a
checagem por modelo e coluna em `.database_consistency.yml`, com o motivo
escrito ao lado — nunca desligar um checker inteiro.

## O modelo de teste

`spec/support/rich_text_probe.rb` define o `RichTextProbe` e cria a tabela dele
num `before(:suite)`. A tabela **não** entra no `db/schema.rb`: o schema
commitado descreve o banco de produção, e uma tabela de teste dentro dele
mentiria para o `database_consistency` e para quem lê o arquivo.

Ele existe porque a #32 instala a infraestrutura antes de existir domínio —
`Organization`, `MissionBase`, `Project`, `SiteSurvey` e `ProgressReport` são
das tranches seguintes. Um modelo de aplicação criado só para o teste colocaria
em `app/` código que ninguém chama, e a cobertura 100% cobraria spec dele.

Quando o primeiro modelo de verdade ganhar `has_rich_text`, o `RichTextProbe`
some e os specs migram para ele.
