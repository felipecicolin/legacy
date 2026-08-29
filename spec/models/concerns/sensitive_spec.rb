# frozen_string_literal: true

require "rails_helper"

# O host é o `SensitiveTestRecord` de `spec/support/` — ver o comentário de lá
# sobre por que o concern não ganha um modelo de produção só para o teste.
RSpec.describe Sensitive do
  let(:author) { create(:user) }
  let(:anonymous) { Visibility::Context.anonymous }
  let(:insider) { Visibility::Context.new(clearance: :confidential) }

  def build_record(**attributes)
    SensitiveTestRecord.new(name: "Base do Vale", code: "BV-01", **attributes)
  end

  def promote(record, level:, justification: "Consentimento da equipe local")
    record.promote_visibility!(level:, author:, justification:)
  end

  describe "default level" do
    it "is born restricted without anyone asking" do
      expect(build_record.tap(&:save!).sensitivity_level).to eq("restricted")
    end

    it "rejects a level outside the enum" do
      expect(build_record(sensitivity_level: nil)).not_to be_valid
    end
  end

  describe ".visible_to" do
    before { promote(build_record(code: "PB-01"), level: :public) }

    it "returns only public records for an anonymous context" do
      build_record(code: "RS-01").save!

      expect(SensitiveTestRecord.visible_to(anonymous).pluck(:code)).to eq(["PB-01"])
    end

    it "returns every level a cleared context reaches" do
      build_record(code: "CF-01", sensitivity_level: :confidential).save!

      expect(SensitiveTestRecord.visible_to(insider).count).to eq(2)
    end
  end

  describe ".hidden_from" do
    # É por aqui que o agregado anonimizado por região vai pedir "as outras".
    it "returns the complement of visible_to, still as a relation" do
      build_record(code: "RS-01", region_label: "Norte").save!

      expect(SensitiveTestRecord.hidden_from(anonymous).group(:region_label).count)
        .to eq({ "Norte" => 1 })
    end
  end

  describe "precise location on a confidential record" do
    it "refuses to persist an address" do
      record = build_record(sensitivity_level: :confidential, address: "Rua 3, 40")

      expect { record.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "refuses to persist coordinates" do
      record = build_record(sensitivity_level: :confidential, latitude: -22.9, longitude: -43.1)

      expect(record).not_to be_valid
    end

    it "raises even when validations are skipped" do
      record = build_record(sensitivity_level: :confidential, latitude: -22.9)

      expect { record.save(validate: false) }.to raise_error(Sensitive::PreciseLocationForbidden)
    end

    it "accepts country and region" do
      record = build_record(sensitivity_level: :confidential, country_label: "Alfa",
                            region_label: "Norte")

      expect(record).to be_valid
    end

    it "does not stand in the way of a restricted record" do
      expect(build_record(latitude: -22.9)).to be_valid
    end
  end

  describe "#promote_visibility!" do
    it "refuses a direct update towards a less restrictive level" do
      record = build_record.tap(&:save!)

      expect(record.update(sensitivity_level: :public)).to be(false)
    end

    it "refuses a promotion without justification" do
      record = build_record.tap(&:save!)

      expect { promote(record, level: :public, justification: " ") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows a more restrictive change without any ceremony" do
      record = build_record.tap(&:save!)

      expect(record.update(sensitivity_level: :confidential)).to be(true)
    end

    it "records author, levels and justification" do
      record = build_record.tap(&:save!)
      promote(record, level: :public)

      expect(record.sensitivity_changes.sole)
        .to have_attributes(author:, from_level: "restricted", to_level: "public",
                            justification: "Consentimento da equipe local")
    end

    it "audits a record born less restrictive than the default" do
      record = build_record
      promote(record, level: :public)

      expect(record.sensitivity_changes.sole.from_level).to eq("restricted")
    end

    it "writes nothing when the level did not move" do
      record = build_record.tap(&:save!)
      promote(record, level: :restricted)

      expect(record.sensitivity_changes).to be_empty
    end

    it "does not carry the promotion over to the next save" do
      record = build_record.tap(&:save!)
      promote(record, level: :public)
      record.update!(name: "Outro nome")

      expect(record.sensitivity_changes.count).to eq(1)
    end
  end

  describe "#location_label" do
    subject(:record) do
      build_record(country_label: "Alfa", region_label: "Norte", sensitivity_level: :confidential)
    end

    it "gives only the country to whoever does not reach the record" do
      expect(record.location_label(anonymous)).to eq("Alfa")
    end

    it "gives region and country to whoever reaches it" do
      expect(record.location_label(insider)).to eq("Norte · Alfa")
    end

    it "omits a region the record does not have" do
      record.region_label = nil

      expect(record.location_label(insider)).to eq("Alfa")
    end
  end

  # Spec de vazamento: serializa a coleção como quem não tem acesso e procura
  # na saída o que não pode estar lá. Vale contra bug de view, de export e de
  # log — todos serializam a mesma relação.
  describe "serializing a mixed collection as an outsider" do
    let!(:confidential) do
      build_record(name: "Base de Alfa", code: "CF-99", sensitivity_level: :confidential,
                   country_label: "Alfa").tap(&:save!)
    end
    let!(:restricted) do
      build_record(name: "Base do Norte", code: "RS-77", latitude: -22.9, longitude: -43.1)
        .tap(&:save!)
    end

    before { promote(build_record(name: "Vitrine", code: "PB-01"), level: :public) }

    it "leaks neither name, code nor coordinates" do
      payload = SensitiveTestRecord.visible_to(anonymous).to_json

      expect(payload).to include("Vitrine")
      expect(payload).not_to include(confidential.name, confidential.code, restricted.name,
                                     restricted.code, "-22.9", "-43.1")
    end
  end
end
