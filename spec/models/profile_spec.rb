# frozen_string_literal: true

require "rails_helper"

RSpec.describe Profile do
  subject(:profile) { build(:profile) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:legal_name) }

  # `validate_presence_of(:display_name)` não serve aqui: o callback de
  # criação repõe o valor que o matcher acabou de zerar. A regra que importa é
  # esta — depois de criado, o perfil não pode ficar sem nome público.
  it "refuses to blank out the display name later" do
    profile = create(:profile)
    profile.display_name = nil

    expect(profile).not_to be_valid
  end

  it "copies the legal name into the display name on creation" do
    profile = create(:profile, legal_name: "Maria Aparecida de Souza")

    expect(profile.display_name).to eq("Maria Aparecida de Souza")
  end

  # Campo de texto vazio chega do formulário como `""`, e não como `nil`. Um
  # `||=` não enxerga isso: `""` é truthy, o default não corre e o campo que a
  # UI apresenta como opcional reprova a criação inteira.
  it "copies the legal name when the display name arrives blank" do
    profile = create(:profile, legal_name: "Maria Aparecida de Souza", display_name: "")

    expect(profile.display_name).to eq("Maria Aparecida de Souza")
  end

  it "keeps a display name that was given" do
    profile = create(:profile, legal_name: "Maria Aparecida de Souza", display_name: "Cida")

    expect(profile.display_name).to eq("Cida")
  end

  # O nome exibido é armazenado, e não derivado: corrigir o nome legal não
  # pode reescrever retroativamente o histórico já exibido.
  it "does not follow a later change to the legal name" do
    profile = create(:profile, legal_name: "Maria Aparecida de Souza")
    profile.update!(legal_name: "Maria Aparecida de Souza Lima")

    expect(profile.display_name).to eq("Maria Aparecida de Souza")
  end

  it "shows the public name when interpolated" do
    profile = build(:profile, legal_name: "Nome Legal", display_name: "Nome Público")

    expect(profile.to_s).to eq("Nome Público")
  end

  it "keeps the legal name out of the serialized payload" do
    profile = create(:profile, legal_name: "Nome Legal", display_name: "Nome Público")

    expect(profile.to_json).not_to include("Nome Legal")
  end

  # No `serializable_hash` do Active Model o `only:` tem precedência sobre o
  # `except:`, então pedir a coluna pelo nome é justamente o caminho que uma
  # defesa apenas-por-padrão deixaria passar.
  it "keeps the legal name out even when it is asked for by name" do
    profile = create(:profile, legal_name: "Nome Legal")

    expect(profile.as_json(only: [:legal_name])).to eq({})
  end

  it "rejects a second profile for the same person" do
    person = create(:user)
    create(:profile, user: person)

    expect(build(:profile, user: person)).not_to be_valid
  end

  # A validação acima é ergonomia; quem de fato garante a unicidade sob
  # concorrência é o índice. Por isso este exemplo passa por cima dela — e por
  # isso preenche `display_name` à mão: sem validação não roda o callback que
  # o preencheria, e o NOT NULL da coluna dispararia antes do índice.
  it "lets the database refuse a second profile for the same person" do
    person = create(:user)
    create(:profile, user: person)
    duplicate = build(:profile, user: person, display_name: "Cida")

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "goes away with the person" do
    profile = create(:profile)

    expect { profile.user.destroy }.to change(described_class, :count).by(-1)
  end

  # `preferred_locale` e `timezone` são NOT NULL com default, e o
  # `database_consistency` não cobra presença em coluna que tem default. Sem
  # validação, um `nil` vindo de um PATCH atravessa o modelo inteiro e estoura
  # como `ActiveRecord::NotNullViolation` — exceção de driver no meio de um
  # request, em vez de erro de formulário. E `""` passaria e viraria um fuso
  # vazio gravado, que quebra na primeira leitura.
  it "refuses to blank out the preferred locale" do
    profile = create(:profile)
    profile.preferred_locale = nil

    expect(profile).not_to be_valid
  end

  it "refuses to blank out the timezone" do
    profile = create(:profile)
    profile.timezone = ""

    expect(profile).not_to be_valid
  end

  # Com `build` o anexo fica só na memória: `attached?` responde true sem uma
  # única linha gravada, e o exemplo passaria sem provar que as tabelas do
  # Active Storage aguentam a inserção — que é justamente o que a migration
  # deste PR existe para garantir.
  #
  # A foto tem de ser uma imagem de verdade: desde a #24 o anexo passa pelo
  # `ExifScrubber`, que recusa bytes que a libvips não abre. Um "arquivo de
  # foto" que não é foto não tem EXIF para limpar, e aceitá-lo seria gravar
  # metadado nenhum tendo limpado nada.
  it "carries the picture as an Active Storage attachment" do
    profile = create(:profile)
    profile.avatar.attach(GeotaggedPhoto.upload(filename: "foto.jpg"))

    expect(profile.reload.avatar).to be_attached
  end

  # O retrato entra pelo mesmo pipeline da foto de obra: um retrato tirado no
  # celular numa base de país perseguido carrega a coordenada da base.
  it "destroys the EXIF of the picture on the way in" do
    profile = create(:profile)
    profile.avatar.attach(GeotaggedPhoto.upload(filename: "foto.jpg"))

    expect(GeotaggedPhoto.exif_fields(profile.reload.avatar.blob.download)).to be_empty
  end

  # A outra porta de log, a que não passa por serialização nenhuma: `inspect` é
  # o que a linha de exceção e o rastreador de erros imprimem.
  it "keeps the legal name out of inspect" do
    profile = create(:profile, legal_name: "Maria Documento", display_name: "Maria")

    aggregate_failures do
      expect(profile.inspect).to include("[FILTERED]")
      expect(profile.inspect).not_to include("Maria Documento")
    end
  end
end
