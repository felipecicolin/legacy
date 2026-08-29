# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    # Sequência porque o e-mail é único no banco: dois `create(:user)` no mesmo
    # exemplo levantariam RecordNotUnique em vez de falhar dizendo o porquê.
    sequence(:email_address) { |n| "pessoa#{n}@exemplo.org" }
    password { "s3nha-de-teste-longa" }
  end
end
