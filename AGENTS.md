# Legacy — AGENTS.md

Aplicação Rails 8.1 em início de vida. Não há domínio ainda: o que existe é o
esqueleto do generator mais a pipeline de qualidade completa, ligada desde o
primeiro commit. Este arquivo descreve as regras que valem para qualquer código
que entrar daqui para frente. Vale para pessoas e para agentes.

**Stack:** Ruby 4.0.2 · Rails 8.1 · PostgreSQL 18 · Propshaft · importmap ·
Turbo + Stimulus · Tailwind v4 · ViewComponent · Solid Cache/Queue/Cable ·
RSpec. Locale `pt-BR`, timezone Brasília.

---

## A regra que explica todas as outras

**Não existe supressão.** Nem `.rubocop_todo.yml`, nem
`.stimulus_lint_todo.yml`, nem `# rubocop:disable`, nem `# :reek:`, nem
`Exclude:` novo em config de linter.

O projeto nasceu com zero ofensas, e a única forma sustentável de continuar
assim é nunca abrir a porta da dívida: um arquivo de todo troca "conserte isto"
por "catalogue isto", e a partir daí o número só cresce. Quando um linter
aponta algo, a resposta é refatorar:

| O que o linter diz | O que fazer |
| --- | --- |
| Método/classe longa | Extrair um objeto de serviço, ou separar responsabilidades |
| Lista de parâmetros longa | Introduzir um value object (`Data.define`) ou kwargs |
| Linha longa | Encurtar nomes, quebrar a linha, mover dados para constante |
| String hardcoded na view | Passar por `t("…")` |
| `FeatureEnvy` / `UtilityFunction` | Mover o método para perto dos dados |

O `bin/directive_guard` cobra isso mecanicamente. Ele tranca a contagem de
diretivas por arquivo em `.directive_allowlist` — e uma diretiva nova, inclusive
um `Exclude:` novo dentro de `.rubocop.yml` ou `.reek.yml`, reprova a CI. Ele
também **reprova se qualquer arquivo de todo aparecer**, mesmo vazio.

Se, depois de conversar com quem mantém o repositório, uma exceção for mesmo
necessária, `bin/directive_guard --update` grava a exceção de forma explícita e
revisável, e o motivo vai escrito no arquivo de config, ao lado da entrada.
Nunca rode `--update` para "passar a CI".

Hoje o allowlist tem 4 chaves, e nenhuma delas é uma supressão de ofensa: são
travas de contagem sobre as exceções estruturais de config.

---

## Rodando a pipeline

```bash
bin/ci
```

Roda localmente o mesmo conjunto que o `.github/workflows/ci.yml` roda no PR.
São ~17s. Rode antes de abrir o PR — descobrir um erro de estilo na CI é caro e
lento comparado a descobrir aqui.

| Comando | O que cobra |
| --- | --- |
| `bin/rubocop --parallel` | Estilo Ruby (rails, performance, rspec, factory_bot, rspec_rails, thread_safety, view_component, i18n, capybara) |
| `bundle exec reek app/ lib/` | Code smells |
| `bin/herb_lint` | Templates HTML+ERB, incluindo as regras customizadas |
| `bin/stimulus_lint` | Controllers Stimulus |
| `bin/i18n-tasks health` | Traduções faltando, sobrando ou não normalizadas |
| `bin/i18n_sidecar_lint` | Estrutura dos sidecars de i18n de componente |
| `bin/components_registry --check` | `registry.json` e `public/llms.txt` em dia |
| `bin/directive_guard` | Nenhuma supressão nova |
| `bin/brakeman` | Vulnerabilidades no código |
| `bin/bundler-audit` / `bin/importmap audit` | Vulnerabilidades em dependências |
| `bundle exec database_consistency` | FKs, índices e NOT NULL versus os modelos |
| `bundle exec rspec` | Specs |

Hooks de git: `bundle exec lefthook install` (o `bin/setup` já faz). O
`pre-commit` roda os mesmos linters sobre os arquivos em stage.

---

## Limites de tamanho

Estes números estão em `.rubocop.yml`, `.reek.yml` e `bin/stimulus_lint`. Não
são sugestão — são o que a CI cobra.

| | Limite |
| --- | --- |
| Método Ruby | 7 linhas (`Metrics/MethodLength`, `TooManyStatements`) |
| Complexidade ciclomática | 6 (Ruby) · 5 (Stimulus) |
| AbcSize | 15 |
| Parâmetros | 4 (kwargs contam) |
| Classe / módulo | 120 linhas |
| Linha | 120 caracteres |
| Método Stimulus | 7 linhas |
| Chamadas repetidas de um mesmo método | 2 (`DuplicateMethodCall`) |

Se um método não cabe em 7 linhas, ele está fazendo mais de uma coisa. Extraia.

---

## Cobertura: 100/100

`script/verify_coverage.rb` cobra 100% de linha **e** de branch. Não é meta
aspiracional, é o gate: código novo chega com spec, ou não chega.

Isso é possível porque começou em 100% e nunca caiu. Recuperar cobertura depois
que ela cai é um projeto; mantê-la é um hábito.

---

## Testes

- **Correção de bug: escreva primeiro o teste que falha.** Ele tem de falhar
  antes do fix e passar depois. Um teste escrito depois do fix prova que o
  código faz o que faz, não que o bug foi consertado.
- Teste comportamento observável, não implementação. Em componentes isso é
  regra cobrada pelo linter: `ViewComponent/TestRenderedOutput` exige
  `render_inline`/`render_preview` em vez de chamar métodos direto.
- `let_it_be`/`before_all` (test-prof) para setup caro compartilhado.
- A suíte roda em paralelo (`parallel_rspec -n 2`), com um banco por processo
  (`legacy_test`, `legacy_test2`). Spec que depende de estado global entre
  exemplos quebra de forma intermitente — não faça.
- Nada de rede: o `webmock` bloqueia conexão externa.

---

## i18n — todo texto visível passa por `t()`

Locale base e único hoje: `pt-BR`. Três linters cobram isso de ângulos
diferentes:

- `I18n/RailsI18n/DecorateString` (rubocop) — string literal em código.
- `no-hardcoded-string` (herb) — texto solto em template.
- `bin/i18n-tasks health` — chave faltando, chave órfã, arquivo não normalizado.

Depois de mexer em locale, rode `bin/i18n-tasks normalize`.

Chave resolvida dinamicamente (`t("status.#{value}")`) é invisível para o
scanner e aparece como órfã. Marque com um comentário
`# i18n-tasks-use t('status.*')` ao lado da chamada — nunca com uma entrada
genérica em `ignore_unused`. O `directive_guard` rastreia esses comentários,
para a lista não crescer em silêncio.

---

## Design system — só tokens semânticos

As cores, raios e superfícies vivem em `app/assets/tailwind/tokens.css`, em duas
camadas: primitivas em `:root` (variáveis CSS puras) e apelidos semânticos em
`@theme inline`, que é o que gera as utilities.

**Views e componentes usam só as semânticas** — `bg-primary`,
`text-muted-foreground`, `border-destructive`, `rounded-lg`. Nunca a escala
primitiva (`bg-blue-500`), nunca valor arbitrário (`h-[200px]`), nunca hex.
Três regras do herb cobram isso, e elas só são cobráveis porque existe o nome
semântico para usar no lugar.

A paleta atual é um ponto de partida neutro. Trocar os matizes pela identidade
do produto é editar `tokens.css` e nada mais — nenhuma view muda.

Se falta um token, **adicione o token**, não uma exceção. E mantenha os
vocabulários separados: `success`/`warning`/`destructive` dizem *estado*. Cor
categórica (dizer *qual* coisa um item é) merece um vocabulário próprio, senão
o leitor precisa desambiguar "vermelho = erro" de "vermelho = categoria X".

---

## Templates HTML+ERB

O `bin/herb_lint` roda sobre o repositório inteiro. Além do catálogo embutido do
herb, nove regras customizadas em `.herb/rules/*.mjs`:

| Regra | Proíbe |
| --- | --- |
| `no-hardcoded-string` | Texto visível fora de `t("…")` |
| `no-inline-event-handler` | `onclick=` e afins — use Stimulus com `data-action` |
| `no-turbo-disable` | `data-turbo="false"` |
| `no-hex-code` | `#fff`, `rgb()`, `hsl()` em atributos |
| `no-arbitrary-tailwind` | Valores arbitrários: `h-[200px]`, `bg-[#fff]` |
| `no-color-scale-utility` | Escala primitiva: `bg-blue-500`, `text-gray-700` |
| `no-raw-button` | `<button>` cru fora de `app/components/` |
| `no-inline-svg` | `<svg>` inline — use `IconComponent` |
| `icon-name-must-exist` | Nome de ícone que não existe no catálogo |

`icon-name-must-exist` é a principal defesa contra alucinação de UI: ela lê
`app/assets/images/icons/*.svg` e reprova qualquer
`IconComponent.new(name: "…")` que aponte para arquivo inexistente.

---

## ViewComponent

Todo componente herda de `ApplicationComponent`, que oferece:

- `class_merge(*classes)` — compõe classes do Tailwind resolvendo conflitos; a
  última vence. Sem isso, quem decide entre `px-4` e `px-6` é a ordem no CSS
  compilado, não a intenção de quem chamou.
- `validate_inclusion!(nome, valor, permitidos)` — falha no construtor, não na
  renderização. Um componente com variante inválida tem de morrer cedo.
- `stimulus_controller` — o identificador do controller do componente.

Convenções que a CI cobra:

- **Todo componente precisa de preview**, em `spec/components/previews/`.
  Navegue em `/rails/view_components` no ambiente de desenvolvimento (previews
  nativos do ViewComponent — este projeto não usa Lookbook).
- **Componentes concretos são testados pela saída renderizada.**
- **Cobertura 100%** vale igual para `app/components/`.
- **`bin/components_registry`** regenera `app/components/registry.json` e
  `public/llms.txt` a partir das classes. Nunca edite os dois à mão; a CI
  reprova se ficarem desatualizados. Um `llms.txt` que descreve uma API que não
  existe mais é pior do que nenhum.
- **i18n de componente vai em sidecar**, `app/components/<nome>/<nome>.<locale>.yml`,
  **plano** — sem envelopar sob o nome do componente, porque o ViewComponent já
  escopa. O `bin/i18n_sidecar_lint` cobra.

Dois cops do `rubocop-view_component` estão ajustados, com o motivo escrito em
`.rubocop.yml`: `PreferComposition` desligado (acusa todo componente que herda
de `ApplicationComponent`, ou seja, todos) e `TestRenderedOutput` dispensado no
spec da base abstrata, que não renderiza nada.

### Adicionando um componente

1. `app/components/<nome>_component.rb`, herdando de `ApplicationComponent`.
2. Template em `app/components/<nome>_component/<nome>_component.html.erb`.
3. Preview em `spec/components/previews/<nome>_component_preview.rb`.
4. Spec em `spec/components/<nome>_component_spec.rb`, cobrindo 100% e usando
   `render_inline`.
5. Se tiver texto: sidecar `<nome>_component.pt-BR.yml`, plano.
6. Se tiver JS: `app/javascript/controllers/<nome>_component_controller.js`.
7. `bin/components_registry` e commite o resultado.
8. `bin/ci`.

---

## Stimulus

Controllers em `app/javascript/controllers/`, incluindo os de componente. Não
são sidecar dentro de `app/components/` — ver "Armadilhas" abaixo.

O `bin/stimulus_lint` é Ruby puro (nenhum Node envolvido) e cobra 18 regras.
As que mais aparecem:

- Sem `console.log`; sem `var`; `===` em vez de `==`.
- Target, value, class ou outlet declarado tem de ser usado.
- `fooTargetConnected` / `fooValueChanged` precisam do identificador declarado.
- Sem `addEventListener` cru — use `data-action`.
- Sem `innerHTML =` — é XSS esperando acontecer.
- Sem efeito colateral no topo do arquivo.
- Todo `setInterval`/`setTimeout` precisa do `clear` correspondente no
  `disconnect()`.
- Imports só de `@hotwired/`, `controllers/`, `./` ou `../` — este projeto não
  tem build de JS, então pacote npm não carregaria mesmo.

---

## Turbo

Turbo é obrigatório. `data-turbo="false"` é proibido pelo linter, e a intenção é
literal: se um comportamento briga com o Turbo, conserte a causa — um Turbo
Frame, um Turbo Stream ou um controller Stimulus. Nunca desligue o Turbo.

---

## Banco de dados

- `bundle exec database_consistency` cobra FK sem índice, `NOT NULL` faltando,
  validação que o schema não sustenta. Ele roda na CI.
- `db/schema.rb` é commitado, e a CI reprova se estiver fora de sincronia com as
  migrations.
- Bancos de teste são um por processo do `parallel_tests`, via sufixo
  `TEST_ENV_NUMBER` no `database.yml`.
- Na CI, o segundo banco sai de `CREATE DATABASE … TEMPLATE`, e não de uma
  segunda carga de schema: é o Postgres clonando, em vez do Rails subindo de
  novo.

---

## Armadilhas conhecidas

Coisas que já custaram caro aqui. Todas são reais e verificadas, não hipóteses.

**Nunca ponha `app/components` em `config.assets.paths`.** É a receita corrente
para controllers Stimulus sidecar, e o preço é vazar código-fonte: o Propshaft
trata todo arquivo sob um asset path como asset, sem filtro de extensão, então o
`assets:precompile` copia `app/components/*.rb` para `public/assets/` e os lista
no `.manifest.json`, que é público. Por isso os controllers de componente vivem
em `app/javascript/controllers/`.

**Use `bin/herb_lint`, não `bundle exec herb lint`.** Quando um arquivo de regra
customizada não carrega — um import que a versão do `@herb-tools/linter` não
exporta mais, um erro de sintaxe — o herb imprime o erro, segue com as regras
restantes e **sai com status 0**. O resultado é um "✓ All files are clean" com
parte do enforcement desligada. O `bin/herb_lint` compara as regras carregadas
com os arquivos em `.herb/rules/` e reprova se faltar alguma.

**No ViewComponent 4 a config de preview é `previews.paths`**, não
`preview_paths`. Atribuir à chave antiga não levanta erro: só não faz nada, e a
listagem de previews abre vazia.

**Os cops de ViewComponent exigem `AllCops/UseProjectIndex: true`.** Sem isso
eles levantam exceção em todo arquivo — e o rubocop imprime o erro mas ainda sai
com status 0.

O padrão nos quatro casos é o mesmo: **ferramenta que falha em silêncio e sai
zero**. Quando ligar um linter novo, confirme que ele reprova algo que deveria
reprovar antes de confiar nele.

---

## Documentação de biblioteca

Antes de escrever código que use uma gem, uma API do Rails ou um pacote JS,
busque a documentação atual (Context7, quando disponível). Assinatura de método
e nome de opção de config mudam entre versões, e as três armadilhas de
"ferramenta que falha em silêncio" acima nasceram exatamente disso: uma API que
mudou e um call site que continuou compilando.

---

## Convenções de escrita

- Código, nomes de método e mensagens de commit: **inglês**.
- Comentários, documentação e texto de UI: **português**.
- Comentário explica **por quê**, não o quê. Se o comentário parafraseia o
  código, apague o comentário; se o código precisa de paráfrase, renomeie o
  código.
- Toda exceção configurada num linter carrega o motivo escrito ao lado dela.
