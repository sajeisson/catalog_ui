# frozen_string_literal: true

require "rails/generators"

module CatalogUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../app", __dir__)  # Apunta a app/ de la gema

      desc "Instala CatalogUi en tu aplicación Rails (copia todos los archivos)"

      def copy_initializer
        template "templates/initializer.rb", "config/initializers/catalog_ui.rb"
      end

      def copy_views
        directory "views/catalog_ui", "app/views/catalog_ui"
      end

      def copy_stylesheets
        directory "assets/stylesheets/catalog_ui", "app/assets/stylesheets/catalog_ui"
      end

      def copy_concern
        copy_file "controllers/concerns/catalog_controller.rb", "app/controllers/concerns/catalog_ui_controller.rb"
      end

      def copy_helper
        copy_file "helpers/catalog_helper.rb", "app/helpers/catalog_ui_helper.rb"
      end

      def inject_stylesheet
        app_css = "app/assets/stylesheets/application.css"
        app_scss = "app/assets/stylesheets/application.scss"
        target = File.exist?(app_scss) ? app_scss : app_css

        if File.exist?(target)
          # Solo si no está ya agregado
          unless File.read(target).include?("catalog_ui/catalog")
            inject_into_file target, "\n@import \"catalog_ui/catalog\";\n", before: /\z/
          end
        end
      end

      def show_readme
        readme "templates/README" if behavior == :invoke
      end
    end
  end
end