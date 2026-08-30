# Arrecadação

Arrecadação é uma cadeia única de prestação de contas. Uma `Campaign` pertence
a uma `Ngo` e pode apontar para uma `Project`; `Contribution` registra
o lançamento em dinheiro, `InKindDonation` registra o valor estimado de um bem
ou serviço, e `Receipt` congela o comprovante da contribuição confirmada.

## Dinheiro e pagamento

Todo valor monetário é um inteiro em centavos (`*_cents`) acompanhado de
`currency`. O modelo nunca usa `float`, e valida que a quantia seja positiva.
`Payments::Gateway` é a única fronteira com o provedor: o ambiente atual usa o
provedor simulado, que é determinístico e marca lançamento e comprovante como
`simulated`. A marca é somente de origem e é protegida por `attr_readonly`.

O total da campanha é derivado: contribuições `confirmed` e doações em espécie
`accepted`, `in_transit` ou `delivered` são recalculadas sob lock. Uma
contribuição pode ser geral (assinatura sem campanha), mas todo lançamento de
campanha exige uma campanha ativa ou já atingida e a mesma moeda.

## Assinaturas e benefícios

`SubscriptionPlan` define valor, moeda e intervalo mensal, trimestral ou anual.
`Subscription#charge_due!` usa lock e a chave
`subscription-<id>-<next_charge_on>` para tornar o ciclo idempotente. Uma falha
mantém a mesma data, muda o status para `past_due` e agenda a tentativa do dia
seguinte; sucesso cria uma `Contribution` e avança a data com `Date#advance`.
O job recorrente diário chama essa operação, sem gateway concreto no domínio.

Cada ciclo cria um benefício de relatório mensal; a cada seis ciclos cria
também o presente semestral. O relatório é montado com o contexto de
visibilidade: uma campanha que o leitor não pode identificar gera conteúdo
restrito, e a ausência de atualização diz honestamente que não há novidades.
Cancelar antes do sexto ciclo marca o presente como `skipped`, preservando o
histórico. O job de benefícios prepara e envia apenas o relatório mensal.

## Orçamento e despesas

Um `Budget` pertence a uma obra, tem moeda e versões. Linhas (`BudgetLine`)
mantêm as estimativas por categoria; o total é recalculado sob lock. Orçamento
aprovado não é editável: `revise!` cria nova versão e copia as linhas. Despesas
não são rejeitadas por ultrapassar a estimativa — `over_budget?` e a variância
sinalizam o excesso para prestação de contas. Despesas e recibos de foto passam
por `attaches_scrubbed_photo`.

## Canais

`Event` pode ter ingresso gratuito ou pago. Inscrições pagas criam uma
`Contribution` com origem `event`; cancelar reembolsa pelo gateway simulado.
Inscrições gratuitas não criam lançamento. Eventos passados só podem nascer
como `held`, e a capacidade é uma verificação simples (não uma promessa de
reserva financeira).

`Partnership` separa tipo, faixa, status, datas e totais em dinheiro e espécie;
uma marca pública só aparece enquanto ativa, assinada e dentro das datas.
`InKindDonation` aceita cinco categorias, exige unidade `hora` para expertise e
serviço, permite triagem espontânea sem `need_id` e mantém especificação rica e
documentos. A tabela de `Need` fica para a issue #33, portanto `need_id` não
tem FK nesta migration.

Todos os canais herdam a sensibilidade de seu contexto e só podem ficar mais
restritos automaticamente. Agregados por país exigem o mínimo de três
campanhas e retornam somente totais, sem identificar doadores ou localizações.
