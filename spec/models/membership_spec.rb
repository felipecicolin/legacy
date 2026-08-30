# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership do
  subject(:membership) { build(:membership) }

  it { is_expected.to belong_to(:profile) }
  it { is_expected.to belong_to(:ngo) }

  it "refuses a second membership for the same pair" do
    existing = create(:membership)

    expect(build(:membership, profile: existing.profile, ngo: existing.ngo)).not_to be_valid
  end

  # A validação acima é ergonomia; quem garante a unicidade sob concorrência é
  # o índice, e por isso este exemplo passa por cima dela.
  it "lets the database refuse the duplicate pair" do
    existing = create(:membership)
    duplicate = build(:membership, profile: existing.profile, ngo: existing.ngo)

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "the last owner" do
    it "cannot be removed" do
      owner = create(:membership, role: :owner)

      expect { owner.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end

    it "cannot be demoted" do
      owner = create(:membership, role: :owner)
      owner.role = :member

      expect(owner).not_to be_valid
    end

    it "explains the refusal in pt-BR" do
      owner = create(:membership, role: :owner)
      owner.role = :member
      owner.validate

      expect(owner.errors.full_messages).to eq(["A ONG precisa de pelo menos um proprietário."])
    end

    # `destroy_all` na associação instancia cada registro e chama `destroy!`, e
    # é por isso que a remoção em massa reprova em vez de passar por baixo.
    # `delete_all` continua fora do alcance — ver docs/ngos.md.
    it "survives a mass removal" do
      owner = create(:membership, role: :owner)

      expect { owner.ngo.memberships.destroy_all }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end

    # Apagar a organização inteira é a exceção: a posse vai junto com a coisa
    # possuída, e recusar seria impedir de apagar a própria organização.
    it "goes away with the ngo" do
      owner = create(:membership, role: :owner)

      expect { owner.ngo.destroy }.to change(described_class, :count).by(-1)
    end

    # A cascata que vem de `Profile` também marca `destroyed_by_association`, e
    # tratá-la como isenta deixaria uma organização viva sem dono. Aqui a
    # recusa volta como `false` e desfaz a transação inteira — a mensagem fica
    # no vínculo, não na pessoa; ver docs/ngos.md.
    it "keeps the person who holds it from being erased" do
      owner = create(:membership, role: :owner)

      expect { owner.profile.destroy }.not_to change(Profile, :count)
    end

    # A pessoa continua, mas a organização perde o dono do mesmo jeito — e este
    # caminho não passa por `role`: com o papel intacto, `role_changed?` é
    # falso e uma guarda que só perguntasse por ele deixaria a gravação passar.
    # A asserção é pelo TIPO do erro, e não por `update` ter voltado `false`:
    # um `false` sozinho passaria igual se quem recusasse fosse outra validação
    # qualquer, e a guarda do owner tivesse parado de disparar em silêncio.
    it "cannot be moved to another ngo" do
      owner = create(:membership, role: :owner)
      owner.ngo = create(:ngo)
      owner.validate

      expect(owner.errors).to be_of_kind(:base, :last_owner)
    end

    # E a contagem tem de sair da organização de ORIGEM: saindo de
    # `ngo`, esta gravação contaria o owner do DESTINO e passaria,
    # deixando a de origem sem nenhum.
    it "cannot be moved into an ngo that has an owner of its own" do
      owner = create(:membership, role: :owner)
      destination = create(:membership, role: :owner).ngo
      owner.attributes = { ngo: destination, role: :member }

      expect(owner).not_to be_valid
    end

    # Limpar `ngo_id` num PATCH levantava `NoMethodError` no meio do
    # request: a validação de presença do `belongs_to` registra o erro, mas não
    # interrompe as outras validações, e a guarda ia buscar `nil.memberships`.
    it "turns a cleared ngo into a form error" do
      owner = create(:membership, role: :owner)

      expect(owner.update(ngo: nil, role: :member)).to be(false)
    end

    # Aceitar o convite é a gravação mais comum do vínculo, e não mexe em papel
    # nem em organização: a guarda não pode esbarrar nela.
    it "still accepts its own invitation" do
      owner = create(:membership, role: :owner)

      expect(owner.update(accepted_at: Time.current)).to be(true)
    end
  end

  describe "an owner with company" do
    it "can be moved away" do
      owner = create(:membership, role: :owner)
      create(:membership, role: :owner, ngo: owner.ngo)

      expect(owner.update(ngo: create(:ngo))).to be(true)
    end

    it "can be removed" do
      owner = create(:membership, role: :owner)
      create(:membership, role: :owner, ngo: owner.ngo)

      expect { owner.destroy! }.to change(described_class, :count).by(-1)
    end

    it "can be demoted" do
      owner = create(:membership, role: :owner)
      create(:membership, role: :owner, ngo: owner.ngo)
      owner.update!(role: :member)

      expect(owner).to be_member
    end
  end

  it "removes a membership that owns nothing" do
    plain = create(:membership, role: :member)

    expect { plain.destroy! }.to change(described_class, :count).by(-1)
  end

  # A guarda olha o papel ANTERIOR: promover alguém a owner muda o papel sem
  # tirar owner nenhum da organização, e não tem por que reprovar.
  it "promotes a member to owner" do
    plain = create(:membership, role: :member)
    plain.update!(role: :owner)

    expect(plain).to be_owner
  end

  it "goes away with a person who owns nothing" do
    plain = create(:membership, role: :member)

    expect { plain.profile.destroy }.to change(described_class, :count).by(-1)
  end

  describe "a pending invitation" do
    it "grants no role at all" do
      expect(build(:membership, role: :owner).effective_role).to be_nil
    end

    it "answers that it is pending" do
      expect(build(:membership)).to be_pending
    end

    # Escopado à organização, e não à tabela: a asserção fica mais forte — o
    # escopo tem de separar os dois vínculos de uma MESMA organização — e não
    # depende de a tabela estar vazia, que é estado global entre exemplos.
    it "is listed apart from the accepted ones" do
      invited = create(:membership)
      create(:membership, :accepted, ngo: invited.ngo)

      expect(invited.ngo.memberships.pending).to contain_exactly(invited)
    end
  end

  describe "an accepted membership" do
    it "grants the role it carries" do
      expect(build(:membership, :accepted, role: :owner).effective_role).to eq("owner")
    end

    it "answers that it was accepted" do
      expect(build(:membership, :accepted)).to be_accepted
    end

    it "is listed apart from the pending ones" do
      joined = create(:membership, :accepted)
      create(:membership, ngo: joined.ngo)

      expect(joined.ngo.memberships.accepted).to contain_exactly(joined)
    end
  end

  it "shows the role through the pt-BR vocabulary" do
    expect(build(:membership, role: :representative).role_label).to eq("Representante")
  end
end
