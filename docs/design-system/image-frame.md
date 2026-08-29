# Moldura de imagem

> Componente: [`app/components/image_frame_component.rb`](../../app/components/image_frame_component.rb)
> · Controller: [`app/javascript/controllers/image_frame_component_controller.js`](../../app/javascript/controllers/image_frame_component_controller.js)
> · Spec de sistema: [`spec/system/image_frame_spec.rb`](../../spec/system/image_frame_spec.rb)

## A ideia em uma frase

O retângulo existe antes da imagem: a moldura reserva a proporção por CSS, e
tudo o mais — variante que ainda processa, anexo ausente, download que falhou —
acontece dentro de um quadro que já tem o tamanho final.

## Por que a proporção é reservada, e não medida

Uma `<img>` sem dimensão ocupa zero até o byte chegar. Quando chega, o
container cresce e empurra tudo o que está abaixo — o *layout shift*. Não é
cosmético: quem está na obra, com rede ruim, lê o relatório enquanto ele se
move debaixo do dedo, e clica no que não queria.

A defesa é o `aspect-ratio` no container, com a imagem em `absolute inset-0`.
A imagem sai do fluxo: não empurra nada porque não ocupa espaço próprio. A
altura do quadro vem só da proporção e da largura disponível.

`spec/system/image_frame_spec.rb` mede isso no navegador, de duas formas
independentes: a altura do quadro **sem anexo** tem de ser igual à do quadro
**com foto**, e a geometria medida antes de a imagem carregar tem de ser
idêntica à medida depois do evento `load`. A segunda espera o trabalho de
verdade — a variante é processada sob demanda pela libvips no primeiro pedido.

## Os tokens de proporção

`aspect-wide` (16/9), `aspect-photo` (4/3) e `aspect-tile` (1/1) moram em
[`tokens.css`](../../app/assets/tailwind/tokens.css), na mesma camada dupla das
cores: `--ratio-*` em `:root` é o valor, `--aspect-*` em `@theme inline` é o
papel, e é ele que gera a utility.

Três decisões que não são óbvias:

**Por que token, e não `aspect-[4/3]`.** Valor arbitrário é proibido pelo
`no-arbitrary-tailwind`, e a razão vale aqui inteira: o enquadramento de foto
de obra é decisão de design system, não de uma view. Trocar 4/3 por 3/2 tem de
ser uma edição no `tokens.css`.

**Por que nomes próprios, e não `aspect-video`/`aspect-square`.** Esses dois
existem no núcleo do Tailwind. Usá-los faria a classe continuar funcionando
mesmo se o token sumisse — vinda de outro lugar, com outro valor, sem erro em
lugar nenhum. É a mesma armadilha do `rounded-xl` descrita em
[`tokens.md`](tokens.md): um nome que o núcleo também tem não denuncia o token
removido. Com `aspect-wide`, remover o token faz o `aspect-ratio` computado
sair `auto`, e o spec de sistema reprova.

**Por que eles não entram na página de fumaça dos tokens.** O
`DesignTokenManifest` varre o `@theme inline` atrás de `--color-*` e
`--radius-*`, e o cruzamento com
`spec/components/previews/design_tokens_preview/` cobre essas duas famílias. A
proporção é sondada pelo spec desta moldura, que já pergunta ao navegador o
`aspect-ratio` resolvido de cada enquadramento — a mesma pergunta, no lugar
onde ela tem contexto. Estender o manifesto obrigaria a página de fumaça a
ganhar altura de verdade só para medir proporção.

Verificado por mutação: renomear `--aspect-wide` reprova em
`aspect-* saiu como auto em playground`.

## Os três estados

| Estado | Quando | O que aparece |
| --- | --- | --- |
| Vazio | Sem anexo, **ou** anexo que nunca vira imagem | Ícone e "Sem imagem" |
| Processando | Anexo representável, `analyzed?` ainda falso | Ícone e "Processando a imagem" |
| Pronto | Anexo representável e analisado | A `<img>` com `srcset` |

O caso que exige atenção é o **anexo que não é imagem** — um PDF, um `.txt`.
Ele cai no estado vazio, e não no de processamento, porque "processando" é uma
promessa: diz que existe trabalho em curso e que a imagem vai chegar. Para um
`.txt` não vai chegar nunca, e a promessa vira uma espera infinita para quem
lê.

## O erro de carregamento

Uma `<img>` que falha mostra o ícone quebrado do navegador — que muda de
desenho a cada navegador, não passa por token nenhum e não diz nada em
português.

A saída é estrutural, não decorativa: o quadro de apoio vem **antes** da imagem
no DOM e os dois ocupam o mesmo retângulo absoluto, então a imagem pinta por
cima do apoio quando carrega. Esconder a imagem no erro revela um estado
neutro que já estava lá, no mesmo lugar e do mesmo tamanho. Nada se move.

Duas sutilezas no controller Stimulus:

**No estado pronto o quadro de apoio é `aria-hidden`.** Ele está atrás da
imagem e não é conteúdo: quem descreve a imagem é o `alt`. No erro, o
controller devolve o quadro ao leitor de tela junto com esconder a imagem.

**`connect()` reconfere `complete` e `naturalWidth`.** Imagem em cache termina
de carregar antes de o Stimulus conectar, e o evento `error` já passou quando o
`data-action` entra em vigor. Uma imagem `complete` com `naturalWidth` zero é
exatamente a falha que se perdeu — sem essa reconferência, o estado de erro
não aparece justamente no caso mais comum.

## `alt` é obrigatório no construtor

Não tem default. Uma imagem decorativa passa `alt: ""` **explicitamente**, e
isso é uma decisão registrada no call site em vez de um esquecimento. O
atributo sai no HTML mesmo vazio: `alt` ausente faz o leitor de tela ler o nome
do arquivo.

## `srcset`, `sizes` e o carregamento

Três larguras — 480, 960 e 1440 — servidas por variantes do Active Storage.
Cobrem o telefone, o cartão de grade e a coluna larga do desktop; acima de 1440
a imagem cresce sem ganhar detalhe visível.

O `sizes` padrão descreve o grid de galeria (`100vw`, `50vw` a partir de 768px,
`33vw` a partir de 1280px). Quem monta outro grid passa o seu — um `sizes`
errado é pior que nenhum, porque faz o navegador escolher a variante errada com
confiança.

A moldura nasce `loading="lazy"` e `decoding="async"`, sem parâmetro para
desligar. Foto de obra aparece em lista, abaixo da dobra, e é esse o caso que
existe hoje. Quando houver uma acima da dobra — uma capa de relatório —, o
parâmetro entra junto com o caso de uso que o justifica, não antes.

## Por que o anexo aceita quatro formas

O construtor recebe o proxy do `has_one_attached`, um `ActiveStorage::Attachment`,
um blob solto ou `nil`, e normaliza os quatro para um blob. Não é generosidade:
o proxy é o que um modelo entrega, o attachment é o que uma coleção entrega, e
o blob é o que um upload direto entrega antes de existir modelo. Exigir uma
forma só empurraria a conversão para todo call site.

## Por que o Active Storage foi instalado aqui

As três tabelas do Active Storage não existiam no schema até esta issue. A
alternativa considerada — construir e testar a moldura sem elas — foi
descartada por evidência, não por gosto:

- `ActiveStorage::Blob.new` consulta o schema antes de qualquer coisa e levanta
  `PG::UndefinedTable` sem as tabelas. Não há blob em memória.
- `url_for` sobre um blob **não** persistido levanta
  `Cannot get a signed_id for a new record`: a URL de representação é assinada
  a partir do id. Sem persistência não há `srcset`.

Ou seja: não existe versão desta moldura que emita `srcset` sem as tabelas. O
`bundle exec database_consistency` passa limpo com elas — foi conferido antes
de a migration entrar.

Nos specs de componente os blobs vêm de `create_before_direct_upload!`:
persiste a linha, não sobe bytes, e não processa variante nenhuma (o Active
Storage só processa quando a URL é pedida). O spec de sistema é o único que
precisa dos bytes de verdade, e é lá que a libvips entra.
