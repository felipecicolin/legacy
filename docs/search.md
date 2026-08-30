# Busca — obra, base ou país na mesma caixa

> Regra curta no [`AGENTS.md`](../AGENTS.md). Aqui está o porquê.

O `SearchFieldComponent` diz *"Buscar obra, base ou país"*. Três tipos de
resultado numa caixa só, e é essa tela que **prova por que Base, Obra e País são
entidades separadas**: um mesmo termo casa os três, e cada um leva a um lugar
diferente. Ver [Campo](field.md).

## Três consultas, não uma `UNION`

Os três tipos têm colunas, políticas de visibilidade e telas diferentes.
Juntá-los em SQL obrigaria a projetar tudo numa forma comum — id, tipo, rótulo —
e a desfazer isso na view para renderizar cada grupo do seu jeito. **O que eles
compartilham é a pergunta, não a linha.**

Cada grupo pergunta ao **seu próprio** escopo de visibilidade, e é isso que faz
a regra seguinte funcionar sem ninguém lembrar dela.

## Buscar não pode virar oráculo

Uma obra confidencial **não aparece nem como "sem permissão"**. A resposta para
um termo que casa algo fora do alcance é **idêntica** à de um termo que não casa
nada — e o spec compara `[status, body]` literalmente, não "parecido".

Um resultado tarjado seria pior que nenhum: ele confirma que existe uma obra com
aquele nome, e a existência já é a informação que a política de sensibilidade
protege. É a mesma escolha do 404 em [Autorização](authorization.md).

Isso se estende ao **filtro de país**: ele oferece só os países que têm base
alcançável. Oferecer os 249 curados deixaria o alcance da pessoa visível pelo
que a lista *não* devolve, além de pedir que ela escolha entre 244 filtros que
não devolvem nada.

## `unaccent` na consulta, e por que não há índice

"sao paulo" tem de achar "São Paulo". Sem `unaccent` a busca vira comparação de
bytes, e quem digita rápido — que não acentua — conclui que o dado não existe. O
`unaccent()` é aplicado **dos dois lados**: o termo e a coluna. Só do lado da
coluna, "Vále" não acharia "Vale".

**Não há índice funcional, e a razão é a mesma que fez o código da obra virar
coluna gerada.** O caminho óbvio seria:

```sql
create function f_unaccent(text) returns text ... immutable ...;
create index ... on projects using gin (f_unaccent(lower(title)) gin_trgm_ops);
```

O `unaccent` é `STABLE` (depende do dicionário instalado) e o Postgres recusa
função não-imutável em índice, então o embrulho imutável é obrigatório. Mas o
**dumper Ruby não escreve função SQL no `db/schema.rb`**, e o banco de teste
nasce do schema: o índice referencia uma função que não existe, e o
`db:schema:load` morre. Foi **medido**, não suposto — a migration chegou a
existir nessa forma.

O custo é varredura sequencial. Para o volume da demonstração não se nota, e
escolher o índice certo com `EXPLAIN` sobre o seed é o trabalho de #49.

> O nome do país **não é coluna**: ele vive em `countries.<iso>` no locale. Por
> isso o casamento de país acontece em Ruby, sobre a lista já restrita aos
> países com base alcançável.

## O estado inteiro na query string

Filtro que não sobrevive ao compartilhamento do link não serve para trabalho em
equipe. Termo, filtros e apresentação viajam na URL, e recarregar reproduz tudo.

**Valor inválido é ignorado, não recusado.** Um `?status=demolida` colado errado
devolve a lista sem aquele filtro — não uma exceção, e não uma lista vazia que
se lê como "não existe nada". A URL é escrita por gente.

A apresentação (tabela ou grade) também persiste **num cookie**: a escolha é de
leitura, não de conteúdo — os dois modos mostram o mesmo conjunto. Cookie e não
sessão porque ela sobrevive ao logout e não vale nada se vazar.

## A espera ao digitar

`search_form_controller.js` submete o formulário sozinho, com 300ms de espera.
Sem ela, cada tecla vira um request e a lista pisca.

O `clearTimeout` no `disconnect()` não é formalidade: sem ele um Turbo Visit que
troque a página deixa o timer vivo, e ele submete um formulário que não está
mais no documento. O `bin/stimulus_lint` cobra isso.

## O estado vazio tem três casos, e um deles não se diz

| Situação | O que a tela diz |
| --- | --- |
| Nunca houve dado | "Ainda não há o que buscar" |
| Filtro não achou | "Nada corresponde a essa busca" |
| Sem permissão | **o mesmo que "filtro não achou"** |

O terceiro nunca é dito em voz alta — é exatamente a regra do oráculo, aplicada
ao texto.

## O `SelectComponent` que entrou junto

A barra de filtro precisava de campo de escolha, e a resposta a "falta
componente" é **estender a biblioteca**, não escrever marcação solta na view.

Ele não é o `InputComponent`: aquele recebe o form builder de um **objeto** e lê
`errors` e `human_attribute_name` dele. Filtro de busca não tem objeto — o
formulário é um `form_with url:` —, e passar um objeto falso só para satisfazer
a API seria inventar um registro que não existe.

O `<select>` vive **dentro** do `<label>`: a associação fica implícita e não
depende de alguém casar `for` com `id`.

## O que falta desta issue

**Paginação.** Os grupos vêm inteiros. Com o volume do seed isso não incomoda, e
paginar dentro de um Turbo Frame que já carrega três grupos pede uma decisão de
desenho — paginar cada grupo ou a lista toda — que vale tomar com a tela de
listagem (#50, #52) na mão, e não antes.

**"Ver todos" por grupo.** Ele levaria a `mission_bases#index` e
`projects#index`, que ainda são placeholders de outras issues. Um link para uma
tela vazia é pior que nenhum link.
