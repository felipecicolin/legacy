# frozen_string_literal: true

# Host concreto para os specs de `Sensitive`. O concern é abstrato de
# propósito — os modelos de obra vêm em issues próprias — e um modelo em
# `app/models/` criado só para o teste passaria a existir de verdade: no
# autoload, no `db/schema.rb` e no `database_consistency`. A tabela nasce e
# morre dentro do banco de teste, que é recriado a cada rodada.
class SensitiveTestRecord < ApplicationRecord
  include Sensitive
end

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.create_table(:sensitive_test_records, force: :cascade) do |t|
        t.string :code
        t.string :country_label
        t.string :name
        t.string :region_label
        t.string :address
        t.decimal :latitude, precision: 9, scale: 6
        t.decimal :longitude, precision: 9, scale: 6
        t.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)
      end
    end
  end
end
