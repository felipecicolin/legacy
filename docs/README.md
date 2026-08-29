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

### Plataforma

- [Autenticação](authentication.md) — para quem ela é, por que o app nasce
  fechado, por que sessão é linha no banco, e as duas decisões de segurança
  (não vazar quem tem conta, derrubar sessões na troca de senha).

### Deploy

- [Deploy no Coolify](deploy/coolify.md) — por que Solid Cache, Queue e Cable
  moram num banco só, o que a `DATABASE_URL` alcança e o que não alcança, e a
  configuração que o Coolify precisa do outro lado.
