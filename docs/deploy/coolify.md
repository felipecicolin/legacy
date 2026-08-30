# Deploy no Coolify

O deploy é por Dockerfile: o Coolify constrói a imagem a partir deste
repositório e sobe **um container**, com o Postgres como serviço separado na
mesma instância. Não há Kamal, não há `docker-compose.yml` e não há container de
worker — o supervisor do Solid Queue roda dentro do Puma.

Este documento explica a decisão que tornou isso possível (Solid num banco só) e
o que precisa estar configurado do lado do Coolify.

---

## Por que Solid Cache, Queue e Cable moram no banco primário

O generator do Rails 8 entrega quatro bancos em produção: `primary`, `cache`,
`queue` e `cable`, cada um com o seu `schema` próprio em `db/*_schema.rb`. É um
bom default para quem controla o servidor de banco — isola o churn de escrita
das filas e do cache do banco de domínio, e permite retenção diferente por
banco.

Só que o Coolify entrega **um serviço Postgres e uma `DATABASE_URL`**, e o Rails
não distribui essa URL pelos quatro configs. Ele a aplica só no config chamado
`primary`; os outros três continuam lendo o que estiver escrito no
`database.yml`. Com o default do generator, o resultado é este:

```
$ DATABASE_URL=postgres://cool:pw@db-host:5432/legacy \
  RAILS_ENV=production bin/rails runner '…'

primary: host="db-host" db="legacy"
cache:   host="localhost" db="legacy_production_cache" user="legacy"
queue:   host="localhost" db="legacy_production_queue" user="legacy"
cable:   host="localhost" db="legacy_production_cable" user="legacy"
```

Três conexões apontando para um `localhost` que, dentro do container, não tem
Postgres nenhum. O `db:prepare` do entrypoint falha no boot e o container morre
antes de responder à primeira requisição — o modo de falha é barulhento, mas só
aparece em produção, porque em desenvolvimento e teste o `database.yml` já é de
banco único.

As duas saídas eram:

| Alternativa | Custo |
| --- | --- |
| Manter os quatro bancos, com quatro URLs | Quatro variáveis de ambiente no Coolify em vez de uma, e o papel do Postgres precisa de `CREATEDB` para o `db:prepare` criar os três bancos extras no primeiro boot |
| Consolidar tudo no banco primário | Três migrations a mais, ~140 linhas no `db/schema.rb`, e o churn de escrita dos três gems passa a cair no banco de domínio |

Escolhemos consolidar, por um motivo que não é estético: **é a forma que já roda
nesta instância do Coolify.** O `hubi-web` faz exatamente isso — Solid Cache,
Queue e Cable sobre a conexão primária, uma `DATABASE_URL` só — e está em
produção há meses. A alternativa de quatro URLs é plausível no papel, mas
introduz três incógnitas (permissão de `CREATEDB`, criação de bancos no boot,
quatro variáveis que podem divergir entre si) em troca de uma separação que uma
aplicação de um container só não usa.

O que a consolidação custou na prática:

- `db/migrate/20260829120000_create_solid_cache_tables.rb`
- `db/migrate/20260829120100_create_solid_queue_tables.rb`
- `db/migrate/20260829120200_create_solid_cable_tables.rb`

As três são transcrição fiel dos `db/*_schema.rb` que o Rails gerava para os
bancos dedicados: mesmas colunas, mesmos nomes de índice, mesmas FKs com
`on_delete: :cascade`. Divergir daí quebra as queries dos próprios gems, que
referenciam índice por nome. A única diferença no `schema.rb` dumpado é de
notação — `integer limit: 8` vira `bigint`, e o `limit` em coluna `binary` some
porque no Postgres `bytea` não tem limite —, não de estrutura.

E o `database_consistency` passa sobre elas sem uma única ofensa, o que era o
risco real da consolidação do lado da CI: trazer as tabelas dos gems para dentro
do alcance de um linter que este projeto não pode silenciar.

### O custo que sobra: churn no banco de domínio

Isolar esse churn é justamente a razão de o default do Rails 8 usar quatro
bancos, e a consolidação abre mão disso. Num banco só, o mesmo Postgres que
guarda o domínio absorve o polling do Solid Queue (uma query por segundo, por
dispatcher e por worker), o polling do Solid Cable a cada 100ms, a expiração de
mensagens do Cable e o trim do Cache por tamanho — tudo escrita e delete, o
padrão mais hostil que existe para o autovacuum.

Numa aplicação de um container e sem tráfego, isso é irrelevante, e o
`hubi-web` roda assim em produção. Mas o gatilho para revisitar a decisão é
**carga**, não organização: quando o `pg_stat_user_tables` mostrar as tabelas
`solid_*` dominando o dead tuple count, ou quando a latência de query do domínio
começar a acompanhar o volume de jobs, o caminho de volta é separar os bancos —
e aí valem as quatro URLs que este documento descartou.

### O pool passou a ser compartilhado

Com um banco só, o supervisor do Solid Queue disputa conexão com as threads do
Puma. Por isso a produção não usa o mesmo número de conexões do desenvolvimento:

```yaml
max_connections: <%= ENV.fetch("RAILS_DB_POOL") { ENV.fetch("RAILS_MAX_THREADS", 5).to_i + 4 } %>
```

As quatro conexões de folga cobrem supervisor, dispatcher, scheduler e worker.
Se um dia o worker sair para um container próprio, o `RAILS_DB_POOL` permite
ajustar isso sem mexer no código.

### Nada de `database:`, `username:` ou `host:` na produção

O bloco `production:` do `database.yml` não declara nenhum dos três. É
deliberado: qualquer chave escrita ali **vence a parte correspondente da
`DATABASE_URL`**, em silêncio. Um `host:` esquecido no `default: &default` é
suficiente para o app conectar no lugar errado sem erro nenhum.

---

## Configuração do lado do Coolify

### Variáveis de ambiente

| Variável | Valor | Por quê |
| --- | --- | --- |
| `RAILS_MASTER_KEY` | conteúdo de `config/master.key` | O arquivo é gitignored e não entra na imagem (`.dockerignore`). Sem ele o app não decifra as credentials e não sobe |
| `DATABASE_URL` | a URL interna do serviço Postgres | O Coolify oferece essa variável pronta ao vincular o banco à aplicação |
| `APP_HOST` | `legacy-demo.example.org`, sem esquema | O link do e-mail de recuperação de senha é gerado com ele. O nome é deliberadamente neutro e não sugere uma organização real. Sem a variável **o container não sobe** — é de propósito: um host errado só apareceria na caixa de entrada de outra pessoa |
| `SOLID_QUEUE_IN_PUMA` | `true` | Sem ela o `config/puma.rb` não carrega o plugin, e o `recurring.yml` — que limpa jobs finalizados de hora em hora — nunca roda |
| `RAILS_MAX_THREADS` | opcional, default `5` | Entra no `max_connections` pela fórmula acima |
| `RAILS_DB_POOL` | opcional | Sobrescreve a fórmula, se o pool precisar de ajuste fino |

`RAILS_ENV`, `BUNDLE_*` e `LD_PRELOAD` já vêm fixados no Dockerfile — não repita
no Coolify.

### Healthcheck: `/up`, nunca `/`

**Esta é a armadilha mais provável do primeiro deploy.** O `config/routes.rb`
ainda não define rota raiz, e a produção roda com
`consider_all_requests_local = false`. Um healthcheck apontado para `/` recebe
404, o container é marcado como unhealthy, e o Coolify nunca roteia tráfego para
ele — com a aplicação funcionando perfeitamente do outro lado.

Aponte para `/up`, que é o `rails/health#show`. Ele responde 200 em HTTP puro
mesmo com `force_ssl = true` ligado, porque o `assume_ssl = true` faz o Rails
tratar toda requisição como já-HTTPS e o redirect nunca dispara. Verificado:

```
$ curl -i http://127.0.0.1:3311/up
HTTP/1.1 200 OK
```

### Porta

`80`. O Dockerfile expõe essa porta e o CMD sobe o Thruster, que escuta nela e
faz proxy para o Puma em 3000. A terminação TLS é do Traefik do Coolify — não
defina `TLS_DOMAIN`, ou o Thruster tentaria emitir certificado por conta
própria.

### Volume persistente do Active Storage

No recurso da aplicação no Coolify, crie um volume persistente montado em
`/rails/storage`. Esse é o caminho usado pelo service `local` em
`config/storage.yml`; o nome do volume pode ser `legacy-demo-storage`, sem
referência a uma organização real. Faça o mount antes de habilitar qualquer
upload, porque sem ele todo arquivo enviado some no próximo deploy.

A alternativa é trocar o service por S3/R2 e configurar as credenciais como
secrets do Coolify. Não use as duas estratégias ao mesmo tempo: o app deve ter
uma única origem persistente para os anexos.

### Recarga do seed

Para ensaiar a demo do começo, execute no terminal do container:

```sh
CONFIRM_DEMO_SEED_RELOAD=1 bin/rails demo:reload_seed
```

O comando delega para `db:seed:replant`, que recria os dados e carrega o seed
de forma idempotente. A confirmação explícita é obrigatória e não existe rota
HTTP equivalente, então um acesso acidental à aplicação não apaga o banco.

---

## O que o entrypoint faz

O `bin/docker-entrypoint` é o do generator, sem modificação: quando os dois
últimos argumentos são `./bin/rails server` — que é o caso do
`CMD ["./bin/thrust", "./bin/rails", "server"]` —, ele roda `db:prepare` antes
de servir.

Isso é idempotente: no banco vazio carrega o `schema.rb`, no banco em dia é
no-op, e com migration pendente aplica. Se falhar, o container não sobe, o
healthcheck nunca passa e o Coolify mantém a versão anterior no ar.

O `hubi-web` tem um dispatcher de papéis (`HUBI_ROLE=web|worker|migrate`) porque
roda web e worker em containers separados. Aqui não faz sentido ainda: um
container com `SOLID_QUEUE_IN_PUMA` é o tamanho certo. Quando o volume de jobs
justificar separar, o caminho é o mesmo — o `bin/jobs` já existe.

---

## Pendências conhecidas

Nenhuma bloqueia o deploy, mas a configuração abaixo é obrigatória antes da
funcionalidade correspondente existir:

- **Volume persistente do Active Storage**, montado no Coolify em
  `/rails/storage`, ou service S3/R2 configurado.

Duas pendências que estavam aqui saíram com a autenticação (#9):

- **A rota raiz existe** (`root "home#show"`) e exige sessão, então o domínio
  deixa de responder 404. É espaço reservado até #8 e #57.
- **O host do mailer virou `APP_HOST`**, obrigatório, com o valor neutro
  `legacy-demo.example.org`. O primeiro mailer com link
  — o de recuperação de senha — entrou nessa issue, que era exatamente o gatilho
  registrado aqui. **Adicione a variável no Coolify antes do próximo deploy**,
  ou o container não sobe.
