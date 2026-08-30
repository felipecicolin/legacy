# Pagamentos — a fronteira que mantém a demo honesta

> Fronteira: [`app/payments/payments/`](../app/payments/payments)
> · Rastro: [`PaymentTransaction`](../app/models/payment_transaction.rb)
> · Specs: [`spec/payments/`](../spec/payments)

Este projeto é uma **demonstração**. Não há gateway, não há PIX, não há cartão,
não há chave de API e não há webhook — não existe terceiro do outro lado.

O que existe é o domínio de arrecadação modelado por inteiro, com o pagamento
isolado atrás de uma fronteira e uma implementação simulada do outro lado. É
essa fronteira que faz as issues seguintes de arrecadação (#39 a #46) poderem
ser escritas sem um `if demo?` em cada tela, e que faz a integração de verdade,
quando vier, ser a troca de um objeto — não uma reescrita, e não uma migration.

## As quatro peças

| Peça | Papel |
| --- | --- |
| `Payments::PaymentProvider` | O contrato, e os dois vocabulários fechados (`OPERATIONS`, `STATUSES`) |
| `Payments::Request` / `Payments::Result` | O que entra e o que sai de toda operação |
| `Payments::SimulatedProvider` | A única implementação de hoje |
| `Payments::Gateway` | A fachada: é com ela que o domínio fala, e é ela que grava o rastro |

```ruby
request = Payments::Request.new(amount_cents: 25_000, currency: "BRL", reference: "doacao-7")
transaction = Payments::Gateway.new.charge(request)

transaction.provider_reference # => "SIM-doacao-7"
transaction.simulated?         # => true
```

O provedor concreto é resolvido uma vez, em
[`config/initializers/payments.rb`](../config/initializers/payments.rb), e vive
em `config.x.payment_provider`. **Aquela é a única linha do repositório que
nomeia uma implementação.** Trocar o simulador por um gateway real é reescrever
a atribuição; nenhum modelo, controller, view ou coluna muda.

### Por que `Request` em vez dos três parâmetros soltos

A issue esboçou `charge(amount_cents:, currency:, reference:)`. A mesma trinca
atravessa a fachada, o provedor e a linha do banco, e o reek chama isso pelo
nome: `DataClump` — três métodos, os mesmos três parâmetros. A regra do
`AGENTS.md` para esse smell é uma só, "introduzir um value object", e não há
supressão neste repositório. Então a trinca virou `Payments::Request`, e a
assinatura das três operações é `(request)`.

O ganho não é só calar o linter: um campo novo no pedido (a parcela, o
compromisso recorrente) entra no `Data.define` e não em quatro assinaturas.

### Por que o `Request` valida na construção

Porque o `Gateway` chama o provedor **primeiro** e grava o rastro **depois**.
Deixar a cobrança do valor só nas validações de `PaymentTransaction` inverte a
ordem que interessa: o pedido atravessa o provedor, o provedor age, e só então
o `create!` reprova. Com o simulador isso é um `RecordInvalid` estranho; com um
gateway de verdade do outro lado é dinheiro movido sem linha no banco — o
contrário exato do que esta fachada promete.

```ruby
Payments::Request.new(amount_cents: 0, currency: "brl", reference: "doacao-9")
# => ArgumentError: amount_cents must be a positive Integer, got 0
```

`Integer` e não "numérico": centavo é contagem, e aceitar `Float` aqui seria a
porta por onde o dinheiro em ponto flutuante entra no sistema. O formato da
moeda sai de `PaymentProvider::CURRENCY_FORMAT`, o mesmo que a validação da
coluna usa — duas cópias do regexp seriam a divergência que aparece tarde, com
um pedido que a fachada aceita e a linha recusa.

## Por que o simulador é determinístico e configurável

O desfecho vem de `outcome:`, e nunca de sorteio:

```bash
PAYMENT_OUTCOME=refused bin/rails server
```

Valor desconhecido **não sobe**: o construtor levanta `ArgumentError` no boot,
com o valor na mensagem. É deliberado — um `PAYMENT_OUTCOME=refuse` digitado
errado que subisse em silêncio viraria uma demo que produz sucesso enquanto
quem a configurou acha que está mostrando recusa.

**Determinístico** porque uma demo que falha uma vez a cada dez não dá para
apresentar, e um spec sobre ela seria intermitente — o tipo de teste que reprova
na CI de outra pessoa, em outro arquivo.

**Configurável** porque uma demo que só mostra o caminho feliz não prova nada
sobre a UI: as telas de pendência, de falha e de recusa só existem se der para
chegar nelas. Os quatro desfechos são `succeeded`, `pending`, `failed` e
`refused`.

`pending` está lá por causa do mundo real, não da demo: boleto e PIX agendado
respondem depois. Uma UI que só sabe tratar sim e não encontra a terceira
resposta na primeira integração de verdade — tarde, e com dinheiro envolvido.

## O rastro: `payment_transactions`

Toda chamada à fachada vira linha. Gravar na fachada, e não em cada chamador, é
o que sustenta duas promessas: não existe movimento de dinheiro sem rastro, e
nenhuma tela precisa perguntar "isto é demo?" para saber se marca.

Três decisões de coluna merecem explicação:

**Dinheiro é `bigint` de centavos com `currency` ao lado.** Regra do
repositório, e ela existe porque `float` não representa 0,10: o erro é
invisível numa linha e aparece depois de somar mil. A coluna de moeda existe
para que somar valores em moedas diferentes seja impossível por acidente.

**`simulated` é `attr_readonly`.** Com os defaults do Rails 8.1, atribuir a um
atributo readonly num registro persistido levanta
`ActiveRecord::ReadonlyAttributeError`. Promover um lançamento simulado a real
não é, portanto, um update a ser pego em code review: é uma exceção, em tempo
de execução, no lugar exato onde alguém tentou. O default da coluna é `true`
pelo mesmo motivo — numa instalação de demonstração o silêncio tem de errar
para o lado de marcar demais.

### Até onde o `attr_readonly` vai, e por que não há trigger

O alcance medido, porque metade dele é contraintuitivo:

| Caminho | O que acontece |
| --- | --- |
| `update` / `update!` / `save` | `ActiveRecord::ReadonlyAttributeError` |
| `update_column` | `ActiveRecord::ActiveRecordError` |
| `update_all` | **passa em silêncio** |
| SQL cru | **passa em silêncio** |

`update_all` surpreende porque parece Active Record e não é: ele monta o UPDATE
a partir da relação, sem instanciar registro, então não há atributo para o
`attr_readonly` recusar. Um script de correção em massa — o lugar mais natural
para escrever `update_all` — promoveria a coluna inteira sem levantar nada.

A trava que pegaria isso não é `CHECK`: uma constraint enxerga o estado de uma
linha, não a transição, e imutabilidade é uma afirmação sobre a transição. Seria
trigger. E trigger **não cabe neste repositório hoje**, por um motivo mecânico:
o `db/schema.rb` é o formato Ruby, e o dumper do Rails não escreve trigger nele.
A trava existiria no banco criado por migration e não existiria no banco de
teste, que a CI monta com `db:schema:load` — uma garantia que vale em produção e
não vale onde ela é verificada é pior que garantia nenhuma, e é exatamente o
padrão de "ferramenta que sai verde sem olhar" que o `AGENTS.md` cataloga. Tê-la
custaria migrar o projeto para `schema_format = :sql`.

Então o limite fica escrito onde se lê — no modelo, aqui, e no `AGENTS.md` — em
vez de meio cobrado. Quem for escrever correção em massa em
`payment_transactions` precisa saber que a coluna não se defende sozinha nesse
caminho.

**Nenhuma coluna guarda instrumento de pagamento.** Não há número, validade,
código de segurança, titular nem IBAN. A demo não coleta o que a demo não usa,
e o que não é coletado não vaza — nem em dump, nem em log, nem em backup
esquecido.

## As duas invariantes que a CI cobra

Vivem em [`spec/payments/payments_spec.rb`](../spec/payments/payments_spec.rb),
e as duas são sobre o repositório inteiro, não sobre uma classe:

1. **Nenhum arquivo de `app/models`, `app/controllers`, `app/views` ou
   `app/components` cita `SimulatedProvider`.** O nome concreto no domínio é a
   fronteira furada: a partir dele, trocar de provedor vira busca e
   substituição em N arquivos e o `if demo?` volta pela porta dos fundos.
2. **Nenhuma coluna de nenhuma tabela tem nome de dado de pagamento.** O spec
   percorre `connection.tables` e compara os nomes de coluna quebrados por `_`
   contra uma lista de tokens (`card`, `cvv`, `pan`, `titular`, `iban`,
   `validade`, `expiry`…) — tokens inteiros, e não substring, porque `pan`
   casaria com metade do dicionário.

   `validade`/`expiry`/`expiration` entraram depois: a validade do cartão é o
   único dos cinco dados que o `AGENTS.md` promete barrar e que não carrega
   nenhum outro token no nome, então `t.date :validade` e
   `t.integer :expiry_month` atravessavam o gate inteiros. Achado plantando as
   duas colunas — a lista de tokens é ela mesma um lugar onde a ferramenta sai
   verde sem olhar.

Cada uma vem com um exemplo irmão — "actually reads the domain files",
"actually reads the schema" — que existe por causa da armadilha recorrente
deste repositório: **ferramenta que não olha nada e sai verde**. Um glob
apontado para o diretório errado acha zero arquivos e passa para sempre.

As duas foram verificadas do jeito que o `AGENTS.md` manda: com uma violação
plantada de propósito, para ver o spec reprovar antes de confiar nele.

## A marca é do dado, e não da tela

Houve um `SimulatedDataBannerComponent`: uma tarja no layout, em toda tela, com
os dizeres "Ambiente de demonstração". Ele foi **removido por decisão de
produto** — a tarja competia com o conteúdo em cada tela do produto, inclusive
nas que não mostram um centavo, como a de acesso.

Fica registrado o que se perdeu junto, porque a decisão só é revisável se o
custo estiver escrito: o risco que a tarja endereçava é o **print compartilhado
fora de contexto**. Uma prestação de contas simulada que parece real não se
denuncia sozinha numa captura de tela, e hoje nada na interface a denuncia.

O que **continua** valendo é a marca no dado, que é a camada que não depende de
ninguém lembrar: `Payments::Gateway` carimba `simulated:` em todo lançamento a
partir do `simulated?` do provedor, a coluna é `attr_readonly`, e promover
simulado a real levanta `ReadonlyAttributeError`. O contrato do provedor
continua exigindo `simulated?` explicitamente, pelo mesmo motivo de sempre —
não há padrão, porque os dois padrões possíveis mentem.

Se a marca voltar para a interface, ela volta pelo layout e não pela tela de
arrecadação, e perguntando ao provedor (`Payments::Gateway.simulated?`) e não
ao ambiente: `Rails.env.production?` responderia errado justamente numa demo
publicada, que é onde o aviso mais importaria.

## Escrevendo o próximo provedor

1. Inclua `Payments::PaymentProvider` e implemente as quatro perguntas. O que
   faltar levanta `NotImplementedError` com o nome da sua classe.
2. Responda `simulated?` explicitamente. O contrato não tem padrão de
   propósito: `false` esconderia a marca numa demo e `true` marcaria dinheiro
   real como de mentira.
3. Devolva `Payments::Result` com um status do vocabulário. Inventar
   `:approved` levanta `ArgumentError` na fronteira, e não uma linha inválida
   no banco.
4. Reaponte `config.x.payment_provider`. Se isso não bastar — se você precisou
   de uma coluna, de um `if` num modelo ou de uma migration —, a fronteira
   vazou, e o lugar de consertar é aqui, não na sua classe.
