# frozen_string_literal: true

namespace :demo do
  desc "Rebuild the demo database and reload its seed"
  task reload_seed: :environment do
    confirmation = ENV["CONFIRM_DEMO_SEED_RELOAD"]
    abort "Set CONFIRM_DEMO_SEED_RELOAD=1 to reload the demo seed" unless confirmation == "1"

    Rake::Task["db:seed:replant"].invoke
  end
end
