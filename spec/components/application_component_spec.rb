# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent, type: :component do
  describe "#stimulus_controller" do
    it "mirrors the importmap key of the component's Stimulus controller" do
      expect(ButtonComponent.new.stimulus_controller).to eq("button-component")
    end
  end

  describe "#class_merge" do
    it "lets the last of two conflicting utilities win" do
      expect(described_class.new.class_merge("px-4", "px-6")).to eq("px-6")
    end

    it "drops nils instead of leaving holes in the class string" do
      expect(described_class.new.class_merge("flex", nil, "gap-2")).to eq("flex gap-2")
    end
  end

  describe "#validate_inclusion!" do
    it "passes an allowed value through" do
      expect { described_class.new.validate_inclusion!(:size, :md, %i[sm md]) }.not_to raise_error
    end

    it "names the attribute and the allowed set when the value is not allowed" do
      expect { described_class.new.validate_inclusion!(:size, :xxl, %i[sm md]) }
        .to raise_error(ArgumentError, /invalid size :xxl. Allowed: \[:sm, :md\]/)
    end
  end
end
