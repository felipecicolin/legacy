# frozen_string_literal: true

require "rails_helper"

RSpec.describe MissionBasePresenter do
  let(:country) { create(:country) }
  let(:mission_base) { create(:mission_base, :located, country: country) }

  def presenter_for(clearance)
    described_class.new(mission_base, Visibility::Context.new(clearance: clearance))
  end

  describe "#precise_location" do
    # A coordenada não é escondida com CSS nem enviada vazia: quem não alcança
    # o registro não recebe o par, e a view não renderiza o elemento.
    it "answers nothing to a reader who does not reach the record" do
      expect(presenter_for(:public).precise_location).to be_nil
    end

    it "answers the pair to a reader who reaches it" do
      expect(presenter_for(:restricted).precise_location)
        .to eq([mission_base.latitude, mission_base.longitude])
    end

    # Base sem coordenada registrada é o caso comum, e ele não pode virar um
    # par de nulos no HTML.
    it "answers nothing when the coordinate was never recorded" do
      mission_base.update!(latitude: nil, longitude: nil)

      expect(presenter_for(:restricted).precise_location).to be_nil
    end
  end

  describe "#photo_caption" do
    let(:project) { create(:project, mission_base: mission_base) }
    let(:photographer) { create(:profile, display_name: "Ana R.") }
    let(:photo) { create(:project_photo, project: project, taken_by: photographer) }

    # A legenda do design system é "data e responsável".
    it "carries the date and the person for a reader who reaches the record" do
      expect(presenter_for(:restricted).photo_caption(photo))
        .to eq("#{I18n.l(photo.taken_on)} · Ana R.")
    end

    # Quem não alcança recebe a data e mais nada: nomear quem esteve lá é o que
    # a política de identidade evita.
    it "carries only the date for a reader who does not" do
      expect(presenter_for(:public).photo_caption(photo)).to eq(I18n.l(photo.taken_on))
    end
  end

  describe "#gallery" do
    it "groups the photos by the project they belong to" do
      project = create(:project, mission_base: mission_base)
      photo = create(:project_photo, project: project)

      expect(presenter_for(:restricted).gallery).to eq(project.id => [photo])
    end

    it "answers nothing for a base whose projects have no photo" do
      create(:project, mission_base: mission_base)

      expect(presenter_for(:restricted).gallery).to be_empty
    end
  end
end
