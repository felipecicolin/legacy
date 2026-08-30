# frozen_string_literal: true

require "rails_helper"

# O vocabulário curado é dado, e dado é a parte da entrega que nenhum linter
# lê. Este spec é o guarda dele, e ele compara os DOIS lados: chave sem rótulo
# reprova, e rótulo sem chave também. É essa dupla checagem que sustenta a
# entrada `{countries,skill_categories,skills}.*` no `ignore_unused` do
# i18n-tasks — a verificação de "chave não usada" foi trocada por uma mais
# forte, não removida. Ver docs/vocabulary.md.
RSpec.describe Vocabulary::Catalog do
  describe "the country vocabulary" do
    let(:entries) { described_class.countries.entries }
    let(:codes) { entries.pluck(:iso_code) }

    it "carries the whole ISO 3166-1 list" do
      expect(codes.size).to eq(249)
    end

    it "has no repeated code" do
      expect(codes.tally.select { |_code, count| count > 1 }).to be_empty
    end

    it "has no repeated alpha-3 code" do
      long_codes = entries.pluck(:iso3_code)

      expect(long_codes.tally.select { |_code, count| count > 1 }).to be_empty
    end

    # `NO`, sem aspas, é o booleano `false` em YAML — e a Noruega sairia do
    # arquivo sem erro nenhum, num carregamento que continua verde.
    it "reads every code as two letters" do
      expect(codes).to all(match(/\A[A-Z]{2}\z/))
    end

    it "reads every alpha-3 code as three letters" do
      expect(entries.pluck(:iso3_code)).to all(match(/\A[A-Z]{3}\z/))
    end

    it "names an ISO 4217 currency for every country" do
      expect(entries.pluck(:currency_code)).to all(match(/\A[A-Z]{3}\z/))
    end

    it "decides the editorial flag on every line" do
      expect(entries.pluck(:high_risk).uniq).to all(be_in([true, false]))
    end

    # A curadoria de `high_risk` é decisão editorial da equipe, tomada com quem
    # conhece o campo. Este exemplo NÃO impede que ela seja feita: ele diz o
    # que vale hoje, e a issue que marcar o primeiro país troca este número
    # junto com a lista — de propósito, para que a mudança apareça no diff.
    it "has no country curated as high risk yet" do
      expect(entries.select { |entry| entry.fetch(:high_risk) }).to be_empty
    end

    it "has a pt-BR label for every code" do
      expect(codes.reject { |code| I18n.exists?("countries.#{code.downcase}") }).to be_empty
    end

    it "has no label without a country" do
      labelled = I18n.t("countries").keys.map { |key| key.to_s.upcase }

      expect(labelled - codes).to be_empty
    end
  end

  describe "the skill vocabulary" do
    let(:entries) { described_class.skills.entries }
    let(:keys) { entries.pluck(:key) }

    it "covers the four categories" do
      expect(entries.pluck(:category).uniq).to match_array(%w[architecture engineering support trade])
    end

    it "has no repeated key" do
      expect(keys.tally.select { |_key, count| count > 1 }).to be_empty
    end

    # Empate de posição faz a ordem da tela depender da ordem do banco, que
    # ninguém escolheu e ninguém percebe mudar.
    it "orders each category without a tie" do
      tied = entries.group_by { |entry| entry.fetch(:category) }
                    .select { |_category, list| list.pluck(:position).uniq.size < list.size }

      expect(tied).to be_empty
    end

    it "has a pt-BR label for every key" do
      expect(keys.reject { |key| I18n.exists?("skills.#{key}") }).to be_empty
    end

    it "has no label without a skill" do
      expect(I18n.t("skills").keys.map(&:to_s) - keys).to be_empty
    end

    it "has a pt-BR label for every category" do
      categories = entries.pluck(:category).uniq

      expect(categories.reject { |name| I18n.exists?("skill_categories.#{name}") }).to be_empty
    end

    it "has no category label without a skill" do
      expect(I18n.t("skill_categories").keys.map(&:to_s) - entries.pluck(:category)).to be_empty
    end
  end
end
