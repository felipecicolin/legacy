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

### Plataforma

- [Autenticação](authentication.md) — para quem ela é, por que o app nasce
  fechado, por que sessão é linha no banco, e as duas decisões de segurança
  (não vazar quem tem conta, derrubar sessões na troca de senha).
- [i18n](i18n.md) — o que a `rails-i18n` traduz e o que sobrou para nós, os
  formatos pt-BR e o raciocínio por trás de cada um, onde cada chave mora, a
  convenção de rótulo de enum e o guarda que a cobra.
- [Identidade — `Profile`](identity.md) — por que uma pessoa e muitos papéis em
  vez de uma tabela por papel, por que o nome público é armazenado e não
  derivado, e como o nome legal é impedido de sair por serialização.

- [Organizações e vínculos](organizations.md) — por que dois enums fogem do
  nome que a issue pedia, por que o slug é imutável e ganha sufixo de
  desempate, as três camadas que garantem que toda organização tenha um dono, e
  o que a remoção em massa ainda alcança.

- [Pagamentos](payments.md) — a fronteira que isola o provedor, por que o
  simulador é determinístico e configurável, por que a marca de origem é
  `attr_readonly`, e as duas invariantes que a CI cobra sobre o repositório
  inteiro.

- [Visibilidade](visibility.md) — por que obra nasce fechada, por que registro
  confidencial não *guarda* coordenada em vez de só não mostrá-la, como a
  promoção de nível é auditada, e o que sustenta o agregado anonimizado.

- [Action Text](action-text.md) — por que texto rico nasce sem anexo embutido,
  as duas camadas que cobram isso, a corrida que a barra do Trix perde se a
  tradução chegar um tique atrasada, por que o CSS do Trix fica verbatim, e o
  `trix.js` disputado por dois arquivos que matou o grafo de módulos inteiro em
  silêncio — em uma máquina só.

### Deploy

- [Deploy no Coolify](deploy/coolify.md) — por que Solid Cache, Queue e Cable
  moram num banco só, o que a `DATABASE_URL` alcança e o que não alcança, e a
  configuração que o Coolify precisa do outro lado.
