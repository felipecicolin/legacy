# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfilePresenter do
  subject(:presenter) do
    described_class.new(profile, role_label: "responsável técnico", subject: base)
  end

  let(:profile) { create(:profile, legal_name: "Maria Documento", display_name: "Maria S.") }
  let(:anonymous) { Visibility::Context.anonymous }
  let(:insider) { Visibility::Context.new(clearance: :confidential) }
  let(:base) { SensitiveTestRecord.new(name: "Base do Vale", sensitivity_level: :confidential) }

  describe "#name_for" do
    it "gives the role without a name when the reader cannot identify" do
      expect(presenter.name_for(anonymous)).to eq("responsável técnico")
    end

    it "gives the public name when the reader reaches the record" do
      expect(presenter.name_for(insider)).to eq("Maria S.")
    end

    # O nome do documento não aparece nem para quem alcança: quem o vê é staff
    # autorizado, por outra porta. Ver docs/identity.md.
    it "never gives the legal name" do
      expect(presenter.name_for(insider)).not_to eq("Maria Documento")
    end
  end

  describe "#caption_for" do
    let(:taken_on) { Date.new(2026, 3, 12) }

    it "keeps only the date when the reader cannot identify" do
      expect(presenter.caption_for(anonymous, taken_on: taken_on)).to eq("12/03/2026")
    end

    # O responsável SAI inteiro, e não vira rótulo de papel: numa legenda o
    # papel estreita o conjunto de quem pode ter tirado a foto.
    it "does not fall back to the role label" do
      expect(presenter.caption_for(anonymous, taken_on: taken_on)).not_to include("responsável")
    end

    it "names the person when the reader reaches the record" do
      expect(presenter.caption_for(insider, taken_on: taken_on)).to eq("12/03/2026 · Maria S.")
    end
  end
end
