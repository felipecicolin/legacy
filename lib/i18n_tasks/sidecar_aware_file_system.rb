# frozen_string_literal: true

require "i18n/tasks/data/file_system"

module I18nTasks
  # ViewComponent v4 stores per-component translations in sidecar yml files
  # with a FLAT shape (`pt-BR: { key: value }`) and its I18nBackend
  # auto-scopes them under the component name at runtime. Plain i18n-tasks
  # would either collide keys across sidecars or miss component-scoped
  # lookups (`t(".key")` from a component template resolves to
  # `<component>.key` in the source scanner).
  #
  # This adapter hooks the parse boundary: sidecar yml is wrapped under its
  # component name on read so the in-memory tree mirrors VC's runtime scope
  # (`<component>.<key>`), and the wrapper is stripped on write so the
  # files on disk stay flat — the format VC expects and
  # `bin/i18n_sidecar_lint` enforces.

  SIDECAR_PATH_RE = %r{\Aapp/components/([a-z0-9_]+_component)/\1\.[^.]+\.yml\z}

  Sidecar = Data.define(:path, :component) do
    def self.for(path)
      component = path[SIDECAR_PATH_RE, 1]
      component && new(path: path, component: component)
    end
  end

  class SidecarAwareFileSystem < I18n::Tasks::Data::FileSystem
    # `register_adapter` writes to a class-level ivar that subclasses don't
    # inherit. Re-register so `load_file` / `adapter_name_for_path` resolve
    # `.yml` and `.json` paths through us.
    register_adapter :yaml, "*.yml", I18n::Tasks::Data::Adapter::YamlAdapter
    register_adapter :json, "*.json", I18n::Tasks::Data::Adapter::JsonAdapter

    protected

    def load_file(path)
      data = super
      component = path[SIDECAR_PATH_RE, 1]
      data.transform_values { |tree| component ? { component => tree } : tree }
    end

    # `*args` matches the gem's positional `(path, tree, sort=true)` call
    # without forcing an explicit boolean default in our signature.
    def write_tree(*args)
      path, tree, sort = args
      sidecar = Sidecar.for(path) or return super
      content = unwrap_dump(sidecar, tree.to_hash(sort != false))
      return if File.file?(path) && content == read_file(path)

      ::FileUtils.mkpath(File.dirname(path))
      ::File.write(path, content)
    end

    def normalized?(path, tree)
      sidecar = Sidecar.for(path) or return super
      return false unless File.file?(path)

      read_file(path) == unwrap_dump(sidecar, tree.to_hash(true))
    end

    private

    def unwrap_dump(sidecar, tree_hash)
      hash = tree_hash.transform_values { |locale_tree| locale_tree.fetch(sidecar.component, locale_tree) }
      adapter_dump(hash, self.class.adapter_name_for_path(sidecar.path))
    end
  end
end
