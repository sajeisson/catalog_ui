# frozen_string_literal: true

module CatalogUi
  class Engine < ::Rails::Engine
    isolate_namespace CatalogUi

    initializer "catalog_ui.helpers" do
      ActiveSupport.on_load(:action_controller) do
        helper CatalogUi::CatalogHelper
      end
    end

    initializer "catalog_ui.assets" do |app|
      app.config.assets.precompile += %w[catalog_ui/catalog.css]
    end
  end
end