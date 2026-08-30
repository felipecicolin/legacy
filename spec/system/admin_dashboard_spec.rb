# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin dashboard" do
  let(:password) { "s3nha-de-teste-longa" }

  # `have_link("Sair")` força o Capybara a esperar o redirecionamento do login
  # terminar antes de devolver o controle — sem isso, um `visit` seguinte pode
  # chegar antes do cookie de sessão estar mesmo gravado. É link, não botão:
  # `ButtonComponent` com `href:` renderiza `<a>`.
  def sign_in_as_staff
    user = create(:user, password: password)
    create(:staff_role, user: user, staff_level: :admin)

    visit new_session_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: password
    click_button "Entrar"

    expect(page).to have_link("Sair")
  end

  it "shows an empty state in every list block on a clean database" do
    sign_in_as_staff
    visit admin_root_path

    expect(page).to have_text("Nenhuma obra em andamento")
    expect(page).to have_text("Nenhum relatório aprovado ainda")
  end

  it "shows no alert strip when nothing is urgent, paused or critical" do
    sign_in_as_staff
    visit admin_root_path

    expect(page).to have_text("Painel do administrador")
    expect(page).to have_no_css("[role='alert']")
  end

  # "Obras em andamento" mostra as quatro obras ainda não concluídas — a
  # concluída fica de fora de propósito, não é a mesma coisa que "sumiu".
  it "shows the four non-completed statuses as cards, and excludes completed work" do
    base = create(:mission_base)
    Project::STATUSES.each_key { |status| create(:project, mission_base: base, status: status) }

    sign_in_as_staff
    visit admin_root_path

    expect(page).to have_css("[role='alert']", text: "obra urgente")
    aggregate_failures do
      ["Levantamento", "Em obra", "Parada", "Urgente"].each { |label| expect(page).to have_text(label) }
      expect(page).to have_no_text("Concluída")
    end
  end

  it "fits the viewport at phone, tablet and desktop widths" do
    sign_in_as_staff

    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit admin_root_path

        fits = page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
        expect(fits).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
