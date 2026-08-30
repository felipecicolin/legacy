# Documentação

O `AGENTS.md` na raiz é o contrato: as regras que a CI cobra, curtas e sem
justificativa longa. Este diretório é o complemento — o **porquê** de cada
regra e o **como** de cada tarefa recorrente.

A divisão importa. Uma regra que vem com três parágrafos de contexto no
`AGENTS.md` deixa de ser lida; um documento que só repete a regra não
acrescenta nada. Então:

| Vai no `AGENTS.md` | Vai aqui |
| --- | --- |
| O que a CI reprova | Por que ela reprova isso |
| Limites numéricos | O raciocínio que fixou o número |
| "Faça assim" | O passo a passo, com exemplo |
| Armadilha em uma frase | A investigação que a descobriu |

## Índice

### Design system

- [Tokens de cor, superfície e raio](design-system/tokens.md) — o vocabulário
  semântico, como adicionar um token, como trocar a identidade visual do
  produto, e o que sustenta que nada disso quebre em silêncio.
- [Moldura de imagem](design-system/image-frame.md) — por que a proporção é
  reservada antes de a imagem existir, os tokens de enquadramento, os três
  estados do anexo, e a evidência que obrigou a instalar o Active Storage.
- [Layout de autenticação](design-system/auth-layout.md) — por que as telas de
  acesso não usam o shell da aplicação, o que um layout novo perde em silêncio,
  por que a ordem do DOM é o inverso da ordem da tela, e como a foto entra no
  lugar do apoio.
- [Biblioteca de componentes](design-system/components.md) — a composição do
  shell responsivo, os estados sem conteúdo, a tabela dupla e as regras de
  acessibilidade compartilhadas pelos componentes de fundação.

### Plataforma

- [Autenticação](authentication.md) — para quem ela é, por que o app nasce
  fechado, por que sessão é linha no banco, e as duas decisões de segurança
  (não vazar quem tem conta, derrubar sessões na troca de senha).
- [Autorização e páginas de erro](authorization.md) — papéis globais e
  contextuais, a verificação obrigatória das policies, não enumeração de
  recursos e flash acessível por Turbo Stream.
- [i18n](i18n.md) — o que a `rails-i18n` traduz e o que sobrou para nós, os
  formatos pt-BR e o raciocínio por trás de cada um, onde cada chave mora, a
  convenção de rótulo de enum e o guarda que a cobra.
- [Busca](search.md) — por que três consultas em vez de uma `UNION`, por que
  buscar não pode virar oráculo, por que o `unaccent` não tem índice, e os três
  casos do estado vazio dos quais um não se diz.
- [Mobilização — necessidade, voluntariado e envio](mobilization.md) — por que a
  necessidade tem duas chaves reais em vez de um polimorfismo, por que o
  voluntariado tem duas camadas e o que a fusão apagaria, e por que não há
  documento de viagem.
- [Campo — base, obra e avanço](field.md) — por que base e obra são coisas
  diferentes e o que a fusão quebraria, como a sensibilidade desce sem nunca
  afrouxar, por que o código da obra é coluna gerada, por que o avanço é log de
  eventos com a coluna servindo só de cache, o vazamento pelo perfil de quem
  participou, e o que o seed mínimo é e não é.
- [Autorização](authorization.md) — por que a pergunta é "pode fazer isto neste
  objeto" e nunca "que tipo de usuário é este", onde cada papel mora, por que a
  autorização é fechada por padrão nas duas pontas, e por que 404 e 403
  respondem igual.
- [Identidade — `Profile`](identity.md) — por que uma pessoa e muitos papéis em
  vez de uma tabela por papel, por que o nome público é armazenado e não
  derivado, e como o nome legal é impedido de sair por serialização.

- [Organizações e vínculos](organizations.md) — por que dois enums fogem do
  nome que a issue pedia, por que o slug é imutável e ganha sufixo de
  desempate, as três camadas que impedem uma organização de perder o dono que
  tem — inclusive quando o vínculo é movido para outra —, e o que a remoção em
  massa ainda alcança.

- [Pagamentos](payments.md) — a fronteira que isola o provedor, por que o
  simulador é determinístico e configurável, por que a marca de origem é
  `attr_readonly`, e as duas invariantes que a CI cobra sobre o repositório
  inteiro.

- [Arrecadação](funding.md) — a cadeia de campanha, contribuição, assinatura,
  orçamento e canais, com dinheiro em centavos, pagamento simulado,
  idempotência e visibilidade segura.

- [Vocabulário curado](vocabulary.md) — por que a lista de países e habilidades
  é YAML e não seed, por que o nome do país não é coluna, por que a curadoria de
  `high_risk` é decisão pendente da equipe, e o gancho que só aperta.

- [Visibilidade](visibility.md) — por que obra nasce fechada, por que registro
  confidencial não *guarda* coordenada em vez de só não mostrá-la, como a
  promoção de nível é auditada, e o que sustenta o agregado anonimizado.

- [Identidade contextual e política de foto](photo-policy.md) — por que quem
  decide o nome que aparece é o recurso e não o perfil, por que o EXIF é
  destruído na ingestão em vez de filtrado na exibição, as duas armadilhas
  silenciosas do override de anexo, como a rota do Active Storage é
  interceptada sem copiar o arquivo de rotas do engine, e onde cada uma
  dessas defesas para.

- [Action Text](action-text.md) — por que texto rico nasce sem anexo embutido,
  as duas camadas que cobram isso, a corrida que a barra do Trix perde se a
  tradução chegar um tique atrasada, por que o CSS do Trix fica verbatim, e o
  `trix.js` disputado por dois arquivos que matou o grafo de módulos inteiro em
  silêncio — em uma máquina só.

### Deploy

- [Deploy no Coolify](deploy/coolify.md) — por que Solid Cache, Queue e Cable
  moram num banco só, o que a `DATABASE_URL` alcança e o que não alcança, e a
  configuração que o Coolify precisa do outro lado.
