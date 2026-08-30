# frozen_string_literal: true

# Bases e obras suficientes para a trilha de frontend abrir um preview com
# conteúdo e para a de dados ter linha em que agregar.
#
# Idempotente por chave natural (`slug` da base, `title` da obra dentro dela) e
# determinístico: nada de `rand` sem semente, porque demo que muda a cada carga
# é demo que não dá para ensaiar. Datas relativas a hoje, senão a demo
# envelhece e todas as obras ficam no passado. Ver docs/field.md.
module DevelopmentSeeds
  module Field
    # Um dos três é `high_risk`, e é ele que prova a política de sensibilidade
    # funcionando sozinha: a base criada nele nasce `confidential` e some da
    # listagem anônima sem ninguém marcar nada.
    COUNTRIES = [
      { iso_code: "XA", iso3_code: "XAA", high_risk: false },
      { iso_code: "XB", iso3_code: "XBB", high_risk: false },
      { iso_code: "XC", iso3_code: "XCC", high_risk: true },
    ].freeze

    BASES = [
      { slug: "vale-verde", name: "ONG do Vale Verde", ngo_kind: :association, country: "XA", public: true },
      { slug: "escola-aurora", name: "Escola Aurora", ngo_kind: :school, country: "XA" },
      { slug: "clinica-do-porto", name: "Clínica do Porto", ngo_kind: :clinic, country: "XB" },
      { slug: "casa-norte", name: "Casa Norte", ngo_kind: :housing, country: "XC" },
      # Sem obra nenhuma, e aberta ao público de propósito: é o caso que
      # motivou separar ONG de obra, e a tela de detalhe (#53) existe para
      # provar que ele renderiza completo. Um seed sem ele deixaria a prova
      # dependendo de alguém montar o caso à mão.
      { slug: "casa-do-rio", name: "Casa do Rio", ngo_kind: :association, country: "XB", public: true },
    ].freeze

    # Os cinco estados aparecem, porque é a listagem com os cinco lado a lado
    # que prova o `StatusBadgeComponent`. `surveying` é o default e não se
    # declara; os demais chegam por transição, que é o caminho real.
    PROJECTS = [
      { base: "vale-verde", title: "Reforma do telhado", status: nil },
      { base: "vale-verde", title: "Poço artesiano", status: :in_progress },
      { base: "escola-aurora", title: "Ampliação das salas", status: :paused },
      { base: "escola-aurora", title: "Rede elétrica", status: :urgent },
      { base: "clinica-do-porto", title: "Sala de curativos", status: :completed },
      { base: "casa-norte", title: "Cerca e portão", status: :in_progress },
    ].freeze

    module_function

    NEEDS = [
      { base: "vale-verde", title: "Telhas cerâmicas", need_kind: :material, quantity: 400, urgency: :high },
      { base: "vale-verde", title: "Engenharia estrutural", need_kind: :skill, quantity: 1, urgency: :critical },
      { base: "escola-aurora", title: "Equipe de mutirão", need_kind: :team, quantity: 12, urgency: :normal },
      { base: "clinica-do-porto", title: "Recursos para acabamento", need_kind: :funding, quantity: 1,
        urgency: :low },
      { base: "casa-do-rio", title: "Cimento e areia", need_kind: :material, quantity: 30, urgency: :high },
    ].freeze

    def load!
      countries = COUNTRIES.index_by { |entry| entry.fetch(:iso_code) }.transform_values { |e| upsert_country(e) }
      bases = BASES.index_by { |entry| entry.fetch(:slug) }
                   .transform_values { |entry| upsert_base(entry, countries) }
      PROJECTS.each { |entry| upsert_project(entry, bases) }
      NEEDS.each { |entry| upsert_need(entry, bases) }
    end

    # A necessidade da BASE, e não da obra: é o caso que justifica base e obra
    # serem tabelas diferentes, e o seed precisa mostrá-lo já na primeira carga.
    def upsert_need(entry, bases)
      base = bases.fetch(entry.fetch(:base))
      need = base.needs.find_or_initialize_by(title: entry.fetch(:title))
      need.assign_attributes(entry.except(:base))
      need.skill = curated_skill if entry.fetch(:need_kind) == :skill
      need.save!
    end

    # A camada declara a dependência em vez de supor que o `db/seeds.rb` já
    # carregou o vocabulário: quem chama `load_all!` direto — um spec, o
    # console — não passa por lá, e a necessidade de habilidade nasceria sem
    # habilidade. `load_vocabulary!` é idempotente.
    def curated_skill
      Skill.load_vocabulary! if Skill.none?

      Skill.find_by(key: "structural") || Skill.first!
    end

    def upsert_country(entry)
      Country.find_or_initialize_by(iso_code: entry.fetch(:iso_code)).tap do |country|
        country.update!(entry)
      end
    end

    def upsert_base(entry, countries)
      Ngo.find_or_initialize_by(slug: entry.fetch(:slug)).tap do |base|
        base.country = countries.fetch(entry.fetch(:country))
        base.name = entry.fetch(:name)
        base.ngo_kind = entry.fetch(:ngo_kind)
        base.ngo_status = :active
        base.save!
        open_to_the_public(base) if entry[:public]
      end
    end

    # Uma base aberta, para o contraste ficar visível: sem ela um visitante
    # anônimo enxerga zero e a listagem não prova nada. E a abertura passa pela
    # porta de verdade — `promote_visibility!` exige autor e justificativa, e é
    # o seed exercitando a auditoria em vez de contorná-la.
    def open_to_the_public(base)
      return if base.public?

      base.promote_visibility!(level: :public, author: coordinator_profile.user,
                               justification: "Vitrine da demonstração")
    end

    # A obra chega ao estado por TRANSIÇÃO, e não por atribuição direta: é o
    # caminho que a aplicação usa, e um seed que o contornasse deixaria de
    # exercitar a matriz de transições.
    def upsert_project(entry, bases)
      base = bases.fetch(entry.fetch(:base))
      project = Ngo.find(base.id).projects.find_or_initialize_by(title: entry.fetch(:title))
      project.save! if project.new_record?
      advance(project, entry.fetch(:status))
    end

    # A coordenação entra ANTES de qualquer transição: quase todo caminho passa
    # por `in_progress`, e é ele que exige coordenador. Descobrir isso só na
    # rota que passa por lá deixaria o seed quebrando em metade dos estados.
    def advance(project, status)
      return if status.nil? || project.status == status.to_s

      ensure_coordinator(project)
      route_to(project, status).each { |step| project.update!(status: step) }
    end

    # `in_progress` e `urgent` não são alcançáveis a partir de `surveying` sem
    # passar por outro estado — o caminho é o mesmo que a UI percorre.
    def route_to(project, status)
      return [status] if Project::TRANSITIONS.fetch(project.status).include?(status.to_s)

      [:in_progress, status]
    end

    def ensure_coordinator(project)
      project.project_participations.find_or_create_by!(profile: coordinator_profile, participation_role: :coordinator) do |record|
        record.started_on = 3.months.ago.to_date
        record.participation_status = :active
      end
    end

    # Um perfil de equipe só, reusado: o seed mínimo não precisa de elenco, e
    # inventar dez pessoas aqui competiria com a demonstração de #48.
    def coordinator_profile
      user = User.find_or_create_by!(email_address: "coordenacao@exemplo.test") do |record|
        record.password = SecureRandom.hex(16)
      end
      Profile.find_or_create_by!(user: user) { |record| record.legal_name = "Coordenação de Campo" }
    end
  end
end
