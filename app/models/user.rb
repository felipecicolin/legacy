# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # `dependent: :destroy` e não `:nullify`: `profiles.user_id` é NOT NULL, e a
  # FK do banco recusaria a linha órfã de qualquer forma — melhor a cascata
  # acontecer no lugar em que dá para explicá-la.
  has_one :profile, dependent: :destroy

  # `normalizes` em vez de callback à mão: é o que faz a unicidade do índice e
  # a da validação concordarem. Um callback rodaria depois da validação, então
  # "  Fulano@Ex.COM " passaria pelo `validates uniqueness` como string
  # diferente de "fulano@ex.com" e só o índice do banco reprovaria — com uma
  # exceção de driver no lugar de um erro de formulário.
  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  # O `has_secure_password` valida a presença de `password`, que é atributo
  # virtual. A coluna NOT NULL é a `password_digest`, e nada a sustentava —
  # o `database_consistency` reprova exatamente isso.
  validates :password_digest, presence: true
end
