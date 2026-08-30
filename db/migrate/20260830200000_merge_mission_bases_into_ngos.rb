# frozen_string_literal: true

# A base missionária deixa de existir como entidade própria: o lugar durável e
# a instituição que responde por ele passam a ser a mesma coisa, a ONG. Ver
# docs/organizations.md.
#
# A migration PRESERVA as bases existentes em vez de exigir recarga do seed: a
# linha vira uma ONG, e os quatro filhos (campanha, envio, necessidade, obra)
# são reapontados pelo mapa de ids. Sem isso, `db:migrate` incremental — o do
# banco de desenvolvimento e o do deploy — deixaria FK apontando para tabela
# que não existe mais.
class MergeMissionBasesIntoNgos < ActiveRecord::Migration[8.1]
  # `ngo` e `mission_agency` perdem o sentido quando a própria entidade é a
  # ONG, e `mission_base` idem: os três caem em `association`, que é o genérico
  # honesto. Os demais são os mesmos de antes, renumerados.
  KIND_FROM_ORGANIZATION = { 0 => 0, 1 => 4, 2 => 5, 3 => 5 }.freeze
  KIND_FROM_BASE = { 0 => 5, 1 => 5, 2 => 1, 3 => 2, 4 => 0, 5 => 3 }.freeze

  # `approved` e `active` eram o mesmo estado com dois nomes, e ficam no mesmo
  # inteiro. `inactive` ganha um valor próprio: base desativada não é
  # organização suspensa, e colapsar as duas apagaria o motivo.
  STATUS_FROM_BASE = { 0 => 0, 1 => 1, 2 => 3 }.freeze

  # `country_id` entra NULÁVEL, e isso é estado de passagem: organização não
  # tinha país, base tinha e obrigatório. A coluna some junto com o resto do
  # vocabulário internacional na migration seguinte — apertá-la aqui só para
  # afrouxar depois seria trabalho para desfazer.
  ABSORBED = %w[address latitude longitude established_on people_served
                country_id region_id sensitivity_level].freeze

  def up
    rename_organizations_to_ngos
    absorb_base_columns
    copy_mission_bases_in
    repoint_children
    repoint_polymorphic_records
    drop_table :mission_bases
    remove_column :ngos, :legacy_mission_base_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_organizations_to_ngos
    rename_table :organizations, :ngos
    rename_column :ngos, :organization_kind, :ngo_kind
    rename_column :ngos, :organization_status, :ngo_status
    remap :ngos, :ngo_kind, KIND_FROM_ORGANIZATION

    %i[memberships partnerships volunteer_engagements volunteer_groups].each do |table|
      rename_column table, :organization_id, :ngo_id
    end
  end

  def absorb_base_columns
    add_column :ngos, :address, :string
    add_column :ngos, :latitude, :decimal, precision: 9, scale: 6
    add_column :ngos, :longitude, :decimal, precision: 9, scale: 6
    add_column :ngos, :established_on, :date
    add_column :ngos, :people_served, :integer
    add_column :ngos, :sensitivity_level, :integer, null: false,
                                          default: Sensitive::LEVELS.fetch(:restricted)
    add_reference :ngos, :country, foreign_key: true, index: false
    add_reference :ngos, :region, foreign_key: true
    add_column :ngos, :legacy_mission_base_id, :bigint

    add_index :ngos, :sensitivity_level
    add_index :ngos, %i[country_id ngo_status]
    add_check_constraint :ngos, Sensitive::PRECISE_LOCATION_CHECK,
                         name: "ngos_confidential_has_no_location"
    add_check_constraint :ngos, "people_served is null or people_served >= 0",
                         name: "ngos_people_served_not_negative"
  end

  # `slug` é único nas duas tabelas separadamente, então a fusão pode colidir.
  # O sufixo é o mesmo desempate que os dois modelos já usavam ao nascer.
  def copy_mission_bases_in
    columns = %w[name slug ngo_kind ngo_status created_at updated_at legacy_mission_base_id] + ABSORBED
    execute(<<~SQL.squish)
      insert into ngos (#{columns.join(', ')})
      select b.name,
             case when exists (select 1 from ngos o where o.slug = b.slug)
                  then b.slug || '-' || substr(md5(b.id::text || b.name), 1, 6) else b.slug end,
             #{case_for('b.base_kind', KIND_FROM_BASE)},
             #{case_for('b.base_status', STATUS_FROM_BASE)},
             b.created_at, b.updated_at, b.id,
             b.address, b.latitude, b.longitude, b.established_on,
             b.people_served, b.country_id, b.region_id, b.sensitivity_level
      from mission_bases b
    SQL
  end

  def repoint_children
    %i[campaigns deployments needs projects].each do |table|
      remove_foreign_key table, :mission_bases
      rename_column table, :mission_base_id, :ngo_id
      execute(<<~SQL.squish)
        update #{table} c set ngo_id = n.id from ngos n where n.legacy_mission_base_id = c.ngo_id
      SQL
      add_foreign_key table, :ngos
    end
  end

  # Texto rico, anexo e auditoria guardam o nome da classe numa coluna. Um
  # `record_type` que continuasse dizendo `MissionBase` viraria associação nula
  # em silêncio — a descrição e a foto da base sumiriam sem erro nenhum.
  def repoint_polymorphic_records
    %w[action_text_rich_texts active_storage_attachments sensitivity_changes].each do |table|
      execute(<<~SQL.squish)
        update #{table} t set record_type = 'Ngo', record_id = n.id
        from ngos n where t.record_type = 'MissionBase' and n.legacy_mission_base_id = t.record_id
      SQL
      execute("update #{table} set record_type = 'Ngo' where record_type = 'Organization'")
    end

    { contributions: :contributor_type, in_kind_donations: :donor_type,
      subscriptions: :subscriber_type }.each do |table, column|
      execute("update #{table} set #{column} = 'Ngo' where #{column} = 'Organization'")
    end
  end

  def remap(table, column, mapping)
    execute("update #{table} set #{column} = #{case_for(column.to_s, mapping)}")
  end

  def case_for(expression, mapping)
    branches = mapping.map { |from, to| "when #{from} then #{to}" }.join(" ")
    "(case #{expression} #{branches} end)"
  end
end
