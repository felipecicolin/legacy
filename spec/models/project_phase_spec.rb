# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectPhase do
  subject(:phase) { build(:project_phase) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:budget_lines).dependent(:nullify) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_numericality_of(:weight).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:physical_progress).is_in(0..100) }
  it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }

  it "exposes the physical progress as the stage progress" do
    expect(phase.progress).to eq(phase.physical_progress)
  end
end
