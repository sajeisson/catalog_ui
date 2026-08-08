================================================================================

  CATALOG UI INSTALADO

================================================================================
rails generate catalog_ui:install

1. La gema está configurada en config/initializers/catalog_ui.rb

2. Los estilos se inyectaron en tu application.css/scss

3. Para usar en un controlador:

    class ClientsController < ApplicationController
      include CatalogUi::CatalogController

      private

      def set_catalog_config
        @catalog_config = {
          model: Client,
          title: 'Listado de Clientes',
          icon: 'bi-people',
          search_fields: [:nombre, :nit, :correo],
          order_field: :nombre,
          default_per_page: 10
        }
      end

      def resource_params
        params.require(:client).permit(:nombre, :nit, :telefono, :correo)
      end
    end

4. En tu vista (app/views/clients/index.html.erb):

    <%
      columns = catalog_columns do |c|
        c.badge  :nit,      header: 'NIT', icon: 'bi-card-text'
        c.text   :nombre,   header: 'Nombre', highlight: true, truncate: 50
        c.phone  :telefono
        c.email  :correo
      end

      filters = catalog_filters do |f|
        f.search :nombre, label: 'Buscar por Nombre', placeholder: 'Nombre...'
        f.text   :nit,    label: 'NIT'
      end
    %>

    <%= render 'catalog_ui/shared/catalog_container',
        title: catalog_config[:title],
        icon: catalog_config[:icon],
        new_path: new_client_path,
        export_path: clients_path(format: :xlsx),
        search_path: search_clients_path,
        clear_path: clients_path,
        collection: @collection,
        filters: filters,
        columns: columns %>

================================================================================