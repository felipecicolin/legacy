# Legacy — AGENTS.md

Aplicação Rails 8.1 em início de vida. Não há domínio ainda: o que existe é o
esqueleto do generator mais a pipeline de qualidade completa, ligada desde o
primeiro commit. Este arquivo descreve as regras que valem para qualquer código
que entrar daqui para frente. Vale para pessoas e para agentes.

**Stack:** Ruby 4.0.2 · Rails 8.1 · PostgreSQL 18 · Propshaft · importmap ·
Turbo + Stimulus · Tailwind v4 · ViewComponent · Solid Cache/Queue/Cable ·
RSpec. Locale `pt-BR`, timezone Brasília.

**Requisitos de sistema:** PostgreSQL, **libvips** (`brew install vips` /
`apt install libvips`) e **Google Chrome**. A libvips não é opcional: o
processador de variantes padrão do Active Storage é o vips, e sem a biblioteca
a aplicação não sobe — nem para rodar os specs. O Dockerfile já a instala. O
Chrome é para os specs de sistema (`spec/system/`), que rodam headless; o
driver o Selenium Manager resolve sozinho.

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
- **Spec de sistema roda em Chrome headless e exige o CSS compilado.** O
  `bin/ci` e a CI rodam `bin/rails tailwindcss:build` antes da suíte; rodando
  `rspec` na mão depois de mexer em `app/assets/tailwind/`, rode o build antes,
  senão o spec mede o CSS antigo.

---

## i18n — todo texto visível passa por `t()`

> Formatos pt-BR, convenção de nomes de chave e rótulo de enum:
> [`docs/i18n.md`](docs/i18n.md).

Locale base e único hoje: `pt-BR`. Três linters cobram isso de ângulos
diferentes:

- `I18n/RailsI18n/DecorateString` (rubocop) — string literal em código.
- `no-hardcoded-string` (herb) — texto solto em template.
- `bin/i18n-tasks health` — chave faltando, chave órfã, arquivo não normalizado.

Depois de mexer em locale, rode `bin/i18n-tasks normalize`.

Chave resolvida dinamicamente (`I18n.t(status, scope: :statuses)`) é invisível
para o scanner e apareceria como órfã. **Escreva com `scope:`, nunca com
interpolação** — o cop `DecorateStringFormattingUsingInterpolation` reprova
`t("statuses.#{value}")`.

O comentário `# i18n-tasks-use` **não funciona neste repositório**: medido, o
scanner desta versão não o lê em arquivo `.rb`. O vocabulário de enum vai em
`ignore_unused` no `config/i18n-tasks.yml.erb`, com o motivo ao lado — e o que
torna isso seguro é `spec/models/enum_translation_audit_spec.rb`, que percorre
os enums de todos os modelos e reprova qualquer valor sem rótulo. A checagem de
"não usada" foi trocada por uma mais forte, não removida. Detalhes em
[`docs/i18n.md`](docs/i18n.md).

A `rails-i18n` cobre o miolo do framework (validação, mês, moeda, "3 meses");
os formatos que ela não acerta ficam em `config/locales/rails.pt-BR.yml`
e são cobrados por `spec/i18n_spec.rb`, porque linter nenhum lê texto de gem.
Nome de campo vai em `activerecord.attributes.*`; **valor de enum nunca vai cru
para a tela** — o rótulo é `<enum no plural>.<valor>` no topo do locale, e
`spec/models/enum_translation_audit_spec.rb` reprova quem esquecer.

---

## Design system — só tokens semânticos

> Vocabulário completo, receitas e armadilhas:
> [`docs/design-system/tokens.md`](docs/design-system/tokens.md).

As cores, raios e superfícies vivem em `app/assets/tailwind/tokens.css`, em duas
camadas: primitivas em `:root` (variáveis CSS puras, que nomeiam o **matiz**) e
apelidos semânticos em `@theme inline` (que nomeiam o **papel**), e é o
`@theme inline` que gera as utilities.

**Views e componentes usam só as semânticas** — `bg-primary`,
`text-muted-foreground`, `border-destructive`, `rounded-lg`. Nunca a escala
primitiva (`bg-blue-500`), nunca valor arbitrário (`h-[200px]`), nunca hex.
Três regras do herb cobram isso, e elas só são cobráveis porque existe o nome
semântico para usar no lugar.

A paleta atual é um ponto de partida neutro. Trocar os matizes pela identidade
do produto é editar `tokens.css` e nada mais — nenhuma view muda.

Proporção também é token — `aspect-wide`, `aspect-photo`, `aspect-tile` —, e a
`ImageFrameComponent` a reserva antes de a imagem existir; quem cobra é
`spec/system/image_frame_spec.rb`. Ver
[`docs/design-system/image-frame.md`](docs/design-system/image-frame.md).

Se falta um token, **adicione o token**, não uma exceção. E mantenha os
vocabulários separados: `success`/`warning`/`destructive` dizem *estado*;
`category-1`…`category-4` dizem *qual coisa* um item é. Sem essa separação o
leitor precisa desambiguar "vermelho = erro" de "vermelho = categoria X".

`spec/system/design_tokens_spec.rb` é quem sustenta tudo isso: ele pergunta ao
navegador que cor cada utility resolveu e reprova o que sair transparente —
token renomeado ou removido não gera erro em lugar nenhum, só uma classe que o
Tailwind deixa de emitir. O mesmo spec recalcula o contraste WCAG de cada par
`X`/`X-foreground` a partir da cor resolvida, então **token novo entra com par
de contraste que passa em AA** (4.5:1 para texto), e a tabela no fim do
`tokens.css` não tem como envelhecer. Todo token declarado precisa aparecer na
página de fumaça em `spec/components/previews/design_tokens_preview/` — com a
utility escrita literalmente, porque o Tailwind v4 gera classe varrendo texto e
um nome montado em laço não produz nada.

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

## Autenticação

> Para quem ela é, as decisões e as armadilhas:
> [`docs/authentication.md`](docs/authentication.md).

Autenticação nativa do Rails 8.1, sem gem. Três regras valem daqui para frente:

- **Fechado por padrão.** O concern `Authentication` põe
  `before_action :require_authentication` em todo controller. Abrir uma action é
  explícito, com `allow_unauthenticated_access` — e a decisão vai comentada.
- **`User` guarda credencial e sessão, nada de pessoa.** Nome, país e foto são
  do `Profile` (#18); papel é contexto (#20, #21, #31), nunca coluna em `users`.
- **Login e recuperação não dizem se a conta existe.** Mesma mensagem, mesma
  rota, mesmo status para senha errada e e-mail inexistente. Use
  `User.authenticate_by` — é ele que iguala também o tempo de resposta.

## Identidade

> Por que uma pessoa e muitos papéis, e as armadilhas:
> [`docs/identity.md`](docs/identity.md).

A pessoa é o `Profile`. Três regras:

- **Uma pessoa, muitos papéis.** Nenhuma tabela por papel — papel é contexto
  (#20, #21, #31), e "visão do investidor" é projeção autorizada sobre os mesmos
  dados.
- **`legal_name` nunca sai sozinho.** `to_s` devolve `display_name`, e
  `Profile#serializable_hash` remove `legal_name` depois do `super` — não como
  `except:` padrão, que o `only:` do Active Model atropelaria.
- **`display_name` é armazenado, não derivado.** Corrigir o nome legal não pode
  reescrever o histórico já exibido.

## Organizações e vínculos

> Os nomes dos enums, as três camadas da regra do owner e o que `delete_all`
> não alcança: [`docs/organizations.md`](docs/organizations.md).

A instituição é a `Organization`; o vínculo com uma pessoa é o `Membership`.
Quatro regras:

- **Papel é contexto.** Ele mora no `Membership`, nunca numa coluna em
  `profiles`.
- **Organização nasce `pending`, e quem lista é `Organization.visible`.** Não
  aprovada não aparece em busca e não recebe doação.
- **`slug` nasce do nome e é imutável** (`attr_readonly`) — URL pública que
  quebra é dívida permanente.
- **Uma organização não perde o `owner` que tem.** Remover, rebaixar *ou mover
  para outra organização* o último reprova; a cascata da própria organização é
  a única isenta.

E uma regra de vocabulário que vale para qualquer enum novo: **se o namespace
de rótulo (`<enum no plural>.*`) já existe com outro sentido, o enum ganha nome
próprio** — foi por isso que as colunas aqui são `organization_kind` e
`organization_status`, e não `kind` e `status`.

## Pagamentos

> A fronteira, o simulador determinístico e a marca de dado simulado:
> [`docs/payments.md`](docs/payments.md).

Demonstração, sem integração financeira: nenhum gateway, nenhuma chave, nenhum
webhook. Quatro regras valem daqui para frente:

- **Ninguém fala com o provedor.** Modelo, controller, view e componente
  chamam `Payments::Gateway`; o provedor concreto é resolvido uma vez em
  `config.x.payment_provider`. Um spec de fronteira reprova o nome
  `SimulatedProvider` em `app/models`, `app/controllers`, `app/views` e
  `app/components`.
- **Nenhum dado de instrumento de pagamento em coluna nenhuma.** Sem número,
  validade, CVV, titular ou IBAN — um spec percorre o schema inteiro e reprova.
- **Dinheiro é `bigint` de centavos mais coluna `currency`.** Nunca `float`. O
  `Payments::Request` recusa o que não for `Integer` positivo, na construção:
  pedido inválido morre antes do provedor agir, não depois.
- **Todo lançamento nasce com `simulated`**, e a marca é `attr_readonly`:
  promover simulado a real levanta `ReadonlyAttributeError`. `update_all` e SQL
  cru escapam — o alcance exato e por que não há trigger estão em
  [`docs/payments.md`](docs/payments.md). Toda tela que mostra valor traz a
  marca visível — o `SimulatedDataBannerComponent` está no layout justamente
  para nenhuma precisar lembrar.

## Visibilidade

> Os três níveis, o que não se persiste e a auditoria:
> [`docs/visibility.md`](docs/visibility.md).

O concern `Sensitive` dá a todo registro de obra um `sensitivity_level`
(`public` · `restricted` · `confidential`). Seis regras valem daqui para
frente:

- **Obra nasce `restricted`.** Inclusive na criação: `create!` com nível menos
  restritivo que o default reprova, do mesmo jeito que um `update` reprovaria.
- **Registro `confidential` não guarda coordenada nem endereço.** Não é filtro
  de exibição — é o que se persiste. Gravar reprova na validação, levanta
  `Sensitive::PreciseLocationForbidden` com validação pulada e reprova na CHECK
  constraint quando o caminho pula callback (`update_column`, `insert_all`).
- **Migration de modelo com o concern leva a constraint e o `null: false`.**
  `t.check_constraint Sensitive::PRECISE_LOCATION_CHECK` mais
  `sensitivity_level` NOT NULL com o default do enum — sem os dois, o concern
  protege menos do que parece. A receita está em
  [`docs/visibility.md`](docs/visibility.md).
- **Afrouxar restrição só por `promote_visibility!`**, com autor e
  justificativa. `update` direto reprova na validação e
  `update_attribute`/`save(validate: false)` levantam
  `Sensitive::UnauditedDisclosure`. Restringir mais não pede cerimônia.
- **Linha de `sensitivity_changes` não se edita.** Qualquer `update` levanta
  `SensitivityChange::Immutable`: reescrever a auditoria é pior que apagá-la.
- **Consulta de visibilidade sai de `visible_to` / `hidden_from`**, que recebem
  um `Visibility::Context` e devolvem relação. Nunca escreva um segundo caminho
  de SQL que decida visibilidade — é ele que vai divergir.

## Vocabulário curado — países e habilidades

> Por que YAML, a curadoria pendente e as armadilhas:
> [`docs/vocabulary.md`](docs/vocabulary.md).

A lista de países (ISO 3166-1 inteiro) e a taxonomia de habilidades vivem em
`db/vocabulary/*.yml`. Cinco regras:

- **O YAML é a fonte; o seed lê, não redigita.** `db/seeds.rb` carrega por
  `Country.load_vocabulary!`, idempotente e casando pelo `iso_code` — a
  curadoria editada depois alcança a linha que já existe.
- **Chave em inglês no YAML, rótulo em português no locale**
  (`config/locales/vocabulary/pt-BR.yml`). Nome de país **não é coluna**:
  `Country#name` resolve `countries.<iso_code>`.
- **`high_risk` é decisão editorial da equipe, e hoje está vazia.** Não se
  infere de índice de terceiro. Marcar um país é editar a linha dele, com dono
  e data registrados na issue.
- **O gancho só aperta.** `high_risk` empurra `default_sensitivity` para
  `confidential`; desmarcar não devolve o país ao default, e marcar **não**
  alcança obra já gravada — mudança de política é promoção auditada.
- **Chave de vocabulário sem rótulo (e rótulo sem chave) reprova** em
  `spec/models/vocabulary/catalog_spec.rb`. É ele que sustenta a entrada
  `{countries,skill_categories,skills}.*` no `ignore_unused` do i18n-tasks.

## Action Text

> As decisões, as medições e as armadilhas:
> [`docs/action-text.md`](docs/action-text.md).

Texto rico é `has_rich_text`, com Trix e Active Storage por trás. Quatro regras:

- **Sem anexo embutido.** O upload do Trix não passa pelo processamento de foto
  da plataforma, então o `config/initializers/action_text.rb` poda
  `action-text-attachment` na renderização. Reabrir isso é decisão de produto,
  não conveniência de tela.
- **Listagem de texto rico usa `with_rich_text_<nome>_and_embeds`.** Sem o
  preload, cada registro renderizado custa três queries a mais.
- **Rótulo do Trix vive em `app/javascript/trix_locale.js`**, e a chamada é
  síncrona no `application.js` — não em `connect()` de Stimulus. Ver armadilhas.
- **O Trix vem da gem `action_text-trix`, não de uma cópia em
  `vendor/javascript/`.** Ela já serve do próprio domínio e é travada pela
  `actiontext`. A cópia é UMD: `import "trix"`, nunca
  `import Trix from "trix"`.

## Foto e identidade contextual

> Por quê, armadilhas e limites:
> [`docs/photo-policy.md`](docs/photo-policy.md).

- **Anexo de foto entra por `attaches_scrubbed_photo`**, nunca por
  `has_one_attached` direto. O EXIF é destruído na ingestão — os bytes com GPS
  não chegam ao storage. Blob pronto e signed id são **recusados**: não há como
  limpar o que já foi armazenado.
- **Quem decide se uma pessoa aparece pelo nome é o recurso ao lado dela**, não
  o perfil: `ProfilePresenter#name_for(context)`, com `subject:` obrigatório. O
  rótulo de papel chega traduzido de quem chama — papel é vocabulário de #20,
  #21 e #31.
- **Arquivo é servido por controller que autoriza.** As rotas do Active Storage
  são interceptadas em `config/routes.rb`; os nomes continuam sendo os do
  engine. Não use `blob.url` nem redirecione para o serviço: a URL assinada não
  passa por autorização nenhuma.

**Armadilha:** o override do writer de anexo tem de ser definido na **classe**,
não num módulo. O writer do `has_one_attached` mora em
`GeneratedAssociationMethods`, um módulo incluído — e um override num módulo
incluído depois perde a disputa **sem erro nenhum**, com a foto subindo com o
GPS dentro.

## Campo — base, obra e avanço

> O raciocínio de cada decisão: [`docs/field.md`](docs/field.md).

- **Base não é obra.** A base é lugar durável e acumula obras; a obra é
  episódica. `Need` aponta para a base por FK obrigatória e para a obra por FK
  opcional — necessidade sem obra é o caso normal, não a exceção.
- **A sensibilidade desce e só APERTA:** país → base → obra. Base em país
  `public` não nasce `public`; abrir é `promote_visibility!`. O piso da obra em
  relação à base vale sempre, não só na criação.
- **`Project#code` é coluna gerada pelo banco**, sobre um `serial`. Sequence
  avulsa **não é dumpada** no `db/schema.rb`, e o banco de teste nasce do
  schema: presa à coluna, ela sobrevive.
- **Avanço é log de eventos.** `Project#physical_progress` é cache com **um
  escritor só** (`recalculate_physical_progress`, chamado pelo `ProgressReport`),
  movido apenas por relatório `approved`, e valendo o **mais recente**, não o
  maior — regressão de percentual é permitida.
- **Relatório aprovado é imutável.** A guarda pergunta por `status_was`, não por
  `approved?` — a aprovação é ela própria um `update`.
- **Texto rico "preenchido" se mede por `body.to_plain_text.strip.present?`.**
  O Trix envia `<div><br></div>` quando ninguém digitou nada.

## Autorização — fechada por padrão

> Vocabulário, matriz de papéis e o raciocínio de cada decisão:
> [`docs/authorization.md`](docs/authorization.md).

A pergunta nunca é "que tipo de usuário é este", e sim **"esta pessoa pode fazer
isto neste objeto"**. Papel não é coluna em `User`: é `StaffRole` para a
plataforma, `Membership#role` para organização, `ProjectParticipation#role` para
obra.

- **Policy por recurso, em `app/policies/`**, herdando de `ApplicationPolicy`,
  que **recusa tudo** por padrão. Nada de `if current_user.admin?` em controller.
- **A policy recebe `Authorization::Context`, não `User`.** Ele traz perfil,
  papel de plataforma e os vínculos **aceitos**, carregados uma vez por request
  — perguntar ao contexto não vai ao banco.
- **`after_action :verify_authorized` vale para toda action.** Quem não tem
  registro para autorizar declara `skip_authorization_for` com o motivo escrito
  ao lado. Não é atalho: hoje são só as actions de sessão e de senha.
- **404 e 403 respondem igual.** `Pundit::NotAuthorizedError` e
  `ActiveRecord::RecordNotFound` caem no mesmo handler e devolvem 404 — se as
  duas fossem distinguíveis, varrer ids enumeraria o que a sensibilidade
  esconde.
- **Só o nível `admin` alcança `confidential`.** `support` e `curator` param em
  `restricted`, de propósito: alcance que ninguém usa é alcance que vaza.

## Banco de dados

- `bundle exec database_consistency` cobra FK sem índice, `NOT NULL` faltando,
  validação que o schema não sustenta. Ele roda na CI.
- **Coluna `NOT NULL` com default é ponto cego dele**: não cobra validador de
  presença, e `nil` explícito vira `NotNullViolation` em vez de erro de
  formulário. Valide na mão — ver [`docs/identity.md`](docs/identity.md).
- `db/schema.rb` é commitado, e a CI reprova se estiver fora de sincronia com as
  migrations.
- **Toda tabela do `db/schema.rb` tem uma migration neste repositório que a
  cria.** Se dois branches precisam da mesma migration copiada de engine, os
  dois trazem o **mesmo arquivo**, byte a byte, com o timestamp combinado — ver
  [`docs/action-text.md`](docs/action-text.md).
- Bancos de teste são um por processo do `parallel_tests`, via sufixo
  `TEST_ENV_NUMBER` no `database.yml`.
- Na CI, o segundo banco sai de `CREATE DATABASE … TEMPLATE`, e não de uma
  segunda carga de schema: é o Postgres clonando, em vez do Rails subindo de
  novo.
- **Solid Cache, Queue e Cable moram no banco primário**, não em bancos
  dedicados: em produção há uma `DATABASE_URL` só. As tabelas entram por
  migration como qualquer outra — ver
  [`docs/deploy/coolify.md`](docs/deploy/coolify.md).
- O bloco `production:` do `database.yml` não declara `database`, `username` nem
  `host`. Chave escrita ali vence a parte correspondente da `DATABASE_URL`, em
  silêncio.

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

**A partir de 10 templates o herb vira paralelo e para de imprimir
`Loaded N custom rules`.** O `PARALLEL_FILE_THRESHOLD` do
`@herb-tools/linter` é 10: acima disso quem carrega as regras é o worker
thread, e o processo principal nunca imprime o banner. As regras continuam
valendo — verificado, uma violação é reprovada com o repositório inteiro em
modo paralelo — mas o `bin/herb_lint` lia a contagem dali e passou a reprovar
todo mundo dizendo "0 regras carregadas", que é falso. Ele agora faz a
verificação numa passada separada com `-j 1` sobre um arquivo só, e o lint de
verdade segue paralelo.

**`rate_limit` sobre o `:null_store` nunca dispara.** O contador é um
`increment` no cache, e o null store devolve `nil` — o limite existe no código
e não existe em execução. Em teste, `config.action_controller.cache_store`
aponta para um memory store por isso; ver [`docs/authentication.md`](docs/authentication.md).

**O `database_consistency` local olhava o banco de DESENVOLVIMENTO.** Na CI o
job `test` define `RAILS_ENV` para o job inteiro, então lá ele olha o banco de
teste. Localmente o `config/ci.rb` não passava env e o passo reprovava com
"should have a corresponding table" sempre que o banco de dev estivesse atrás
das migrations — um erro sobre o banco errado. O passo agora leva
`RAILS_ENV=test`, como a CI.

**O `Sensitive` só protege coluna que ele sabe nomear.**
`precise_location_attributes` intersecta `PRECISE_LOCATION_ATTRIBUTES` com o
`column_names` da tabela. Uma tabela que chame suas colunas de `street`, `lat`
ou `geom` sai inteira do alcance: as três camadas passam a proteger um conjunto
vazio, e nada reprova — nem linter, nem spec, nem constraint. Coluna de
localização usa os nomes da constante, ou a constante cresce junto.

**Coordenada vaza por dois logs, não um.** A lista default do
`filter_parameters` tem `passw`, `token`, `secret` — nada de localização, e o
Rails é ela que usa para alimentar o `filter_attributes` do Active Record. São
duas superfícies: o `inspect` do modelo (linha de log de exceção, rastreador de
erros) e o `Parameters: {…}` da requisição, que não passa por modelo nenhum. Por
isso os nomes de `PRECISE_LOCATION_ATTRIBUTES` entram nos dois lugares — no
`filter_parameter_logging.rb` e, por modelo, no próprio concern.

**`stylesheet_link_tag :app` não carrega o Tailwind.** O `:app` resolve para
`app/assets/stylesheets/application.css` — o manifesto vazio do generator. O
build do Tailwind sai em `app/assets/builds/tailwind.css` e precisa do próprio
`stylesheet_link_tag "tailwind"`. Os dois layouts subiam sem uma única utility
e nada reclamava: o Propshaft serve o manifesto, o link tag não levanta erro, e
até #6 nenhum spec renderizava layout. Foi o spec de tokens que descobriu.

**`db:migrate` num banco VAZIO carrega o `db/schema.rb` em vez de rodar as
migrations** — sem imprimir uma linha de `== migrating`. Isso esconde tabela
declarada no schema que nenhuma migration cria: a CI (`db:schema:load`) e o
clone limpo passam os dois. Quem paga é o `db:migrate` **incremental**, o do
banco de desenvolvimento e o do deploy: ele roda só o que falta, não cria a
tabela órfã e, no dump que escreve em seguida, **apaga** a tabela do
`db/schema.rb` commitado. Para verificar de verdade, migre a partir do schema
da `main`, não de um banco vazio. Ver [`docs/action-text.md`](docs/action-text.md).

**Tirar `action-text-attachment` da lista de tags permitidas não remove o
anexo.** O `PermitScrubber` DESEMBRULHA a tag não permitida: tira o elemento e
mantém os filhos. E o Action Text renderiza o conteúdo do anexo — o `img` com a
URL do blob — antes de sanitizar. Sem `prune: true` a imagem fica, com o
elemento em volta removido, e parece que a política funcionou. Ver
[`docs/action-text.md`](docs/action-text.md).

**A `ActionText::Engine` atribui o sanitizador num `config.after_initialize` +
`on_load(:action_view)`.** Configurar antes disso — num `to_prepare`, que é o
reflexo — não levanta erro: é sobrescrito depois, e a política some pela metade.
O `config/initializers/action_text.rb` usa o mesmo par de ganchos.

**`Trix.config.lang` aplicado tarde demais devolve a barra em inglês, sem erro.**
O `getDefaultHTML()` roda uma vez, quando o custom element sobe, e o Trix
registra o `customElements.define` num `setTimeout` — então código síncrono do
`application.js` chega a tempo e um `connect()` de Stimulus não. E é
`Object.assign(Trix.config.lang, …)`: o gerador da barra fecha sobre o objeto,
então substituí-lo deixa o gerador lendo o antigo. `spec/system/rich_text_editor_spec.rb`
é quem cobra as duas coisas — nenhum linter aqui lê o Trix.

**Dois arquivos com o mesmo caminho lógico de asset: quem vence muda de
máquina.** O `Propshaft::LoadPath` monta o mapa com `mapped[nome] ||= …`, então
decide a ordem do `config.assets.paths` — e ela não é a mesma em todo lugar.
Medido: com `vendor/javascript/trix.js` e o `trix.js` da gem `action_text-trix`
disputando `trix.js`, o vendor ganhava na máquina de quem escreveu e a gem
ganhava no runner do GitHub. Nada reclama: os dois arquivos existem, os dois são
servidos com 200, e nem `assets:precompile` nem `importmap audit` olham nome
duplicado. `spec/propshaft/load_path_spec.rb` cobra. Ver
[`docs/action-text.md`](docs/action-text.md).

**Erro de ligação num módulo derruba o grafo INTEIRO, em silêncio.** Foi o custo
da armadilha acima: a cópia da gem é UMD, sem `export default`, então o
`import Trix from "trix"` não resolvia — e o navegador rejeita o grafo antes de
avaliar qualquer módulo. Sintoma: todo `/assets/*.js` com 200 no painel de rede
e `window.Turbo`, `window.Stimulus` e `window.Trix` os três `undefined`. Um
`import` que erra sozinho leva junto Turbo, Stimulus e tudo mais que o
`application.js` alcança.

**`NO` é `false` em YAML, e a Noruega some sem erro.** Vale para o código na
lista curada e para a chave no locale: sem aspas, o parser devolve booleano, o
arquivo carrega, e o país deixa de existir sem uma linha de aviso. Os códigos
vão entre aspas nos dois lugares, e `spec/models/country_spec.rb` pede o nome
da Noruega em particular — ver [`docs/vocabulary.md`](docs/vocabulary.md).

**O parser do herb lê marcação dentro de `<%# … %>`.** Comentário ERB não é zona
neutra: um `<body>` ou um `<%= … %>` citado na explicação vira erro de
`parser-no-errors`. Escreva o exemplo sem os sinais, ou não cite marcação no
comentário.

**`gh pr merge --auto` só espera pelos checks obrigatórios do branch.** Sem
proteção de branch configurada, "obrigatório" é o conjunto vazio, e o auto-merge
do dependabot merge na hora — sem olhar a CI. Já aconteceu aqui: o bump de
`image_processing` 1.14 → 2.0.3 entrou na main com `lint` e `test` vermelhos e
quebrou o boot. O `dependabot_automerge.yml` foi reescrito para acordar no
**fim** da CI e só agir se ela passou, mas configurar proteção de branch com
`scan`/`lint`/`test`/`coverage` obrigatórios continua sendo a trava certa.

**Bump de major de dependência merece leitura, não só CI verde.** O
`image_processing` 2.0 largou a dependência de `ruby-vips` e passou a exigir que
o consumidor a declare. O Active Storage tem um `rescue LoadError` para
degradar quando falta a libvips, mas ele casa a mensagem do dlopen — e a 2.0
reescreve essa mensagem, então o rescue não pega. Duas mudanças pequenas em
bibliotecas diferentes, e o resultado é a aplicação não subir.

**A `DATABASE_URL` só alcança o config `primary`.** Com os quatro bancos do
default do Rails 8, `cache`, `queue` e `cable` continuam lendo o `database.yml`
e apontando para `localhost` — onde, dentro do container, não há Postgres. O
`db:prepare` do entrypoint falha no boot, e só em produção: desenvolvimento e
teste já são de banco único, então nada na CI reprova. Por isso o Solid foi
consolidado no primário.

**Healthcheck de deploy vai em `/up`, nunca em `/`.** Não há rota raiz, e a
produção roda com `consider_all_requests_local = false`: `/` devolve 404, o
container fica permanentemente unhealthy e o proxy nunca roteia tráfego — com a
aplicação funcionando do outro lado.

---

## Documentação — `docs/`

**Todo trabalho que estabelece vocabulário, mecanismo ou decisão durável sai com
documento em `docs/`.** Não é opcional e não é "quando sobrar tempo": é parte da
entrega, no mesmo commit.

O que conta como pertinente: um vocabulário que outras pessoas vão consumir
(tokens, componentes, papéis), um mecanismo não óbvio (como um gate é cobrado,
por que um teste existe), uma decisão de arquitetura com alternativa plausível,
uma armadilha que custou investigação. O que **não** conta: o que o código já
diz sozinho, e o que só vale para um PR.

A divisão de trabalho entre os dois arquivos é rígida, porque é ela que mantém
os dois legíveis:

| Vai no `AGENTS.md` | Vai no `docs/` |
| --- | --- |
| O que a CI reprova | Por que ela reprova isso |
| Limites numéricos | O raciocínio que fixou o número |
| "Faça assim", em uma linha | O passo a passo, com exemplo |
| A armadilha em uma frase | A investigação que a descobriu |

Uma regra que chega ao `AGENTS.md` com três parágrafos de contexto deixa de ser
lida — este arquivo só funciona enquanto for varrível. E um documento que apenas
repete a regra não acrescenta nada: se o `docs/` não tem o porquê, ele não
precisava existir.

Regra nova entra nos dois: uma linha aqui, com link, e a explicação lá. Todo
documento novo entra no índice de [`docs/README.md`](docs/README.md) — índice
que mente é pior que índice que não existe.

## Documentação de biblioteca

Antes de escrever código que use uma gem, uma API do Rails ou um pacote JS,
busque a documentação atual (Context7, quando disponível). Assinatura de método
e nome de opção de config mudam entre versões, e as três armadilhas de
"ferramenta que falha em silêncio" acima nasceram exatamente disso: uma API que
mudou e um call site que continuou compilando.

---

## Issues e PRs

**Todo PR que entrega uma issue fecha a issue sozinho, com palavra-chave em
inglês:**

```
Closes #9
```

O GitHub só reconhece `close`/`closes`/`closed`, `fix`/`fixes`/`fixed` e
`resolve`/`resolves`/`resolved`. Este repositório escreve o corpo do PR em
português, e é exatamente aí que a pegadinha mora: **`Fecha #9` não fecha nada.**
Não é erro, não é aviso — o GitHub trata como texto comum e o
`closingIssuesReferences` do PR volta vazio.

Já aconteceu aqui: #6 e #9 foram entregues e mergeadas com "Fecha #N" no corpo,
e as duas ficaram abertas. O board mentiu por dois dias, e a descoberta veio de
uma consulta que por acaso listou as issues antigas.

A linha `Closes #N` é a única em inglês num corpo em português. É feio e é
proposital: ela é sintaxe de ferramenta, não texto para pessoa.

Junto com isso:

- **Quando a entrega fecha uma issue de rastreamento parcial** (a #56 é o
  índice do milestone), marque a caixa correspondente no mesmo dia. Índice que
  mente é pior que índice que não existe — a mesma regra do `docs/README.md`.
- **Issue substituída não é deletada.** Feche como *not planned*, explique no
  comentário o que a substituiu e mova o que sobrou para a issue nova. Deletar
  no GitHub é irreversível, e o que se perde junto é o registro da decisão.

## Convenções de escrita

- Código, nomes de método e mensagens de commit: **inglês**.
- Comentários, documentação e texto de UI: **português**.
- Comentário explica **por quê**, não o quê. Se o comentário parafraseia o
  código, apague o comentário; se o código precisa de paráfrase, renomeie o
  código.
- Toda exceção configurada num linter carrega o motivo escrito ao lado dela.
