# frozen_string_literal: true

require "rails_helper"

TABLE_ROW = Data.define(:code, :name, :status)

RSpec.describe TableComponent, type: :component do
  let(:rows) do
    [TABLE_ROW.new(code: "OB-001", name: "Centro comunitário", status: "in_progress"),
     TABLE_ROW.new(code: "OB-002", name: "Biblioteca local", status: "completed")]
  end

  def render_table(table_rows = rows)
    render_inline(described_class.new(rows: table_rows, caption: "Obras cadastradas",
                                      data: { turbo_frame: "results" })) { |table| add_columns(table) }
  end

  it "delegates empty rows to EmptyStateComponent" do
    render_table([])

    expect(page).to have_css("section h2", text: "Nenhum registro encontrado")
    expect(page).to have_no_table
  end

  it "renders the same rows as an accessible table and mobile cards" do
    render_table

    expect(page).to have_css("caption", text: "Obras cadastradas")
    expect(page).to have_css("th[scope='col']", count: 3)
    expect_table_rows
  end

  it "marks only ordered columns with aria-sort" do
    render_table

    expect(page).to have_css("th[aria-sort='ascending']", count: 1)
    expect(page).to have_css("th:not([aria-sort])", count: 1)
    expect(page).to have_css("th[aria-sort='descending']", count: 1)
  end

  it "rejects a column alignment outside the contract" do
    expect do
      render_inline(described_class.new(rows: rows, caption: "Obras")) do |table|
        table.with_column(header: "Código", align: :justify, &:code)
      end
    end.to raise_error(ArgumentError, /invalid align/)
  end

  private

  def add_columns(table)
    table.with_column(header: "Código", align: :right,
                      sort: { href: "/obras?sort=code", direction: "ascending" }, &:code)
    table.with_column(header: "Obra", align: "center", sort: "/obras?sort=name", &:name)
    table.with_column(header: "Situação", sort: "descending") do |row|
      vc_test_view_context.render(StatusBadgeComponent.new(status: row.status))
    end
  end

  def expect_table_rows
    expect(page).to have_css("tbody tr", count: 2)
    expect_table_cell_content
    expect_mobile_cards
    expect(page).to have_css("a[href='/obras?sort=code'][data-turbo-frame='results']")
  end

  def expect_table_cell_content
    expect(page).to have_css("tbody td.tabular-nums.text-right", text: "OB-001")
    expect(page).to have_css("tbody td", text: "Em obra")
  end

  def expect_mobile_cards
    expect(page).to have_css("dl", count: 2)
    expect(page).to have_css("dl dt", text: "Código", count: 2)
  end
end
