# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(Authorization::Context.anonymous, Object.new) }

  let(:user) { create(:user) }
  let(:profile) { create(:profile, user:) }
  let(:context) { Authorization::Context.for(user) }
  let(:anonymous) { Authorization::Context.anonymous }

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

  def visible_record(code)
    record = SensitiveTestRecord.create!(code:)
    record.promote_visibility!(level: :public, author: create(:user), justification: "Catálogo público")
    record
  end

  def member_policy
    ngo = create(:ngo)
    record = SensitiveTestRecord.create!(code: "PB-03")
    record.define_singleton_method(:ngo) { ngo }
    create(:membership, profile:, ngo:, role: :member, accepted_at: Time.current)
    described_class.new(context, record)
  end

  def admin_policy
    record = SensitiveTestRecord.create!(code: "PB-04", sensitivity_level: :confidential)
    admin = create(:user)
    create(:staff_role, user: admin, staff_level: :admin)
    described_class.new(Authorization::Context.for(admin), record)
  end

  def ngo_visible?(*traits)
    ngo = create(:ngo, *traits)
    described_class.new(anonymous, ngo).send(:visible_record?)
  end

  it "stores the authorization context and record" do
    record = Object.new
    policy = described_class.new(context, record)

    expect(policy).to have_attributes(context:, record:)
  end

  it "allows a signed-in page and refuses an anonymous one" do
    expect(described_class.new(context, :page).access?).to be(true)
    expect(described_class.new(anonymous, :page).access?).to be(false)
  end

  it "allows a public page to everyone" do
    expect(described_class.new(anonymous, :page).public_access?).to be(true)
  end

  it "allows staff-only pages only to staff" do
    expect(described_class.new(context, :page).staff_access?).to be(false)
    user.staff_role = build(:staff_role, user:)
    expect(described_class.new(Authorization::Context.for(user), :page).staff_access?).to be(true)
    expect(described_class.new(anonymous, :page).staff_access?).to be(false)
  end

  it "hides a missing record" do
    expect(described_class.new(context, nil).send(:visible_record?)).to be(false)
  end

  it "refuses a staff threshold without a user" do
    expect(described_class.new(anonymous, :page).send(:staff_at_least?, :admin)).to be(false)
  end

  it "uses the viewer clearance for sensitive records" do
    public_policy = described_class.new(anonymous, visible_record("PB-01"))
    restricted_record = SensitiveTestRecord.create!(code: "PB-02")
    signed_policy = described_class.new(context, restricted_record)

    expect([public_policy.send(:visible_record?), signed_policy.send(:visible_record?)]).to eq([true, true])
  end

  # A ONG deixou de ter caminho próprio aqui. Antes da fusão ela não tinha
  # sensibilidade e por isso respondia pelo estado de aprovação; agora ela tem,
  # e o caminho genérico serve — quem pergunta pelo estado é a `NgoPolicy`.
  it "reads an ngo through the same clearance as any sensitive record" do
    expect([ngo_visible?(:listed), ngo_visible?(:active)]).to eq([true, false])
  end

  it "raises clearance for ngo members and platform admins" do
    expect([member_policy.send(:visible_record?), admin_policy.send(:visible_record?)]).to eq([true, true])
  end

  it "provides a default scope" do
    records = instance_double(ActiveRecord::Relation)
    allow(records).to receive(:all).and_return(records)

    expect(described_class::Scope.new(context, records).resolve).to eq(records)
  end
end
