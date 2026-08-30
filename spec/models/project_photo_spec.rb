# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectPhoto do
  subject(:photo) { build(:project_photo) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:progress_report).optional }
  it { is_expected.to belong_to(:taken_by).class_name("Profile").optional }
  it { is_expected.to have_one_attached(:image) }

  it "exposes the three responsive widths" do
    expect(ProjectPhoto::VARIANT_WIDTHS).to eq([480, 960, 1440])
    expect(photo.variant_for(960)).to respond_to(:processed)
  end

  it "requires an image and accepts a scrubbed image" do
    photo.image.detach
    expect(photo).not_to be_valid
    photo.image.attach(GeotaggedPhoto.upload)

    expect(photo).to be_valid
  end

  it "rejects unsupported content types and oversized blobs" do
    photo.image.detach
    expect do
      photo.image.attach(io: StringIO.new("bytes"), filename: "arquivo.txt", content_type: "text/plain")
    end.to raise_error(ExifScrubber::Unsupported)
  end

  it "rejects a report belonging to another project" do
    photo.progress_report = create(:progress_report)
    expect(photo).not_to be_valid
  end

  it "keeps the project as its attachment visibility subject and builds a card crop" do
    expect(photo.visibility_subject).to eq(photo.project)
    expect(photo.category_label).to eq("Antes")
    expect(photo.card_variant).to respond_to(:processed)
  end

  it "rejects an attachment with an unsupported content type" do
    photo.image.blob.update!(content_type: "text/plain")

    expect(photo).not_to be_valid
  end

  it "rejects an attachment that is too large" do
    photo.image.blob.update!(byte_size: ProjectPhoto::MAX_FILE_SIZE + 1)

    expect(photo).not_to be_valid
  end
end
