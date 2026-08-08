# frozen_string_literal: true

require_relative "lib/catalog_ui/version"

Gem::Specification.new do |spec|
  spec.name        = "catalog_ui"
  spec.version     = CatalogUi::VERSION
  spec.authors     = ["jfsan"]
  spec.email       = ["jfsan@yahoo.com"]
  spec.summary     = "UI kit reutilizable para catálogos Rails"
  spec.description = "Proporciona diseño, helpers, concern y partials para listados CRUD consistentes con búsqueda, filtros, paginación y exportación."
  spec.homepage    = "https://github.com/sajeisson/catalog_ui"
  spec.license     = "MIT"

  spec.files = Dir["{app,lib}/**/*", "MIT-LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0.0"

  spec.add_dependency "rails", ">= 6.1"
  spec.add_dependency "kaminari", ">= 1.2"
  spec.add_dependency "ransack", ">= 3.0"
end