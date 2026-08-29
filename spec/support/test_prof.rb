# frozen_string_literal: true

# Ferramental de profiling da suíte (test-prof).
#
# `let_it_be`/`before_all`/`create_default` são API que os specs usam, então
# ficam sempre carregados. Os *profilers* são carregados só quando a variável
# de ambiente que os liga está presente — cada um instala hooks de RSpec e
# assinantes de ActiveSupport::Notifications, e pagar por isso em toda rodada
# seria financiar a medição com o tempo que ela existe para reduzir.
require "test_prof/recipes/rspec/let_it_be"
require "test_prof/recipes/rspec/before_all"
require "test_prof/recipes/rspec/sample"
require "test_prof/recipes/rspec/factory_default"

TestProf::FactoryDefault.configure do |config|
  # Sem `preserve_traits`, um `create(:record, :some_trait)` cairia no registro
  # padrão sem o trait e o exemplo passaria testando outra coisa.
  config.preserve_traits = true
  config.preserve_attributes = true
end

TestProf::LetItBe.configure do |config|
  # Redeclarar um `let_it_be` em contexto aninhado é quase sempre engano: o de
  # fora continua existindo e ninguém percebe qual dos dois o exemplo usou.
  config.report_duplicates = :warn
end

# —— Profilers sob demanda ————————————————————————————————————————
require "test_prof/event_prof" if ENV["EVENT_PROF"]
require "test_prof/factory_prof" if ENV["FPROF"]
require "test_prof/factory_doctor" if ENV["FDOC"]
require "test_prof/tag_prof" if ENV["TAG_PROF"]
require "test_prof/rspec_dissect" if ENV["RD_PROF"]
require "test_prof/tps_prof" if ENV["TPS_PROF"]
require "test_prof/memory_prof" if ENV["TEST_MEM_PROF"]

if ENV["TEST_STACK_PROF"]
  require "test_prof/stack_prof"

  TestProf::StackProf.configure do |config|
    # JSON abre direto no speedscope.app, que é onde a visão "sandwich" — a que
    # responde "quem gasta tempo somando todas as chamadas" — existe.
    config.format = "json"
  end
end
