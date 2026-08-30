# Campo: base, obra e entregáveis

> Modelos: [`MissionBase`](../app/models/mission_base.rb),
> [`Project`](../app/models/project.rb), [`SiteSurvey`](../app/models/site_survey.rb),
> [`ProgressReport`](../app/models/progress_report.rb),
> [`ProjectParticipation`](../app/models/project_participation.rb) e
> [`ProjectPhoto`](../app/models/project_photo.rb).

## Base e obra

`MissionBase` é o lugar durável. A associação com necessidades entra quando o
modelo `Need` de #33 existir; até lá, a base já suporta várias obras ao longo
do tempo, inclusive quando não existe uma obra ativa. `Project` é o episódio,
com código sequencial `OB-0001`, prazo, meta de recursos e um dos cinco estados
do domínio. O slug da base e o código da obra são armazenados e imutáveis.

Uma base nasce `pending`; apenas `MissionBase.visible` (bases `active`) entra
na busca ou em fluxos de apoio. A obra herda o nível de visibilidade da base na
criação e nunca pode ser menos restritiva. Países `high_risk` fazem uma base
nascer `confidential`; nesse nível a validação e a constraint do PostgreSQL
impedem latitude e longitude.

## Entregáveis e avanço

`SiteSurvey` registra visita, achados e recomendações com Action Text. Rascunho
não entra na consulta pública; a submissão exige achados com texto visível.

`ProgressReport` é um log de eventos. O resumo é obrigatório na submissão, o
percentual é limitado a 0–100 no modelo e no banco, e um relatório aprovado é
imutável. Apenas o relatório aprovado mais recente atualiza o cache
`projects.physical_progress`; a consulta `latest_per_project` usa
`DISTINCT ON` do PostgreSQL para escolher o desempate pelo id sem N+1.

## Pessoas e fotos

`ProjectParticipation` guarda o papel no contexto da obra, permitindo papéis
distintos para a mesma pessoa. Convites não concedem `effective_role`; somente
coordenador e líder técnico podem enviar relatório de avanço.

Fotos de projeto e a capa da base passam por `ScrubbedPhoto`, que remove EXIF
antes do blob ser armazenado. O servidor aceita somente JPEG, PNG e WebP até
10 MB. A foto original permanece preservada no blob, `variant_for` oferece as
larguras 480/960/1440 e `card_variant` oferece recorte 16:9;
as URLs passam pela entrega autorizada e consultam a visibilidade da obra
associada, inclusive quando o anexo está em relatório ou levantamento.

O seed de desenvolvimento fica em `db/seeds/development/field.rb`: ele cria
uma massa pequena e determinística, por chaves naturais, e pode ser executado
mais de uma vez.
