# frozen_string_literal: true

require "rails_helper"

RSpec.describe Country do
  describe "the code" do
    it "refuses a code that is not two uppercase letters" do
      expect(build(:country, iso_code: "bra")).not_to be_valid
    end

    it "refuses an alpha-3 code that is not three uppercase letters" do
      expect(build(:country, iso3_code: "BR")).not_to be_valid
    end

    it "refuses a second country with the same code" do
      create(:country, iso_code: "XX")

      expect(build(:country, iso_code: "XX")).not_to be_valid
    end
  end

  describe "the currency" do
    it "refuses what is not an ISO 4217 code" do
      expect(build(:country, currency_code: "dolar")).not_to be_valid
    end

    # Território sem moeda própria é caso legítimo, e a coluna é anulável por
    # isso — mas o que estiver lá tem de ser um código.
    it "accepts a country without one" do
      expect(build(:country, currency_code: nil)).to be_valid
    end
  end

  describe "the name" do
    it "comes from the locale, not from a column" do
      expect(described_class.new(iso_code: "BR").name).to eq("Brasil")
    end

    # `NO` sem aspas é o booleano `false` em YAML, dos dois lados: na lista
    # curada e na chave do locale. Este é o exemplo que reprova se um dos dois
    # perder as aspas — nenhum outro sinal apareceria.
    it "resolves the code that YAML would read as a boolean" do
      expect(described_class.new(iso_code: "NO").name).to eq("Noruega")
    end
  end

  describe "the default sensitivity" do
    it "is restricted, like everywhere else in the platform" do
      expect(described_class.new.default_sensitivity).to eq("restricted")
    end

    it "refuses a level the concern does not name" do
      expect { build(:country, default_sensitivity: :secret) }.to raise_error(ArgumentError)
    end

    it "refuses a country whose editorial flag was left undecided" do
      expect(build(:country, high_risk: nil)).not_to be_valid
    end

    it "becomes confidential when the country is curated as high risk" do
      expect(create(:country, high_risk: true).default_sensitivity).to eq("confidential")
    end

    # O gancho só aperta. Um país deixar de ser perigoso não é um fato que a
    # edição de uma linha de vocabulário deva afirmar sozinha.
    it "does not loosen again when the flag is cleared" do
      country = create(:country, high_risk: true)

      country.update!(high_risk: false)

      expect(country.default_sensitivity).to eq("confidential")
    end
  end

  describe "the hook a field record hangs on" do
    it "makes a record created in a high risk country be born confidential" do
      country = create(:country, high_risk: true)
      record = SensitiveTestRecord.create!(country:, sensitivity_level: country.default_sensitivity)

      expect(record).to be_confidential
    end

    # Mudança de política é decisão explícita e auditada, nunca efeito colateral
    # de um update de vocabulário: rebaixar retroativamente uma obra já pública
    # aconteceria sem autor, sem justificativa e sem linha de auditoria.
    it "does not reach a record already saved when the flag changes" do
      country = create(:country)
      record = SensitiveTestRecord.create!(country:, sensitivity_level: country.default_sensitivity)

      country.update!(high_risk: true)

      expect(record.reload.sensitivity_level).to eq("restricted")
    end
  end

  describe ".load_vocabulary!" do
    it "loads the curated list" do
      described_class.load_vocabulary!

      expect(described_class.count).to eq(Vocabulary::Catalog.countries.entries.size)
    end

    it "does not duplicate what a previous run already loaded" do
      described_class.load_vocabulary!

      expect { described_class.load_vocabulary! }.not_to change(described_class, :count)
    end

    # `find_or_create_by!` deixaria a curadoria só valer para país novo, e uma
    # linha marcada depois nunca alcançaria o banco já carregado.
    it "reaches the row a previous run had already created" do
      country = create(:country, iso_code: "BR", iso3_code: "BRA", high_risk: true)

      described_class.load_vocabulary!

      expect(country.reload).not_to be_high_risk
    end

    it "keeps the level a previous curation had tightened" do
      country = create(:country, iso_code: "BR", iso3_code: "BRA", high_risk: true)

      described_class.load_vocabulary!

      expect(country.reload.default_sensitivity).to eq("confidential")
    end
  end

  describe "the regions" do
    it "goes away with the country" do
      region = create(:region)

      expect { region.country.destroy }.to change(Region, :count).by(-1)
    end
  end
end
