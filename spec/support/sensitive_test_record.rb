# frozen_string_literal: true

# Host concreto para os specs de `Sensitive`. O concern é abstrato de
# propósito — os modelos de obra vêm em issues próprias — e um modelo em
# `app/models/` criado só para o teste passaria a existir de verdade: no
# autoload, no `db/schema.rb` e no `database_consistency`. A tabela nasce e
# morre dentro do banco de teste, que é recriado a cada rodada.
class SensitiveTestRecord < ApplicationRecord
  include Sensitive
  include ScrubbedPhoto

  # O host carrega a foto pelos mesmos motivos que carrega o nível: os dois
  # mecanismos são abstratos, e é aqui que eles se encontram — a política de
  # entrega pergunta a sensibilidade do registro dono do anexo.
  attaches_scrubbed_photo :photo

  # O modelo de base ainda não existe, e é dele que virá o vínculo de verdade.
  # Aqui o vínculo serve para o spec de `Country` poder afirmar o que interessa
  # sobre o gancho de sensibilidade: que marcar um país como `high_risk` não
  # alcança registro já gravado NAQUELE país.
  belongs_to :country, optional: true
end

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.create_table(:sensitive_test_records, force: :cascade) do |t|
        t.string :code
        # Sem `foreign_key:`: a tabela do host nasce no `before(:suite)`, e uma
        # FK a amarraria à ordem em que as tabelas do schema aparecem.
        t.references :country, index: false
        t.string :country_label
        t.string :name
        t.string :region_label
        t.string :address
        t.decimal :latitude, precision: 9, scale: 6
        t.decimal :longitude, precision: 9, scale: 6
        t.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)

        # A tabela do host reproduz o que toda migration de modelo com o concern
        # tem de declarar — é o que deixa o spec provar que a constraint pega o
        # `update_column`, e não só que a constante existe.
        t.check_constraint Sensitive::PRECISE_LOCATION_CHECK,
                           name: "sensitive_test_records_confidential_has_no_location"
      end
    end
  end
end
