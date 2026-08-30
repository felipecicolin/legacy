# Identidade contextual e política de foto

> Presenter: [`ProfilePresenter`](../app/presenters/profile_presenter.rb)
> · Ingestão: [`ExifScrubber`](../app/models/exif_scrubber.rb) ·
> [`ScrubbedPhoto`](../app/models/concerns/scrubbed_photo.rb)
> · Entrega: [`AuthorizedBlobDelivery`](../app/controllers/concerns/authorized_blob_delivery.rb)
> · Complementos: [Visibilidade](visibility.md) · [Identidade](identity.md)

A [#23](visibility.md) fechou o registro; esta fecha as duas coisas que
continuam identificando uma base depois de o registro estar fechado: **a
pessoa que aparece ao lado dela** e **a foto**.

O princípio é o mesmo, e ele vale a repetição porque é ele que decide cada
escolha abaixo: *dado que não existe não vaza* — nem por bug de view, nem por
log, nem por export, nem por backup.

## 1. Identidade contextual

O `Profile` guarda `legal_name` e `display_name` e não decide nada sobre eles.
Qual dos dois aparece, e em que contexto, é política, e mora no
`ProfilePresenter`:

```ruby
presenter = ProfilePresenter.new(profile, role_label: t(".role"), subject: base)
presenter.name_for(context)   # => "Maria S."  ou  "responsável técnico"
```

### Por que `subject`, e não o perfil

O exemplo da issue pergunta `context.can_identify?(@profile)`. A implementação
pergunta `context.can_identify?(@subject)`, e a diferença não é detalhe: **um
perfil não tem nível de sensibilidade**. O risco de nomear alguém não vem da
pessoa, vem da obra a que ela está ligada — a mesma Maria pode ser nomeada ao
lado de uma obra de vitrine e não pode ao lado de uma base em país perseguido.
Perguntar ao perfil devolveria a mesma resposta nos dois casos.

Por isso `subject:` é **obrigatório**. Uma pessoa renderizada "solta", sem
cena, não tem como ser avaliada, e um default nulo transformaria o
esquecimento na resposta permissiva.

### Por que o rótulo de papel chega pronto

`role_label:` é uma string já traduzida, vinda de quem chama. Papel é contexto
— `Membership#role` (#20), `StaffRole` (#21), `ProjectParticipation#role`
(#31) —, e criar aqui um segundo vocabulário de papéis produziria dois
conjuntos de rótulos para as mesmas coisas, com a garantia de divergirem. O
que mora no presenter é a **política** (qual dos dois aparece), não o
**vocabulário**.

### A legenda omite, não substitui

A legenda do design system é "data e responsável". Quando o contexto não pode
identificar, `caption_for` devolve **só a data**: o responsável sai inteiro, e
não vira "responsável técnico". Numa legenda o papel não acrescenta informação
útil e ainda estreita o conjunto de quem pode ter tirado aquela foto — que é o
oposto do que a forma reduzida existe para fazer.

O `ImageFrameComponent` (#74) já recebe a legenda por slot, e o comentário
dele já dizia por quê: "a política de nome público pode proibir mostrar o
responsável, e a moldura não tem como saber disso". Nada no componente muda.

## O cabeçalho de cache que o proxy herda

`AuthorizedBlobsController` herda de `ActiveStorage::Blobs::ProxyController`, e
ele chama `http_cache_forever public: true` — `Cache-Control: public,
immutable`, validade de cem anos.

É o desenho certo lá: entrega sem autorização, conteúdo igual para todo mundo, e
a única proteção é a URL ser difícil de adivinhar. Herdado aqui, é errado do
jeito pior: **a mesma URL devolve os bytes ou 404 conforme quem pergunta.** Um
cache compartilhado — CDN, proxy de empresa — guardaria a resposta de quem tinha
direito e passaria a servi-la para quem não tem, sem nunca mais consultar este
controller. A autorização por requisição, que foi a razão de escolher proxy em
vez de redirect, seria desfeita pela camada de cache.

`forbid_shared_caching` reescreve para `private` e acrescenta `Vary: Cookie`. O
`private` mantém o cache do navegador de quem já viu, que é legítimo, e tira o
compartilhado; o `Vary` diz que é a sessão que muda a resposta.

Vale reparar em como isso passou despercebido: o cabeçalho não vem de código
escrito aqui, vem da superclasse. Nenhum spec do PR original olhava para
cabeçalho de cache, e os que existiam passavam — a negação funcionava, o 404
saía. Herdar comportamento de um controller desenhado para o caso oposto é o
tipo de coisa que só aparece quando alguém pergunta pelo que **não** está no
diff.

## 2. EXIF: destruição na ingestão

EXIF carrega coordenada GPS. Uma foto de base publicada com o EXIF intacto
localiza a base com precisão de metros, e a pessoa que publicou não vê nada de
errado na tela — o dado não aparece em lugar nenhum da imagem.

A remoção é **destruição no momento da ingestão**, e não filtro de exibição
nem job que passa depois. Os bytes com GPS **nunca chegam ao serviço de
storage**: quem os recebe é o `ExifScrubber`, que devolve um arquivo novo, e é
esse o que sobe.

Um job assíncrono teria sido a forma óbvia e é pior: entre o upload e a
execução do job existe uma janela em que o arquivo com a coordenada está
armazenado e endereçável. A janela é curta, e "curta" não é uma propriedade
que se possa afirmar sobre uma fila.

### A porta é uma só

```ruby
class ProjectPhoto < ApplicationRecord
  include ScrubbedPhoto
  attaches_scrubbed_photo :image
end
```

O macro sobrescreve o **writer** do anexo. Isso cobre as duas formas de anexar
porque elas são a mesma: `ActiveStorage::Attached::One#attach` chama
`record.public_send("image=", attachable)`. Não existe caminho de `attach` que
não passe pelo writer.

Duas armadilhas ficaram no caminho, e as duas são silenciosas:

**O override tem de ser definido na CLASSE, não num módulo do concern.** O
writer que o `has_one_attached` gera mora em `GeneratedAssociationMethods`, um
módulo *incluído* na classe. Método definido na classe vence módulo incluído;
método definido em outro módulo, incluído depois, **perde** — e o resultado não
é um erro, é a foto subindo com o GPS dentro. Por isso o macro usa
`define_method` sobre `self`, que naquele ponto é a classe concreta.

**`saver(strip: true)`, e não uma limpeza só do IFD de GPS.** O que sai é o
bloco inteiro de metadados — EXIF, IPTC e XMP. Fabricante, modelo, número de
série da câmera e miniatura embutida também dizem de quem e de onde é a foto,
e uma miniatura embutida é uma segunda cópia da imagem que ninguém inspeciona.

### O que ele recusa, e por quê

| Chega como | O que acontece |
| --- | --- |
| `nil`, `""` | passa intacto — é o caminho de **remoção** do anexo |
| `UploadedFile`, hash `io:`, `File`, `Pathname` | limpo e reembalado |
| `ActiveStorage::Blob`, signed id | `ExifScrubber::AlreadyStored` |
| qualquer outra coisa | `ExifScrubber::Unsupported` |
| bytes que a libvips não abre | `ExifScrubber::Unsupported` |

**Quem anexa foto de formulário traduz essa exceção em erro de campo.**
`ExifScrubber::Unsupported` é a porta se fechando — o desenho certo, porque
reescrever o arquivo "como está" devolveria o EXIF intacto com cara de limpo.
Mas exceção no writer vira 500, e o que a pessoa fez foi escolher o arquivo
errado. `ProjectPhoto` mostra o padrão: um módulo com `prepend` captura a
exceção e marca um atributo virtual que a validação lê.

**`prepend`, e não `def image=` no corpo da classe.** O writer que
`attaches_scrubbed_photo` instala é definido NA CLASSE com `define_method`, e um
`def` no corpo o substituiria — a foto subiria com o EXIF dentro, sem erro
nenhum. É a mesma armadilha de módulo-versus-classe que o próprio concern
documenta, só que na direção oposta.

Recusar o blob pronto é o ponto que merece explicação. É o que o **direct
upload** devolve, e sobre ele não há o que prometer: os bytes já foram
armazenados, por um caminho que ninguém limpou. Aceitá-lo e "limpar depois"
seria exatamente a janela que este desenho existe para não ter. A porta se
fecha em vez de fingir.

Recusar o que não é imagem tem a mesma lógica: reescrever "como está" um
arquivo que a libvips não abre devolveria o EXIF intacto com cara de limpo.
A consequência prática é que `Profile#avatar` (#18) passou a exigir uma imagem
de verdade — antes qualquer sequência de bytes era aceita.

O `Profile#avatar` entra no pipeline junto: "sempre e para todas as fotos" só é
verdade se valer também para o único anexo que já existia. Um retrato tirado no
celular numa base carrega a coordenada da base, igual à foto da obra.

## 3. Entrega autorizada

Os controllers do Active Storage são **públicos por padrão**, e o comentário no
código-fonte deles diz isso com todas as letras: a única proteção é a URL ser
difícil de adivinhar. Para foto de obra confidencial isso não serve — a URL é
permanente por desenho, e viaja em print, em e-mail encaminhado e em cache de
proxy.

### Como a interceptação funciona

O `config/routes.rb` declara os **mesmos padrões** que o engine declara, antes
dele:

```ruby
scope ActiveStorage.routes_prefix do
  get "/blobs/redirect/:signed_id/*filename" => "authorized_blobs#show"
  # …
end
```

As rotas da aplicação são desenhadas antes das do engine e o roteador casa na
ordem de declaração, então quem atende é o controller da aplicação. Os
**nomes** continuam sendo os do engine (`rails_blob_path`,
`rails_representation_url`) e continuam gerando as mesmas URLs — nenhum call
site muda de forma, inclusive o `ImageFrameComponent`.

Sem `as:` de propósito: repetir um nome que o engine também declara levanta
`Invalid route name, already in use` no boot.

As três alternativas foram descartadas por motivo escrito:

| Alternativa | Por que não |
| --- | --- |
| `config.active_storage.draw_routes = false` | quebra o `rich_text_area_tag`, que pede `rails_direct_uploads_url`, e o `ImageFrameComponent`, que pede o `resolve` de variante. Obrigaria a copiar o arquivo de rotas do engine para dentro da aplicação — uma cópia que desatualiza em silêncio no upgrade |
| incluir o `before_action` em `ActiveStorage::BaseController` por `to_prepare` | `__callbacks` é `class_attribute`, e as subclasses do engine registram callbacks próprios. Uma subclasse já carregada quando o patch roda mantém a cópia dela e **nunca vê** o callback novo — falha silenciosa dependente de ordem de carga |
| confiar na URL ser difícil de adivinhar | é o que o Active Storage já faz, e é o que a issue existe para não aceitar |

### Herda do controller de proxy, inclusive nas rotas de redirect

Redirecionar entregaria uma URL assinada do próprio serviço de storage, que
vale por si e não passa por autorização nenhuma. Fazendo streaming, a
autorização acontece em **toda** requisição do arquivo, e não só na primeira.

Na variante há um detalhe de ordem que custa CPU se passar batido: o
`set_representation` da classe-mãe **processa** a variante, e como está
declarado lá em cima correria antes da autorização — quem não pode ver o
arquivo teria mandado a aplicação abrir, redimensionar e gravar uma cópia dele
antes de levar o 404. Por isso `AuthorizedRepresentationsController` remove o
callback herdado e o redeclara depois do seu.

### 404, e não 403

Um 403 confirma que o arquivo existe, e a existência de uma foto já é
informação sobre a obra. É a mesma escolha que o login faz ao não dizer se a
conta existe.

## Onde a defesa não alcança

Escrito aqui porque quem usa lê aqui, e porque uma defesa com limite não
declarado vira promessa.

- **Blob criado à mão.** `ActiveStorage::Blob.create_and_upload!` seguido de
  `ActiveStorage::Attachment.create!` grava o anexo sem passar pelo writer, e
  portanto sem passar pelo `ExifScrubber`. É o análogo do `update_column` da
  #23: pula o callback por definição. Não há constraint equivalente aqui —
  EXIF é conteúdo de arquivo, e o banco não lê arquivo.
- **Registro sem `Sensitive`.** A autorização de entrega só decide sobre anexo
  cujo registro dono inclui o concern. Anexo de qualquer outro modelo continua
  sendo servido como o Active Storage sempre serviu. Quem quiser a garantia
  inclui `Sensitive`.
- **Nível `confidential` é inalcançável por sessão.** `AuthorizedBlobDelivery`
  traduz "tem sessão" em teto `restricted`, porque papel é contexto e as
  tabelas que o guardam chegam em #20, #21 e #31. Até lá **ninguém** vê foto de
  obra confidencial pela web — que é o lado seguro do erro, e não o certo.
- **`/rails/active_storage/disk/…` continua desenhada pelo engine.** Ela só é
  alcançável com um token assinado e de vida curta, que a aplicação deixou de
  emitir ao trocar redirect por streaming. Nada aponta para ela hoje; um
  `blob.url` escrito à mão voltaria a emitir.
- **Export CSV/PDF não existe ainda.** O que existe é a política que qualquer
  export terá de respeitar — `visible_to` para o conjunto,
  `Profile#serializable_hash` para o nome legal — e o spec de vazamento que
  mede o resultado sobre uma coleção mista. O exportador concreto chega com a
  issue que o tiver.
