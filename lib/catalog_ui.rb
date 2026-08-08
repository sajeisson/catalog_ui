# frozen_string_literal: true

require "catalog_ui/version"
require "catalog_ui/engine"
require "catalog_ui/helpers/catalog_helper"
require "catalog_ui/controllers/concerns/catalog_controller"

module CatalogUi
  mattr_accessor :default_per_page, default: 10
  mattr_accessor :max_per_page, default: 100
  mattr_accessor :theme_color, default: "#4f46e5"
  mattr_accessor :currency_unit, default: "Q"
  mattr_accessor :currency_format, default: "%u %n"
  mattr_accessor :date_format, default: :default
  mattr_accessor :search_placeholder, default: "Buscar..."

  def self.configure
    yield self
  end
end