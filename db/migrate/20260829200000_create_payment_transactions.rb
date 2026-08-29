# frozen_string_literal: true

class CreatePaymentTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_transactions do |t|
      t.string :kind, null: false
      t.string :status, null: false

      # Dinheiro é bigint de centavos com a moeda ao lado. Float não
      # representa 0,10 — o erro é invisível numa linha e aparece depois de
      # somar mil.
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "BRL"

      # A referência do nosso lado (a doação, o compromisso) e a do provedor
      # (o comprovante dele). Duas colunas porque são dois donos.
      t.string :reference, null: false
      t.string :provider_reference, null: false

      t.datetime :processed_at
      t.string :failure_reason

      # Padrão `true`: numa instalação de demonstração o silêncio tem de errar
      # para o lado de marcar demais, não para o de exibir dinheiro de mentira
      # como se fosse real.
      t.boolean :simulated, null: false, default: true

      t.timestamps

      t.index :reference
    end
  end
end
