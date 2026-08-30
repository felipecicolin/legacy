# frozen_string_literal: true

require "rails_helper"

# A tela que fecha o produto: sem ela a plataforma mostra obras e não conecta
# ninguém. Ver docs/mobilization.md.
RSpec.describe "Volunteer view" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password: password) }
  let(:profile) { create(:profile, user: user) }
  let(:mission_base) { create(:mission_base, :active) }

  def sign_in(as = user)
    post session_path, params: { email_address: as.email_address, password: password }
  end

  describe "someone who signed in without a profile" do
    # Entrar não é ter perfil. Quem chegou sem um precisa de caminho, não de
    # lista vazia.
    it "is offered a way to create one" do
      sign_in

      get needs_path

      expect(response.body).to include(I18n.t("needs.no_profile.empty_title"))
    end
  end

  describe "someone with no skill registered" do
    # Sem habilidade não há casamento possível, e dizer isso é diferente de
    # mostrar lista vazia.
    it "is told that is what is missing" do
      profile
      sign_in

      get needs_path

      expect(response.body).to include(I18n.t("needs.index.no_skills_title"))
    end
  end

  describe "the matching" do
    let(:skill) { create(:skill) }

    before do
      create(:profile_skill, profile: profile, skill: skill)
      sign_in
    end

    it "shows a need that asks for a skill the person has" do
      wanted = create(:need, mission_base: mission_base, need_kind: :skill, skill: skill)

      get needs_path

      expect(response.body).to include(wanted.title)
    end

    # A que ele não pode ver não aparece nem como negada.
    it "leaves out a need the person cannot reach" do
      hidden_base = create(:mission_base, :active, country: create(:country, high_risk: true))
      hidden = create(:need, mission_base: hidden_base, need_kind: :skill, skill: skill, title: "Escondida")

      get needs_path

      expect(response.body).not_to include(hidden.title)
    end
  end

  describe "a need that asks for a professional registration" do
    let(:gated) { create(:need, :skilled, mission_base: mission_base, requires_professional_registration: true) }

    before do
      profile
      sign_in
    end

    # O requisito ANTES da tentativa: quem não tem registro verificado precisa
    # saber que é isso que trava, e não descobrir por erro de formulário depois
    # de escrever a motivação.
    it "says so on the need page, before anyone tries" do
      get need_path(gated)

      expect(response.body).to include(I18n.t("candidacies.form.requires_credential"))
    end

    it "refuses the candidacy with a message, not an exception" do
      post need_candidacy_path(gated), params: { candidacy: { motivation: "<div>Quero servir.</div>" } }

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("candidacies.form.title"))
      end
    end
  end

  # É o caso de corrida do abatimento chegando à interface: a vaga acabou entre
  # a renderização do formulário e o envio.
  describe "a need whose last slot went while the form was open" do
    let(:need) { create(:need, mission_base: mission_base, quantity: 1) }

    before do
      profile
      sign_in
    end

    it "answers with a message instead of a server error" do
      need.fulfill(source: create(:assignment), quantity: 1)

      post need_candidacy_path(need), params: { candidacy: { motivation: "<div>Quero servir.</div>" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # O formulário vive num frame próprio: candidatar-se não recarrega a página, e
  # o erro de vaga esgotada volta para dentro dele. É fato de marcação, e por
  # isso é verificado aqui — não precisa de navegador para ser verdade.
  describe "the candidacy form" do
    # Assinado, porque `restricted` é o default de uma necessidade e o leitor
    # anônimo para em `public`: sem sessão a resposta é 404 de corpo vazio, que
    # é o comportamento certo e não o que este exemplo mede.
    before do
      profile
      sign_in
    end

    it "is wrapped in its own turbo frame" do
      need = create(:need, mission_base: mission_base)

      get need_path(need)

      expect(response.body).to include(%(<turbo-frame id="candidacy">))
    end
  end

  describe "a candidacy that goes through" do
    before do
      profile
      sign_in
    end

    it "shows up in the person's list afterwards" do
      need = create(:need, mission_base: mission_base)

      post need_candidacy_path(need), params: { candidacy: { motivation: "<div>Quero servir.</div>" } }
      get needs_path

      expect(response.body).to include(need.title)
    end
  end
end
