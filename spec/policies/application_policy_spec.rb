# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(Authorization::Context.anonymous, Object.new) }

  # O default é o contrato: uma policy nova que esqueça de escrever uma regra
  # herda RECUSA. Se este exemplo ficar verde com `true` em algum lugar, o
  # esquecimento passou a conceder acesso — que é o erro que não aparece em
  # teste nenhum, porque a tela simplesmente funciona.
  it "denies every default action" do
    permissions = %i[index? show? create? new? update? edit? destroy?].map { |action| policy.public_send(action) }

    expect(permissions).to all(be(false))
  end

  # `new?` e `edit?` delegam de propósito: uma policy que libera `create?` e
  # esquece de liberar `new?` mostra um formulário que o submit recusa.
  describe "the form actions" do
    subject(:permissive) { permissive_class.new(Authorization::Context.anonymous, Object.new) }

    let(:permissive_class) do
      Class.new(described_class) do
        def create? = true

        def update? = true
      end
    end

    it "makes new? follow create? and edit? follow update?" do
      aggregate_failures do
        expect(permissive.new?).to be(true)
        expect(permissive.edit?).to be(true)
      end
    end
  end
end
