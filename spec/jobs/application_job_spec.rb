# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationJob do
  it "is the Active Job base every job inherits from" do
    expect(described_class.superclass).to eq(ActiveJob::Base)
  end

  it "enqueues onto the configured adapter" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
  end
end
