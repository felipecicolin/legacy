# frozen_string_literal: true

require "rails_helper"

RSpec.describe Session do
  it { is_expected.to belong_to(:user) }
end
