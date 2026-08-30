# Biblioteca de componentes

> Componentes: [`app/components/`](../../app/components/) · Previews:
> [`spec/components/previews/`](../../spec/components/previews/)

## O shell e a grade

O `AppShellComponent` é o único dono dos landmarks de estrutura: skip link,
`header`, `nav`, `aside` e um `main`. A navegação entra pelo slot `navigation`,
para que o layout possa trocar seus links sem duplicar drawer ou tratamento de
foco. Em telas estreitas, o drawer começa fora da viewport e o controller
`app-shell` aplica `translate-x-0`; em telas largas o breakpoint `desktop` o
mantém estático.

Os breakpoints `tablet` (768px) e `desktop` (1024px) vivem em
`tokens.css`. Assim, a mesma grade de 4, 8 e 12 colunas pode ser aplicada a
uma nova tela sem espalhar números de viewport em templates.

## O logotipo

A marca vive em `app/assets/images/logo.png` e aparece em dois lugares: a gaveta
do `AppShellComponent` e o cabeçalho da coluna de formulário da
`AuthLayoutComponent`. Nos dois, o nome acessível vem do `alt` — a mesma chave
`.brand` que antes era texto na tela —, porque trocar palavra por imagem sem
isso apagaria a marca para quem usa leitor de tela.

Três decisões que não se leem no arquivo:

- **A cor foi normalizada para `--clay-500` (#A8482C).** O arquivo entregue
  vinha em #BC522A, um desvio do modelo que gerou a arte em relação ao valor
  pedido. O logotipo é reconstruído como uma máscara de alfa recolorida, então
  a cor da marca continua tendo uma única fonte, que é o `tokens.css`.
- **O fundo virou transparente por alfa de luminância, e não por chave de
  cor.** `-transparent` sobre a borda antisserrilhada deixa halo claro, que só
  aparece quando alguém põe o logotipo sobre fundo escuro — tarde demais.
- **É PNG, e não SVG, porque não há tracer nesta máquina** (nem `potrace` nem
  `autotrace`). O custo é conhecido: trocar o matiz da marca no `tokens.css`
  **não** alcança este arquivo, e ele precisa ser reexportado à mão. É a única
  coisa no design system que não segue o token sozinha.

## Estados e semântica

`EmptyStateComponent` recebe o texto e o ícone do contexto. Isso mantém
separadas as situações “ainda não há dados”, “o filtro não encontrou” e “não
há permissão”: nenhuma delas precisa revelar a quantidade ou o nome de dados
ocultos.

`StatusBadgeComponent` recebe o valor do enum, nunca uma cor escolhida pela
tela. O namespace `project_statuses` é próprio porque `statuses` já descreve
os estados de pagamento; assim um novo estado não muda o significado de um
rótulo existente.

`ProgressBarComponent` usa a mesma barra para avanço físico e recursos. O
primeiro modo recebe um percentual; o segundo calcula a razão entre valor e
meta, sempre limitada a 0–100%. Uma meta ausente mostra a falta de meta e
mantém a barra em zero — um valor financeiro não deve parecer avanço só porque
não há divisor.

## Campos e tabela

`InputComponent` recebe um `FormBuilder`, então o Rails continua sendo a fonte
de `name`, `id` e valor. A mensagem de erro vence a dica no `aria-describedby`,
e o rótulo continua presente mesmo quando o texto visível é compacto.
`SearchFieldComponent` cria um formulário GET Turbo-native e mantém o link de
limpeza com a mesma moldura Turbo; ele não desliga a navegação acelerada.

`TableComponent` não tenta espremer muitas colunas no telefone. O desktop
recebe uma tabela real dentro de seu próprio `overflow-x-auto`; o mobile
recebe cartões `<dl>` com os mesmos cabeçalhos e valores. Com zero linhas o
componente delega a `EmptyStateComponent`, evitando uma tabela vazia sem
contexto.
