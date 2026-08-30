# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorPageComponent, type: :component do
  it "rejects an unknown status" do
    expect { described_class.new(status: :gone) }.to raise_error(ArgumentError, /invalid status/)
  end

  described_class::STATUSES.each_key do |status|
    it "renders the #{status} page" do
      render_inline(described_class.new(status:))

      expect(page).to have_css("main")
      expect(page).to have_css("h1")
      expect(page).to have_css("p")
      expect(page).to have_link("Voltar ao início", href: "/")
    end
  end
end
