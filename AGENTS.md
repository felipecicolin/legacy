# AGENTS.md

Guia curto do ferramental deste repositório. Vale para pessoas e para agentes.

## A regra que explica todas as outras

**Não existe supressão.** Nem `.rubocop_todo.yml`, nem `.stimulus_lint_todo.yml`,
nem `# rubocop:disable`, nem `# :reek:`, nem `exclude:` novo em config de linter.

O projeto nasceu com zero ofensas e a única forma sustentável de continuar assim
é nunca abrir a porta da dívida: um arquivo de todo transforma "conserte isto"
em "catalogue isto", e a partir daí o número só cresce. Quando um linter aponta
algo, a resposta é refatorar:

- Método/classe longa → extraia um objeto de serviço ou separe responsabilidades.
- Lista de parâmetros longa → introduza um value object ou kwargs.
- Linha longa → encurte nomes, quebre a linha, mova dados para uma constante.
- String hardcoded na view → passe por `t("…")`.

O `bin/directive_guard` cobra isso mecanicamente: ele tranca a contagem de
diretivas de supressão por arquivo em `.directive_allowlist`, e qualquer
diretiva nova — inclusive um `Exclude:` novo dentro de `.rubocop.yml` ou
`.reek.yml` — reprova a CI. Se, depois de conversar com quem mantém o
repositório, uma exceção for mesmo necessária, `bin/directive_guard --update`
grava a exceção de forma explícita e revisável. Nunca rode isso para "passar a
CI".

## Rodando a pipeline

```bash
bin/ci
```

Roda localmente o mesmo conjunto que o `.github/workflows/ci.yml` roda no PR:
scanners de segurança, linters, i18n, guard de diretivas, checagens de banco,
specs em paralelo e o gate de cobertura.

Passos avulsos:

| Comando | O que cobra |
| --- | --- |
| `bin/rubocop --parallel` | estilo Ruby (rails/performance/rspec/factory_bot/thread_safety/view_component/i18n) |
| `bundle exec reek app/ lib/` | code smells |
| `bin/herb_lint` | templates HTML+ERB, incluindo as regras customizadas |
| `bin/stimulus_lint` | controllers Stimulus |
| `bin/i18n-tasks health` | traduções faltando, sobrando ou não normalizadas |
| `bin/i18n_sidecar_lint` | estrutura dos sidecars de i18n de ViewComponent |
| `bin/components_registry --check` | `registry.json` e `public/llms.txt` em dia |
| `bin/directive_guard` | nenhuma supressão nova |
| `bin/brakeman` / `bin/bundler-audit` / `bin/importmap audit` | segurança |
| `bundle exec database_consistency` | FKs, índices e NOT NULL versus os modelos |
| `bundle exec rspec` | specs |

## Cobertura: 100/100

`script/verify_coverage.rb` cobra 100% de linha **e** de branch. Não é uma meta
aspiracional: é o gate. Código novo chega com spec, ou não chega.

## Regras customizadas do herb

Em `.herb/rules/*.mjs`, ligadas em `.herb.yml`. Elas cobram invariantes de
design system que o catálogo embutido do herb não cobre:

| Regra | Proíbe |
| --- | --- |
| `no-hardcoded-string` | texto visível fora de `t("…")` |
| `no-inline-event-handler` | `onclick=` e afins — use Stimulus com `data-action` |
| `no-turbo-disable` | `data-turbo="false"` |
| `no-hex-code` | `#fff`, `rgb()`, `hsl()` em atributos |
| `no-arbitrary-tailwind` | valores arbitrários: `h-[200px]`, `bg-[#fff]` |
| `no-color-scale-utility` | a escala primitiva: `bg-blue-500`, `text-gray-700` |
| `no-raw-button` | `<button>` cru fora de `app/components/` |
| `no-inline-svg` | `<svg>` inline — use `IconComponent` |
| `icon-name-must-exist` | nome de ícone que não existe em `app/assets/icons/` |

As três de cor mandam usar os tokens semânticos de
`app/assets/tailwind/tokens.css` (`bg-primary`, `text-muted-foreground`,
`border-destructive`, …). A paleta lá é um ponto de partida neutro — troque os
matizes pela identidade do produto; a estrutura em camadas
(primitivas em `:root` → semânticas em `@theme inline`) é o que faz as regras
serem cobráveis.

Todas estão ativas. `no-raw-button` tem para onde apontar (`ButtonComponent`)
e `icon-name-must-exist` lê o catálogo real em `app/assets/images/icons/` — o
mesmo diretório que `IconComponent::ICONS_DIR`, para linter e runtime nunca
discordarem.

**Rode `bin/herb_lint`, não `bundle exec herb lint`.** Quando um arquivo de
regra não carrega — um import que a versão do `@herb-tools/linter` não exporta
mais, um erro de sintaxe — o herb imprime o erro, segue com as regras restantes
e **sai com status 0**. O resultado é um "✓ All files are clean" com parte do
enforcement desligada. O `bin/herb_lint` compara a contagem de regras
carregadas com os arquivos em `.herb/rules/` e reprova se faltar alguma.

## ViewComponent

Todo componente herda de `ApplicationComponent`, que dá três coisas:
`class_merge` (compõe classes Tailwind resolvendo conflitos, a última vence),
`validate_inclusion!` (falha no construtor, não na renderização) e
`stimulus_controller` (o identificador do controller sidecar).

Convenções que a CI cobra:

- **Todo componente precisa de preview.** `ViewComponent/MissingPreview` está
  ligado. Previews vivem em `spec/components/previews/` e são navegáveis em
  `/rails/view_components` em desenvolvimento — os previews nativos do
  ViewComponent, sem explorador de terceiros.
- **Teste a saída renderizada**, não os métodos. `ViewComponent/TestRenderedOutput`
  cobra `render_inline`/`render_preview` nos specs de componentes concretos.
- **Cobertura 100%** vale para `app/components/` como para o resto.
- **`bin/components_registry`** regenera `app/components/registry.json` e
  `public/llms.txt` a partir das classes. A CI reprova se estiverem
  desatualizados — um llms.txt que descreve uma API que não existe mais é pior
  do que nenhum. Nunca edite os dois à mão.
- **i18n de componente vai em sidecar**, `app/components/<nome>/<nome>.<locale>.yml`,
  plano (sem envelopar sob o nome do componente — o ViewComponent já escopa).
  O `bin/i18n_sidecar_lint` cobra isso.

Dois cops do `rubocop-view_component` estão ajustados em `.rubocop.yml`, com o
motivo escrito lá: `PreferComposition` desligado (acusa todo componente que
herda de `ApplicationComponent`, ou seja, todos) e `TestRenderedOutput`
dispensado no spec da base abstrata, que não renderiza nada.

## Hooks de git

`bundle exec lefthook install` (o `bin/setup` já faz). O `pre-commit` roda os
mesmos linters sobre os arquivos em stage, e o `herb format` re-adiciona ao
stage o que ele reformatar.
