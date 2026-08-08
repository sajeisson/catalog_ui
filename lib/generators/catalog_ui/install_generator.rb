# frozen_string_literal: true

require "rails/generators"

module CatalogUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Instala CatalogUi en tu aplicación Rails"

      def copy_initializer
        template "initializer.rb", "config/initializers/catalog_ui.rb"
      end

      def inject_stylesheet
        app_css = "app/assets/stylesheets/application.css"
        app_scss = "app/assets/stylesheets/application.scss"

        target = File.exist?(app_scss) ? app_scss : app_css

        if File.exist?(target)
          inject_into_file target, "\n@import \"catalog_ui/catalog\";\n", before: /\z/
        else
          say "No se encontró application.css/scss. Agrega manualmente: @import \"catalog_ui/catalog\";", :yellow
        end
      end

      def show_readme
        readme "README"
      end
    end
  end
end