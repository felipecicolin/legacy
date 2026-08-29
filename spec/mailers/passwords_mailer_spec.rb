# frozen_string_literal: true

require "rails_helper"

RSpec.describe PasswordsMailer do
  let(:user) { create(:user, email_address: "fulano@ex.com") }
  let(:mail) { described_class.reset(user) }

  it "addresses the account holder with a translated subject" do
    aggregate_failures do
      expect(mail.to).to eq([user.email_address])
      expect(mail.subject).to eq(I18n.t("passwords_mailer.reset.subject"))
    end
  end

  # Comparar a string do token não serve: `password_reset_token` gera um valor
  # novo a cada chamada, porque carrega a própria expiração. O que interessa é
  # se o link do e-mail RESOLVE de volta para esta conta.
  def token_in(part)
    part.body.to_s[%r{/passwords/([^/]+)/edit}, 1]
  end

  it "carries a link that resolves back to the account, in both parts" do
    aggregate_failures do
      expect(User.find_by_password_reset_token(token_in(mail.html_part))).to eq(user)
      expect(User.find_by_password_reset_token(token_in(mail.text_part))).to eq(user)
    end
  end

  # O prazo é `distance_of_time_in_words`, que a rails-i18n traduz. Quem muda o
  # tempo de vida do token não precisa mexer em locale nenhum.
  it "states the expiry window in Portuguese" do
    expect(mail.text_part.body.to_s).to include("15 minutos")
  end
end
