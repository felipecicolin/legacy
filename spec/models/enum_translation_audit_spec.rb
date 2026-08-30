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

  # O enum falso NÃO pode se chamar `status`: `statuses.draft` é o exemplo
  # canônico do docs/i18n.md, e o dia em que o primeiro modelo trouxer essa
  # chave para o locale o `I18n.exists?` passaria a devolver true e este
  # exemplo ficaria vermelho sem nada estar quebrado — convidando quem for
  # consertar a apagar justamente a única prova de que a auditoria reprova.
  # `absent_status` mantém o plural irregular (`-us` → `-uses`) e nunca vira
  # chave de produto.
  it "reports the key that a model without a label would need" do
    model = Class.new { def self.defined_enums = { "absent_status" => { "never_translated" => 0 } } }

    expect(described_class.missing_keys([model])).to eq(["absent_statuses.never_translated"])
  end
end
