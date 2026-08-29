# frozen_string_literal: true

require "rails_helper"

# Este arquivo cobra o miolo do Rails, não as chaves deste repositório: o que a
# `rails-i18n` traz e o que `config/locales/rails.pt-BR.yml` corrige por cima.
# Nenhum dos três linters de i18n enxerga isto — todos leem as nossas chaves —,
# então sem spec um formato errado só aparece na tela.
RSpec.describe I18n do
  let(:helpers) { ActionController::Base.helpers }
  let(:date) { Date.new(2026, 3, 12) }

  it "speaks only the language the product ships" do
    expect(described_class.available_locales).to eq([:"pt-BR"])
  end

  it "formats money as reais" do
    expect(helpers.number_to_currency(18_400_000 / 100.0)).to eq("R$ 184.000,00")
  end

  it "groups thousands with a dot and decimals with a comma" do
    expect(helpers.number_with_delimiter(1_234_567.89)).to eq("1.234.567,89")
  end

  # A precisão 3 do default do Rails sobrevive à rails-i18n, então 62 sairia
  # "62,000%". `strip_insignificant_zeros` encurta o inteiro sem arredondar o
  # quebrado, que um `precision: 0` perderia.
  it "writes percentages without trailing zeros" do
    aggregate_failures do
      expect(helpers.number_to_percentage(62)).to eq("62%")
      expect(helpers.number_to_percentage(62.5)).to eq("62,5%")
    end
  end

  it "writes dates in the short and the long Brazilian form" do
    aggregate_failures do
      expect(described_class.l(date)).to eq("12/03/2026")
      expect(described_class.l(date, format: :long)).to eq("12 de março de 2026")
    end
  end

  it "measures elapsed time in Portuguese" do
    expect(helpers.distance_of_time_in_words(90.days)).to eq("3 meses")
  end

  # Duas metades diferentes: a mensagem vem da rails-i18n, o nome do campo vem
  # de `config/locales/models/pt-BR.yml`. Sem a segunda a frase sai meio em
  # inglês ("Email address não pode ficar em branco").
  it "names both the attribute and the failure in Portuguese" do
    user = User.new
    user.validate

    expect(user.errors.full_messages_for(:email_address)).to eq(["E-mail não pode ficar em branco"])
  end
end
