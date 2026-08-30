# frozen_string_literal: true

require "rails_helper"

RSpec.describe VolunteerGroup do
  describe "the availability window" do
    let(:today) { Date.current }

    # Grupo sem data declarada é o que ainda está combinando quando vai.
    # Excluí-lo do matching o tornaria invisível justamente para quem poderia
    # convidá-lo.
    it "treats an undeclared window as always available" do
      group = build(:volunteer_group, available_from: nil, available_until: nil)

      expect(group.available_on?(today)).to be(true)
    end

    it "answers for each side of a declared window" do
      group = build(:volunteer_group, available_from: today, available_until: today + 10)
      answers = [today - 1, today, today + 5, today + 11].map { |date| group.available_on?(date) }

      expect(answers).to eq([false, true, true, false])
    end

    it "refuses a window that ends before it starts" do
      expect(build(:volunteer_group, available_from: today, available_until: today - 1)).not_to be_valid
    end

    it "refuses a window that ends before it starts in the database too" do
      group = create(:volunteer_group, available_from: today, available_until: today + 1)
      corrupt = "update volunteer_groups set available_until = available_from - 1 where id = #{group.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /window_ends_after_it_starts/)
    end
  end

  describe ".available_on" do
    let(:today) { Date.current }

    it "finds a group whose window covers the date" do
      covering = create(:volunteer_group, :available, available_from: today - 1, available_until: today + 1)

      expect(described_class.available_on(today)).to contain_exactly(covering)
    end

    it "finds a group with no window declared" do
      open_ended = create(:volunteer_group, :available)

      expect(described_class.available_on(today)).to contain_exactly(open_ended)
    end

    # O grupo cuja janela não cobre a data não aparece no matching, e é isso
    # que impede convidar quem já avisou que não pode.
    it "leaves out a group whose window closed before the date" do
      create(:volunteer_group, :available, available_until: today - 1)

      expect(described_class.available_on(today)).to be_empty
    end

    it "leaves out a group that is not available yet" do
      create(:volunteer_group, :available, available_from: today + 1)

      expect(described_class.available_on(today)).to be_empty
    end

    it "leaves out a group that is still forming" do
      create(:volunteer_group)

      expect(described_class.available_on(today)).to be_empty
    end
  end

  it "refuses a group of nobody" do
    expect(build(:volunteer_group, expected_size: 0)).not_to be_valid
  end

  it "accepts a group whose size is not known yet" do
    expect(build(:volunteer_group, expected_size: nil)).to be_valid
  end

  it "translates the status to pt-BR and interpolates as its name" do
    group = build(:volunteer_group, :available, name: "Turma da Construtora")

    aggregate_failures do
      expect(group.group_status_label).to eq("Disponível")
      expect(group.to_s).to eq("Turma da Construtora")
    end
  end
end
