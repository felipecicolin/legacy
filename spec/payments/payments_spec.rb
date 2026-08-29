# frozen_string_literal: true

require "rails_helper"

# As duas invariantes da fronteira. Nenhuma é sobre uma classe: são sobre o
# repositório inteiro, e por isso vivem aqui, no spec da namespace.
RSpec.describe Payments do
  # Nenhum dado de instrumento de pagamento, em nenhuma tabela. A demo não
  # coleta o que a demo não usa, e o que não é coletado não vaza — nem em dump,
  # nem em log, nem em backup esquecido. Tokens inteiros, e não substring:
  # `pan` casaria com metade do dicionário.
  let(:forbidden_column_tokens) { %w[card cartao cvv cvc pan holder titular iban] }
  let(:domain_dirs) { %w[app/models app/controllers app/views app/components] }

  let(:domain_files) do
    domain_dirs.flat_map { |dir| Rails.root.glob("#{dir}/**/*") }.select(&:file?)
  end

  let(:instrument_columns) do
    connection = ActiveRecord::Base.connection
    connection.tables.flat_map do |table|
      connection.columns(table).map(&:name).filter_map do |column|
        "#{table}.#{column}" if column.split("_").intersect?(forbidden_column_tokens)
      end
    end
  end

  describe "the boundary" do
    # Um provedor concreto citado pelo nome no domínio é a fronteira furada: a
    # partir daí, trocar o simulador pelo gateway real vira busca e
    # substituição em N arquivos, e o `if demo?` volta.
    it "keeps the concrete provider out of the domain" do
      offenders = domain_files.select { |path| path.read.include?("SimulatedProvider") }

      expect(offenders).to be_empty,
                           "provedor concreto citado em #{offenders.join(', ')} — fale com Payments::Gateway"
    end

    # A defesa contra o spec que passa por não ler nada: um glob apontado para
    # o lugar errado acha zero arquivos e fica verde para sempre.
    it "actually reads the domain files" do
      expect(domain_files.size).to be > 10
    end
  end

  describe "the schema" do
    it "has no column that suggests a payment instrument" do
      expect(instrument_columns).to be_empty,
                                    "coluna com cara de instrumento de pagamento: #{instrument_columns.join(', ')}"
    end

    it "actually reads the schema" do
      expect(ActiveRecord::Base.connection.tables).to include("payment_transactions")
    end
  end
end
