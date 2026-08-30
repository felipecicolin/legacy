# Layout de autenticação — o split de imagem e formulário

As três telas de autenticação — acessar, pedir recuperação e definir nova senha
— não passam pelo `AppShellComponent`. Elas usam o layout `authentication`, que
renderiza a `AuthLayoutComponent`: painel de imagem ocupando a metade esquerda
da tela e o formulário na metade direita.

## Por que um layout novo, e não um `if` no da aplicação

O `AppShellComponent` é a moldura de **quem já entrou**: gaveta de navegação,
cabeçalho com o gatilho dela e uma coluna de conteúdo travada em `max-w-7xl`
dentro de um grid de 12 colunas. Nenhuma das três coisas serve a quem ainda não
tem sessão — não há para onde navegar, e a tela quer a largura inteira.

A alternativa era ramificar o layout da aplicação em `authenticated?`. Ela foi
recusada por dois motivos. O primeiro é que `authenticated?` responde a pergunta
errada: uma página de erro 404 também é servida sem sessão e continua querendo o
shell. O segundo é que uma bifurcação ali embaça o contrato do shell — ele passa
a ser "o shell, exceto quando não é", e a próxima pessoa que mexer nele precisa
manter as duas formas na cabeça. `layout "authentication"` no controller diz a
mesma coisa em uma linha, e um `grep` a encontra.

## O que o layout novo precisou trazer de volta

Trocar de layout é o tipo de mudança que perde, em silêncio, o que o layout
antigo dava de graça. Foram três coisas, e as três estão cobertas por spec de
request em `spec/requests/sessions_spec.rb`:

- **A marca de dado simulado.** O `SimulatedDataBannerComponent` vive no layout
  justamente para nenhuma tela precisar lembrar dele. Um segundo layout sem o
  banner fura a promessa "toda tela nasce marcada" — e não reprova nada, porque
  o spec que existia provava a marca só em `root_path`.
- **O partial de flash.** Senha errada é `redirect_to new_session_path,
  alert:`. O spec de sessão que já existia afirma sobre `flash[:alert]`, e ele
  passa com o toast invisível: o flash está na sessão, só não foi pintado. Sem o
  partial, a tela recusaria a pessoa sem dizer por quê.
- **O `<main id="main-content">`.** Era o `AppShellComponent` que declarava a
  landmark. A `AuthLayoutComponent` declara a sua.

O que **não** voltou foi o link de pular para o conteúdo, e isso é decisão, não
esquecimento — ver abaixo.

## `flex-row-reverse`: a ordem do DOM não é a ordem da tela

No DOM o formulário vem **antes** do painel de imagem; quem o joga para a
direita é o `flex-row-reverse` do container. A ordem visual é a pedida — imagem
à esquerda —, e a ordem de leitura é a útil: teclado e leitor de tela chegam ao
campo de e-mail sem atravessar a ilustração.

É por isso que aqui não há link de "ir para o conteúdo principal". Um skip link
existe para pular o que vem antes do conteúdo; nesta tela não vem nada. E marcar
o painel como `aria-hidden` seria pior: ele é slot, e o dia em que receber uma
imagem com legenda — ou um link, como faz a tela do Fly.io — o texto sumiria
para quem usa leitor de tela sem que nada avisasse.

O `spec/components/auth_layout_component_spec.rb` cobra as duas metades dessa
decisão de uma vez: um `flex-row-reverse` removido inverteria a pintura, e um
`<aside>` movido para antes do `<main>` inverteria a leitura.

## O painel é slot, e o apoio é o padrão

`renders_one :illustration`. Enquanto não há foto, o padrão é um painel
`bg-accent` com ícone e uma linha de texto. Os dois ocupam o mesmo retângulo
(`absolute inset-0` dentro de um `<aside class="relative">`), então trocar o
apoio por uma imagem de verdade não muda o enquadramento da tela nem exige tocar
neste componente:

```erb
<%= render AuthLayoutComponent.new do |auth| %>
  <% auth.with_illustration do %>
    <%= image_tag "login.jpg", alt: "", class: "absolute inset-0 h-full w-full object-cover" %>
  <% end %>
  <%= yield %>
<% end %>
```

O par de cor é `bg-accent` / `text-accent-foreground`, e isso importa: o
`spec/system/design_tokens_spec.rb` recalcula o contraste dos pares
`X`/`X-foreground` **declarados**. Combinar dois tokens que não formam par —
`text-muted-foreground` sobre `bg-accent`, por exemplo — produz uma combinação
que ninguém mede, e que pode reprovar em AA sem nada acusar.

Não é a `ImageFrameComponent`: ela reserva uma **proporção** e emite um
`<figure>` com legenda. Um painel lateral quer altura cheia, que é outro
problema.

## Por que o painel some abaixo de 1024px

`hidden desktop:block`. Um decorativo espremido em 380px não mostra imagem
nenhuma e empurra o formulário para baixo da dobra — no telefone, a tela de
acesso é só o formulário. O `spec/system/auth_layout_spec.rb` mede isso no
navegador, porque `w-1/2` e `desktop:block` são decisões que só existem depois
que o CSS resolve: num spec de componente o que existe é a string de classes.

## O `<head>` é um só

Os dois layouts renderizam `layouts/_head`. A duplicação seria cara por um
motivo específico: o `stylesheet_link_tag "tailwind"` ao lado do `:app` e a
ordem do `actiontext` antes do `tailwind` são duas armadilhas documentadas no
`AGENTS.md` que falham **sem erro** — a página sobe sem uma única utility. Com
uma cópia só, a próxima correção alcança as duas telas.

Uma diferença de mecânica: dentro do partial a chamada é
`content_for(:head)`, e não `yield :head`. `yield` com símbolo só resolve em
layout; num partial devolveria vazio, também sem levantar erro.
