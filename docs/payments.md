# Pagamentos — a fronteira que mantém a demo honesta

> Fronteira: [`app/payments/payments/`](../app/payments/payments)
> · Rastro: [`PaymentTransaction`](../app/models/payment_transaction.rb)
> · Marca na UI: [`SimulatedDataBannerComponent`](../app/components/simulated_data_banner_component.rb)
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

## Por que o simulador é determinístico e configurável

O desfecho vem de `outcome:`, e nunca de sorteio:

```bash
PAYMENT_OUTCOME=refused bin/rails server
```

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
   contra uma lista de tokens (`card`, `cvv`, `pan`, `titular`, `iban`…) —
   tokens inteiros, e não substring, porque `pan` casaria com metade do
   dicionário.

Cada uma vem com um exemplo irmão — "actually reads the domain files",
"actually reads the schema" — que existe por causa da armadilha recorrente
deste repositório: **ferramenta que não olha nada e sai verde**. Um glob
apontado para o diretório errado acha zero arquivos e passa para sempre.

As duas foram verificadas do jeito que o `AGENTS.md` manda: com uma violação
plantada de propósito, para ver o spec reprovar antes de confiar nele.

## A marca na tela

`SimulatedDataBannerComponent` fica no **layout**, não na tela de arrecadação.
A escolha é deliberada: assim toda tela nasce marcada e nenhuma precisa lembrar
— e o print compartilhado fora de contexto, que é o risco de verdade de uma
prestação de contas que parece real, sai marcado.

O `render?` pergunta ao provedor (`Payments::Gateway.simulated?`), e não ao
ambiente. `Rails.env.production?` responderia errado justamente numa demo
publicada, que é onde o aviso mais importa. Quando o provedor deixar de ser
simulado, o banner some sozinho — aviso falso custa a mesma confiança que aviso
faltando.

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
