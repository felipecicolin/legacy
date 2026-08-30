# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organization do
  subject(:organization) { build(:organization) }

  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:profiles).through(:memberships) }
  it { is_expected.to validate_presence_of(:name) }

  it "starts out waiting for approval" do
    expect(described_class.new).to be_pending
  end

  it "derives the address from the name" do
    expect(create(:organization, name: "Igreja da Paz").slug).to eq("igreja-da-paz")
  end

  it "keeps an address that was given" do
    expect(create(:organization, slug: "paz").slug).to eq("paz")
  end

  # Campo de texto vazio chega do formulário como `""`, que é truthy — um `||=`
  # deixaria o slug em branco e a criação reprovaria por um campo opcional.
  it "derives the address when the given one arrives blank" do
    expect(create(:organization, name: "Igreja da Paz", slug: "").slug).to eq("igreja-da-paz")
  end

  # Sem o sufixo, a segunda organização de mesmo nome reprovaria no índice
  # único — com um erro sobre um campo que ninguém preencheu.
  it "sets the two organizations of a same name apart" do
    create(:organization, name: "Igreja Betel")
    second = create(:organization, name: "Igreja Betel")

    expect(second.slug).to start_with("igreja-betel-")
  end

  # A URL pública é contrato com quem já a compartilhou. Renomear a
  # organização é normal; mudar o endereço dela não é.
  it "does not follow a later change to the name" do
    organization = create(:organization, name: "Igreja da Paz")
    organization.update!(name: "Igreja da Paz e do Amor")

    expect(organization.slug).to eq("igreja-da-paz")
  end

  it "refuses to change the address of an organization that already exists" do
    organization = create(:organization)

    expect { organization.update!(slug: "outro-endereco") }
      .to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  it "refuses a second organization at the same address" do
    create(:organization, slug: "paz")

    expect(build(:organization, slug: "paz")).not_to be_valid
  end

  # Organização não aprovada não aparece em busca e não recebe doação. Este
  # escopo é o único lugar que decide isso.
  it "shows only the approved organizations" do
    approved = create(:organization, organization_status: :approved)
    create(:organization, organization_status: :pending)
    create(:organization, organization_status: :suspended)

    expect(described_class.visible).to contain_exactly(approved)
  end

  it "refuses a kind that is not in the vocabulary" do
    expect(build(:organization, organization_kind: "ministry")).not_to be_valid
  end

  it "shows the kind through the pt-BR vocabulary" do
    expect(build(:organization, organization_kind: :mission_agency).kind_label).to eq("Agência missionária")
  end

  it "shows the status through the pt-BR vocabulary" do
    expect(build(:organization, organization_status: :suspended).status_label).to eq("Suspensa")
  end

  it "shows the name when interpolated" do
    expect(build(:organization, name: "Igreja da Paz").to_s).to eq("Igreja da Paz")
  end

  it "carries the description as rich text" do
    organization = create(:organization, description: "<div>Obra na fronteira</div>")

    expect(organization.reload.description.to_plain_text).to eq("Obra na fronteira")
  end

  # Com `build` o anexo fica só na memória: `attached?` responderia true sem uma
  # única linha gravada, e nada provaria que as tabelas do Active Storage
  # aguentam a inserção.
  it "carries the logo as an Active Storage attachment" do
    organization = create(:organization)
    organization.logo.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")

    expect(organization.reload.logo).to be_attached
  end
end
