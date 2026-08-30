# frozen_string_literal: true

# Massa mínima para previews e desenvolvimento local. Os nomes são
# deliberadamente fictícios; a camada de campanha chega com o modelo de #48.
module DevelopmentFieldSeed
  module_function

  def run
    countries = seed_countries
    profiles = seed_profiles
    bases = seed_bases(countries)
    seed_projects(bases, profiles)
  end

  def seed_countries
    codes = %w[BR PT US]
    countries = codes.index_with { |code| Country.find_by!(iso_code: code) }
    countries.fetch("US").update!(high_risk: true)
    countries
  end

  def seed_profiles
    Array.new(10) do |number|
      user = User.find_or_initialize_by(email_address: "seed-person-#{number + 1}@example.test")
      user.password = "seed-password-123" if user.new_record?
      user.save!
      Profile.find_or_create_by!(user:) { |profile| profile.legal_name = "Pessoa Fictícia #{number + 1}" }
    end
  end

  def seed_bases(countries)
    definitions = {
      "Base Aurora" => countries.fetch("BR"),
      "Base Horizonte" => countries.fetch("PT"),
      "Base Neblina" => countries.fetch("US"),
      "Base Semente" => countries.fetch("BR"),
    }
    definitions.map { |name, country| seed_base(name, country) }
  end

  def seed_base(name, country)
    base = MissionBase.find_or_initialize_by(slug: name.parameterize)
    base.assign_attributes(name:, kind: :mission_base, country:, status: :active)
    base.latitude, base.longitude = coordinates(country)
    base.save!
    base
  end

  def coordinates(country)
    return [-23.55, -46.63] if country.iso_code == "BR"

    [nil, nil]
  end

  def seed_projects(bases, profiles)
    statuses = %i[surveying in_progress paused urgent completed surveying]
    statuses.each_with_index.map { |target, index| seed_project(bases, profiles, target, index) }
  end

  def seed_project(bases, profiles, target, index)
    base = bases.fetch(index % bases.length)
    project = Project.find_or_initialize_by(title: "Obra Fictícia #{index + 1}")
    project.mission_base = base
    project.save!
    seed_coordinator(project, profiles.fetch(index))
    advance_project(project, target)
    project
  end

  def seed_coordinator(project, profile)
    ProjectParticipation.find_or_create_by!(project:, profile:, role: :coordinator) do |record|
      record.started_on = 3.months.ago.to_date
      record.status = :active
    end
  end

  def advance_project(project, target)
    return if project.status == target.to_s

    project.transition_to!(:in_progress) if project.surveying?
    project.transition_to!(:paused) if target == :paused
    project.transition_to!(:urgent) if target == :urgent
    project.transition_to!(:completed) if target == :completed
  end
end

DevelopmentFieldSeed.run
