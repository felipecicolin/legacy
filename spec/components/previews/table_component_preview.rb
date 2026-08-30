# frozen_string_literal: true

class TableComponentPreview < ViewComponent::Preview
  Row = Data.define(:code, :name, :status, :progress)

  def default
    render(TableComponent.new(rows: rows, caption: "Obras cadastradas")) { |table| configure_columns(table) }
  end

  private

  def configure_columns(table)
    table.with_column(header: "Código", &:code)
    table.with_column(header: "Obra", &:name)
    add_status_column(table)
    add_progress_column(table)
  end

  def add_status_column(table)
    table.with_column(header: "Situação") do |row|
      render(StatusBadgeComponent.new(status: row.status))
    end
  end

  def add_progress_column(table)
    table.with_column(header: "Avanço", align: :right) do |row|
      render(ProgressBarComponent.new(kind: "physical", value: row.progress))
    end
  end

  def rows
    [Row.new(code: "OB-001", name: "Centro comunitário", status: "in_progress", progress: 62),
     Row.new(code: "OB-002", name: "Biblioteca local", status: "completed", progress: 100)]
  end
end
