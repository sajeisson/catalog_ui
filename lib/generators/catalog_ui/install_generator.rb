# frozen_string_literal: true

require "rails/generators"

module CatalogUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      # Para templates (initializer.rb, README)
      source_root File.expand_path("templates", __dir__)

      # Rutas absolutas a los archivos de la gema
      VIEWS_SOURCE      = File.expand_path("../../../app/views/catalog_ui", __dir__)
      STYLES_SOURCE     = File.expand_path("../../../app/assets/stylesheets/catalog_ui", __dir__)

      desc "Instala CatalogUi en tu aplicación Rails (copia vistas y estilos al proyecto)"

      def copy_initializer
        template "initializer.rb", "config/initializers/catalog_ui.rb"
      end

      def copy_views
        if File.directory?(VIEWS_SOURCE)
          directory VIEWS_SOURCE, "app/views/catalog_ui"
        else
          say "No se encontraron vistas en la gema", :yellow
        end
      end

      def copy_stylesheets
        if File.directory?(STYLES_SOURCE)
          directory STYLES_SOURCE, "app/assets/stylesheets/catalog_ui"
        else
          say "No se encontraron estilos en la gema", :yellow
        end
      end

      def inject_stylesheet
        app_css  = "app/assets/stylesheets/application.css"
        app_scss = "app/assets/stylesheets/application.scss"
        target   = File.exist?(app_scss) ? app_scss : app_css

        return unless File.exist?(target)

        unless File.read(target).include?("catalog_ui/catalog")
          inject_into_file target, "\n@import \"catalog_ui/catalog\";\n", before: /\z/
        end
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end