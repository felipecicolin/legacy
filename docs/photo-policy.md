# Identidade contextual e política de foto

> Presenter: [`ProfilePresenter`](../app/presenters/profile_presenter.rb)
> · Ingestão: [`ExifScrubber`](../app/models/exif_scrubber.rb) ·
> [`ScrubbedPhoto`](../app/models/concerns/scrubbed_photo.rb)
> · Complementos: [Visibilidade](visibility.md) · [Identidade](identity.md)

A [#23](visibility.md) fechou o registro; esta fecha as duas coisas que
continuam identificando uma base depois de o registro estar fechado: **a
pessoa que aparece ao lado dela** e **a foto**.

Duas das três, para ser exato. A **entrega autorizada do arquivo** foi adiada
para a [#21](https://github.com/felipecicolin/legacy/issues/21), e a seção 3
explica por quê — o resumo é que hoje ela guardaria uma porta sem nada atrás.

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

### A orientação é o efeito colateral que não pode passar batido

Apagar o bloco de metadados apaga junto a tag `Orientation`, e é ela que diz ao
visualizador para girar a foto do celular. Sem mais nada, todo retrato tirado
em pé sairia deitado — um bug visível em cem por cento das fotos de telefone, e
que ninguém associaria à remoção de EXIF.

O que salva é o `ImageProcessing::Vips`, que aplica `autorot` ao carregar: os
pixels são **girados de verdade** antes de a tag sumir, e a imagem gravada já
está na posição certa sem depender de metadado nenhum. Medido em libvips
8.18.6: uma origem 64×48 com `Orientation = 6` sai 48×64 e sem campo de EXIF.

Isso é propriedade da biblioteca, não do código daqui, e é exatamente por isso
que há um exemplo cobrando: trocar o `ImageProcessing` por um
`Vips::Image#write_to_file` direto, ou passar `autorot: false`, desliga a
correção **sem erro nenhum**.

## 3. Entrega autorizada — adiada para a #21

A metade de entrega **não entrou**, e o motivo é que ela ainda não tem o que
proteger. Os controllers do Active Storage são públicos por padrão — o
comentário no código-fonte deles diz isso com todas as letras —, e a única
proteção nativa é a URL ser difícil de adivinhar. Isso continua verdade nesta
aplicação hoje.

O que fez a defesa ser adiada em vez de escrita:

- **Nada em produção inclui `Sensitive`.** O único host do concern é o
  `SensitiveTestRecord` de `spec/support/`. Uma autorização de entrega que
  decide pela sensibilidade do registro dono do anexo estaria guardando uma
  porta sem nada atrás.
- **O único anexo que existe é o `Profile#avatar`**, e `Profile` não é
  `Sensitive` — ou seja, o anexo real do sistema cairia justamente no caso que
  a política deixa passar.
- **O caminho de permissão não é testável ainda.** "Tem sessão" só consegue
  virar teto `restricted`, porque papel é contexto e as tabelas que o guardam
  chegam na #20, na #21 e na #31. Não existe fonte de clearance capaz de emitir
  `confidential`, então o lado *permitido* da regra não teria como ser
  exercitado ponta a ponta — só o lado que nega.

Código não exercitável guardando dado que não existe é pior que a ausência
dele: ele parece uma garantia. A exigência está registrada na **#21**, que é
onde a clearance passa a existir.

O ponto que quem retomar precisa saber, e que custou a investigação: os
controllers da engine **não herdam de `ApplicationController`**, então o
`before_action :require_authentication` do "fechado por padrão" não os alcança.
Fechar isso não é adicionar um filtro num lugar só — é decidir entre
interceptar as rotas do engine em `config/routes.rb` (as rotas da aplicação são
desenhadas antes e o roteador casa na ordem de declaração; verificado),
`config.active_storage.draw_routes = false` (que quebra o `rich_text_area_tag`
e obriga a copiar o arquivo de rotas do engine, cópia que desatualiza em
silêncio no upgrade) ou um `to_prepare` sobre `ActiveStorage::BaseController`
(que **não funciona**: `__callbacks` é `class_attribute`, e uma subclasse já
carregada mantém a cópia dela e nunca vê o callback novo).

Dois detalhes que a implementação futura vai precisar e não são óbvios: quem
autoriza tem de herdar do controller de **proxy** inclusive nas rotas de
redirect, porque redirecionar entrega uma URL assinada do serviço de storage
que vale por si; e o `show` do proxy responde com `http_cache_forever
public: true`, um `Cache-Control` público e permanente sem `Vary` — que num CDN
ou proxy compartilhado devolve o arquivo a quem nunca foi autorizado, anulando
a defesa inteira. Autorizar a entrega **exige** trocar esse cabeçalho.

## Onde a defesa não alcança

Escrito aqui porque quem usa lê aqui, e porque uma defesa com limite não
declarado vira promessa.

- **Blob criado à mão.** `ActiveStorage::Blob.create_and_upload!` seguido de
  `ActiveStorage::Attachment.create!` grava o anexo sem passar pelo writer, e
  portanto sem passar pelo `ExifScrubber`. É o análogo do `update_column` da
  #23: pula o callback por definição. Não há constraint equivalente aqui —
  EXIF é conteúdo de arquivo, e o banco não lê arquivo.
- **Anexo de texto rico não passa por aqui.** O Trix embute imagem criando o
  blob por direct upload, e esse caminho não tem writer para interceptar — os
  bytes chegam ao storage como vieram. A [#32](action-text.md) fecha o outro
  lado: o elemento de anexo é **podado** na renderização, então a imagem nunca
  é exibida nem endereçada por uma tela. Nenhum modelo de produção tem
  `has_rich_text` hoje; quando algum tiver, o blob órfão continua no disco.
- **A entrega do arquivo não é autorizada.** Quem tiver a URL do blob baixa o
  arquivo, logado ou não — é o comportamento nativo do Active Storage, e ele
  continua valendo aqui. O que esta issue garante sobre o arquivo entregue é só
  que ele não carrega EXIF. Ver a seção 3 e a **#21**.
- **Formato que a libvips não abre não é aceito.** É o lado seguro do erro, mas
  é um lado: um `.heic` de iPhone só entra se a libvips instalada tiver suporte
  a HEIF. O Dockerfile instala a `libvips` da distribuição, e o que ela abre
  varia com a build. Quando isso aparecer, a resposta é a dependência de
  sistema, nunca aceitar o arquivo sem limpar.
- **Export CSV/PDF não existe ainda.** O que existe é a política que qualquer
  export terá de respeitar — `visible_to` para o conjunto,
  `Profile#serializable_hash` para o nome legal — e o spec de vazamento que
  mede o resultado sobre uma coleção mista. O exportador concreto chega com a
  issue que o tiver.
