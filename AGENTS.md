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
| `bundle exec herb lint` | templates HTML+ERB, incluindo as regras customizadas |
| `bin/stimulus_lint` | controllers Stimulus |
| `bin/i18n-tasks health` | traduções faltando, sobrando ou não normalizadas |
| `bin/i18n_sidecar_lint` | estrutura dos sidecars de i18n de ViewComponent |
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

Quatro regras estão **dormentes** até o projeto ganhar as peças que elas
pressupõem, e passam sem ruído enquanto isso:

- `no-raw-button` e `icon-name-must-exist` esperam `app/components/` (ViewComponent)
  e `app/assets/icons/`.
- `bin/i18n_sidecar_lint` e as rotas de sidecar em `config/i18n-tasks.yml.erb`
  esperam `app/components/*_component/`.

Quando o primeiro componente chegar, elas passam a cobrar sozinhas.

## Hooks de git

`bundle exec lefthook install` (o `bin/setup` já faz). O `pre-commit` roda os
mesmos linters sobre os arquivos em stage, e o `herb format` re-adiciona ao
stage o que ele reformatar.
