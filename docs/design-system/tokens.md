# Tokens de cor, superfície e raio

> Arquivo: [`app/assets/tailwind/tokens.css`](../../app/assets/tailwind/tokens.css)
> · Spec: [`spec/system/design_tokens_spec.rb`](../../spec/system/design_tokens_spec.rb)
> · Página de fumaça: [`spec/components/previews/design_tokens_preview/`](../../spec/components/previews/design_tokens_preview/)

## A ideia em uma frase

A view pede um **papel** (`bg-primary`), nunca um **matiz** (`bg-clay-500`), e é
essa indireção que faz trocar a identidade visual do produto ser uma edição de
um arquivo só.

## As duas camadas

```
:root { --clay-500: #A8482C; }              ← primitiva. Nomeia o MATIZ.
@theme inline { --color-primary: var(--clay-500); }   ← semântica. Nomeia o PAPEL.
                                                        É o que vira utility.
```

A camada de baixo é escala crua: `--clay-500` não sabe que é a cor de ação.
A de cima é vocabulário: `--color-primary` não sabe que é argila. **Nenhuma view
consome a camada de baixo.**

É `@theme inline` — e não `:root` — que faz o Tailwind v4 gerar as utilities.
Uma variável declarada só em `:root` existe como custom property e não produz
`bg-*` nenhum.

Três regras do herb cobram o consumo, e elas só são cobráveis porque existe o
nome semântico para usar no lugar:

| Proibido | Regra | Use |
| --- | --- | --- |
| `bg-blue-500`, `text-gray-700` | `no-color-scale-utility` | `bg-primary`, `text-muted-foreground` |
| `h-[200px]`, `bg-[#fff]` | `no-arbitrary-tailwind` | utility de escala, ou um token novo |
| `#fff`, `rgb()`, `hsl()` em atributo | `no-hex-code` | token |

## O vocabulário

Espaçamento não tem token: use a escala padrão do Tailwind, que já é múltipla de
4px (`p-1` = 4px … `p-6` = 24px).

### Superfície

| Token | Primitiva | Uso |
| --- | --- | --- |
| `background` / `foreground` | `sand-50` / `ink-900` | O fundo da página e o texto corrido |
| `card` / `card-foreground` | `white` / `ink-900` | Bloco elevado sobre o fundo |
| `popover` / `popover-foreground` | `white` / `ink-900` | Camada flutuante — menu, dropdown |

### Ação e apoio

| Token | Primitiva | Uso |
| --- | --- | --- |
| `primary` / `primary-foreground` | `clay-500` / `sand-50` | Botão principal, link, foco |
| `primary-soft` | `clay-50` | Fundo pálido para `text-primary` — botão `soft` e `outline` |
| `secondary` / `secondary-foreground` | `sand-100` / `ink-900` | Ação secundária |
| `muted` / `muted-foreground` | `sand-100` / `sand-600` | Fundo discreto e texto de apoio |
| `accent` / `accent-foreground` | `slate-green-700` / `sand-50` | Destaque frio, contraponto à argila |

### Estado — diz SITUAÇÃO

`success`, `warning`, `destructive`. Cada um vem em três peças, e o par muda com
a ênfase:

- **Preenchido:** `bg-success text-success-foreground` — fundo forte, texto pálido.
- **Suave:** `bg-success-soft text-success` — fundo pálido, texto forte.

Os dois passam AA. É o que a `StatusBadgeComponent` (#12) vai consumir.

### Categórico — diz QUAL COISA

`category-1` … `category-4`. Vocabulário **separado** do de estado, de propósito.

Reaproveitar `destructive` para "categoria X" obriga o leitor a desambiguar
"vermelho = erro" de "vermelho = categoria X" a cada leitura — e a legenda não
resolve isso, porque a mesma cor já significou outra coisa três telas antes.
Quando precisar de mais de quatro categorias, o problema provavelmente não é
falta de token: é uma visualização que está pedindo outra codificação que não
cor.

### Estrutura

| Token | Primitiva | Por quê |
| --- | --- | --- |
| `border` | `sand-200` | Divisória **decorativa**. Fica abaixo de 3:1 de propósito — a WCAG 1.4.11 não alcança divisória |
| `input` | `sand-500` | Fronteira de **campo**. A 1.4.11 alcança, então é um passo mais escuro |
| `ring` | `clay-500` | Anel de foco |

`border` e `input` não são o mesmo token porque não têm a mesma obrigação.

### Raio

| Token | Valor | Uso |
| --- | --- | --- |
| `rounded-sm` | 5px | **Controle** — botão, campo |
| `rounded-lg` | 8px | **Cartão** |
| `rounded-full` | 9999px | Pílula, avatar |

Não existem `rounded-md` nem `rounded-xl`. Isso é deliberado, e é uma armadilha
que vale conhecer: no Tailwind v4 o `@theme` **mescla** com a escala padrão em
vez de substituí-la. Um `rounded-xl` continua funcionando — só que pegando o
default do Tailwind, sem token por trás. O raio deixa de ser tokenizado e
ninguém percebe. Se um raio novo for mesmo necessário, adicione a primitiva e o
apelido; não use o buraco.

## Contraste

Todo par de texto passa **WCAG AA** (4.5:1). Fronteira de UI passa 3:1.

Isso não é anotação de boa-fé: `spec/system/design_tokens_spec.rb` recalcula a
razão a partir da cor que o navegador resolveu e reprova abaixo do limiar. A
tabela no fim do `tokens.css` é conveniência de leitura — a verificação é o
spec, e por isso ela não envelhece.

Os pares são **derivados**, não listados à mão: todo `X` que tenha um
`X-foreground` vira par, e todo `X` que tenha um `X-soft` também. Um par novo
entra coberto sem ninguém lembrar de atualizar o spec.

> A paleta original da issue #6 trazia `--amber-600: #B07A18`, que dava 3.09:1
> sobre `--amber-100` — reprovado. Âmbar de meio-tom sobre âmbar pálido é a
> falha clássica de contraste, e ela não é visível a olho nu. Escurecido para
> `#8C6012`, que passa nos dois usos sem sair do matiz.

## Como o spec sustenta tudo isso

**O problema:** token renomeado ou removido não gera erro em lugar nenhum. A
view continua pedindo `bg-primary`, o Tailwind simplesmente deixa de emitir a
classe, e o elemento sai transparente. Sem exceção, sem log, sem linter —
nenhuma ferramenta deste repositório lê o CSS compilado.

**A resposta:** perguntar ao navegador. O spec sobe Chrome headless, abre a
página de fumaça com o CSS de verdade carregado e lê `getComputedStyle`.

Três coisas ele cobra:

1. **Toda cor resolve para cor de verdade.** Transparente reprova.
2. **Todo token declarado no `tokens.css` aparece na página de fumaça.** É esse
   cruzamento que impede a página de virar uma lista desatualizada.
3. **Todo par passa AA.**

Verificado por mutação — as três reprovam de verdade:

| Mutação | Reprova em |
| --- | --- |
| `--color-warning: var(--amber-999)` (primitiva inexistente) | `bg-warning saiu transparente` |
| `--amber-600` de volta para `#B07A18` | `warning-foreground sobre warning dá 3.09:1` |
| Token novo no CSS sem entrada na página | `the missing elements were: ["brand-new"]` |

Vale reparar no primeiro caso: a utility **é** gerada — a regra CSS existe, com
`background-color: var(--amber-999)`. Um teste que só lesse o CSS compilado
passaria. Só o navegador resolve a cadeia de `var()` e revela o transparente. É
o que paga o custo de rodar um navegador aqui.

### Duas fragilidades da página de fumaça

**As utilities estão escritas literalmente, uma por linha.** O Tailwind v4 gera
classe varrendo o texto-fonte do projeto. `class="bg-<%= name %>"` num laço não
produziria classe nenhuma, a página inteira sairia transparente, e o spec
reprovaria por um motivo que não é o dele. (O varredor alcança `spec/` —
verificado.)

**Toda cor é sondada por `bg-*`**, mesmo a de papel textual como
`muted-foreground`. A propriedade `color` **herda**: um `text-muted-foreground`
inexistente pegaria a cor do corpo da página e passaria no teste. Já
`background-color` nasce transparente, então classe que não existe se denuncia.
Metade dos tokens ficaria sem cobertura se o teste sondasse `color`.

## Receitas

### Adicionar um token

1. Se precisar de um matiz novo, adicione a **primitiva** em `:root`.
2. Adicione o **apelido semântico** em `@theme inline`, apontando para ela.
3. Adicione a linha na **página de fumaça**
   (`spec/components/previews/design_tokens_preview/default.html.erb`), com a
   utility escrita literalmente.
4. Se for um par de texto (`X` + `X-foreground`, ou `X` + `X-soft`), o spec já o
   cobre automaticamente — só garanta que passe AA.
5. Atualize a tabela de contraste no fim do `tokens.css`.
6. `bin/rails tailwindcss:build && bundle exec rspec spec/system/design_tokens_spec.rb`

Se faltar um token, **adicione o token** — nunca uma exceção de linter.

### Trocar a identidade visual do produto

Edite os valores das primitivas em `:root`. Se um papel precisar de outro matiz,
reaponte o apelido em `@theme inline`.

**Nenhuma view muda.** É esse o teste de que a arquitetura está de pé: se uma
troca de paleta exigir tocar em template, algum lugar está consumindo primitiva
direto.

Depois: rode o spec. Ele vai reprovar todo par que a paleta nova tiver deixado
abaixo de AA — que é exatamente o momento de descobrir isso.

## Ainda não existe

- **Tema escuro.** A estrutura o comporta — seria um segundo bloco reapontando
  os apelidos para outras primitivas — mas implementá-lo ficou fora de #6.
- **Tokens de tipografia.** São de #7.
