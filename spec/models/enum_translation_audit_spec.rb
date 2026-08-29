# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnumTranslationAudit do
  # Sem eager load, `descendants` vem vazio no ambiente de teste — o autoload
  # só carrega o que alguém referenciou. É esta linha que separa "nenhum enum
  # sem rótulo" de "nenhum modelo carregado".
  before { Rails.application.eager_load! }

  it "finds every enum label of this repository already translated" do
    models = ApplicationRecord.descendants

    aggregate_failures do
      expect(models).not_to be_empty
      expect(described_class.missing_keys(models)).to be_empty
    end
  end

  # O conjunto real ainda é vazio, então o guarda precisa provar que reprovaria.
  it "reports the key that a model without a label would need" do
    model = Class.new { def self.defined_enums = { "status" => { "draft" => 0 } } }

    expect(described_class.missing_keys([model])).to eq(["statuses.draft"])
  end
end
