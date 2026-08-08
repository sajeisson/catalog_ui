# frozen_string_literal: true

module CatalogUi
  module CatalogHelper
    # Modo de vista
    def current_view_mode
      params[:view].presence || 'table'
    end

    def view_toggle_url(mode)
      url_for(request.query_parameters.merge(view: mode, page: nil))
    end

    # ============================================================
    # BUILDER DE COLUMNAS - API PÚBLICA
    # ============================================================

    def catalog_columns
      builder = ColumnBuilder.new
      yield(builder) if block_given?
      builder.columns
    end

    def catalog_filters
      builder = FilterBuilder.new
      yield(builder) if block_given?
      builder.filters
    end

    # ============================================================
    # RENDERIZADOR DE CELDAS - SÓLO TIPOS GENÉRICOS
    # ============================================================

    def render_catalog_cell(item, column, search_term: nil)
      # Si la columna tiene un bloque personalizado, la gema no interfiere.
      # El usuario controla 100% el renderizado.
      if column[:block]
        return capture { column[:block].call(item) }
      end

      value = item.public_send(column[:attribute])

      case column[:as]
      when :badge
        render_badge_cell(value, column)
      when :text
        render_text_cell(value, column, search_term)
      else
        value
      end
    end

    # ============================================================
    # COLUMN BUILDER - GENÉRICO
    # ============================================================

    class ColumnBuilder
      attr_reader :columns

      def initialize
        @columns = []
      end

      # Método universal para definir cualquier columna.
      #
      # Opciones:
      #   :header       - Título de la columna (opcional, humaniza el atributo por defecto)
      #   :as           - :text o :badge (por defecto :text)
      #   :center       - Alineación centrada (false por defecto)
      #   :highlight    - Resalta coincidencias de búsqueda (solo con :as => :text)
      #   :truncate     - Longitud máxima del texto (solo con :as => :text)
      #   :badge_class  - Clase CSS del badge (solo con :as => :badge)
      #   :badge_icon   - Icono del badge (solo con :as => :badge)
      #
      # Con bloque: el usuario renderiza lo que quiera. La gema no toca el valor.
      #
      # Ejemplos:
      #   c.column :nombre, header: 'Cliente', as: :text, highlight: true, truncate: 50
      #   c.column :nit, header: 'NIT', as: :badge, badge_class: 'info', icon: 'bi-card-text'
      #   c.column :saldo, header: 'Saldo' do |item|
      #     number_to_currency(item.saldo, unit: 'Q')
      #   end
      #   c.column :correo, header: 'Email' do |item|
      #     mail_to(item.correo, item.correo)
      #   end
      #
      def column(attribute, header: nil, as: :text, center: false, **options, &block)
        col = {
          attribute: attribute,
          header: header || attribute.to_s.humanize,
          as: as,
          center: center,
          block: block
        }

        # Opciones específicas por tipo
        if as == :text
          col[:highlight] = options[:highlight] || false
          col[:truncate] = options[:truncate]
        end

        if as == :badge
          col[:badge_class] = options[:badge_class] || 'info'
          col[:badge_icon] = options[:badge_icon]
        end

        @columns << col
      end
    end

    # ============================================================
    # FILTER BUILDER - SIN CAMBIOS, YA ES GENÉRICO
    # ============================================================

    class FilterBuilder
      attr_reader :filters

      def initialize
        @filters = {}
      end

      def search(attribute, label:, placeholder: nil, icon: 'bi-search')
        @filters[attribute] = {
          label: label,
          placeholder: placeholder || "Buscar por #{label.downcase}...",
          icon: icon,
          primary: true
        }
      end

      def text(attribute, label:, placeholder: nil, icon: 'bi-text-left')
        @filters[attribute] = {
          label: label,
          placeholder: placeholder || "Buscar por #{label.downcase}...",
          icon: icon,
          primary: false
        }
      end

      def number(attribute, label:, placeholder: nil, icon: 'bi-123')
        @filters[attribute] = {
          label: label,
          placeholder: placeholder || "Buscar por #{label.downcase}...",
          icon: icon,
          primary: false,
          input_type: :number
        }
      end

      def date(attribute, label:, placeholder: nil, icon: 'bi-calendar')
        @filters[attribute] = {
          label: label,
          placeholder: placeholder || "Buscar por #{label.downcase}...",
          icon: icon,
          primary: false,
          input_type: :date
        }
      end

      def select(attribute, label:, options:, placeholder: 'Todos', icon: 'bi-funnel', include_blank: true)
        @filters[attribute] = {
          label: label,
          placeholder: placeholder,
          icon: icon,
          primary: false,
          input_type: :select,
          options: options,
          include_blank: include_blank
        }
      end
    end

    private

    def render_text_cell(value, column, search_term)
      text = value.to_s
      text = text.upcase if column[:attribute].to_s == 'nombre'
      text = highlight(text, search_term) if column[:highlight] && search_term.present?
      text = truncate(text, length: column[:truncate]) if column[:truncate]
      text
    end

    def render_badge_cell(value, column)
      content_tag(:span, class: "badge-modern #{column[:badge_class]}") do
        safe_join([
          (content_tag(:i, '', class: "bi #{column[:badge_icon]}") if column[:badge_icon]),
          value
        ].compact, ' ')
      end
    end
  end
end