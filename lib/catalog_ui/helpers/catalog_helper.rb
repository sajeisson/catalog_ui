
# frozen_string_literal: true

module CatalogUi
  module CatalogHelper
    # Métodos públicos de presentación
    # ============================================================

    def current_view_mode
      mode = params[:view].to_s

      %w[table cards].include?(mode) ? mode : 'table'
    end

    def view_toggle_url(mode)
      mode = mode.to_s

      unless %w[table cards].include?(mode)
        raise ArgumentError, "Modo de vista no válido: #{mode.inspect}"
      end

      url_for(request.query_parameters.merge(view: mode, page: nil))
    end

    # ============================================================
    # RUTAS DE RECURSOS
    # ============================================================

    # Genera rutas convencionales de Rails.
    #
    # Ejemplos:
    #   catalog_resource_path(cliente)
    #   catalog_resource_path(cliente, :admin)
    #   catalog_resource_path(cliente, :admin, action: :edit)
    #
    # Para acciones personalizadas, utiliza explícitamente el helper
    # de rutas correspondiente desde la vista o el bloque de columna.
    def catalog_resource_path(item, namespace = nil, action: nil)
      raise ArgumentError, 'El recurso no puede estar vacío' if item.nil?

      namespaces = Array(namespace).compact

      unless namespaces.all? { |part| valid_route_segment?(part) }
        raise ArgumentError, 'El namespace contiene un segmento no válido'
      end

      action = normalize_route_action(action)

      route_parts = []

      # En las rutas polimórficas de Rails, la acción precede
      # al namespace: [:edit, :admin, recurso].
      route_parts << action if %i[edit new].include?(action)
      route_parts.concat(namespaces)
      route_parts << item

      polymorphic_path(route_parts)
    end

    # ============================================================
    # BUILDERS PÚBLICOS
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
    # RENDERIZADOR DE CELDAS
    # ============================================================

    def render_catalog_cell(item, column, search_term: nil)
      raise ArgumentError, 'El recurso no puede estar vacío' if item.nil?
      raise ArgumentError, 'La columna debe ser un Hash' unless column.is_a?(Hash)

      # Los bloques personalizados mantienen la flexibilidad de la API.
      # capture conserva el comportamiento de renderizado de Rails.
      if column[:block]
        unless column[:block].respond_to?(:call)
          raise ArgumentError, 'El bloque de la columna no es ejecutable'
        end

        return capture { column[:block].call(item) }
      end

      attribute = column[:attribute]

      unless valid_column_attribute?(attribute)
        raise ArgumentError, "Atributo de columna no válido: #{attribute.inspect}"
      end

      unless item.respond_to?(attribute)
        raise ArgumentError,
              "El recurso #{item.class} no responde al atributo #{attribute.inspect}"
      end

      value = item.public_send(attribute)

      case column[:as]&.to_sym
      when :badge
        render_badge_cell(value, column)
      when :text, nil
        render_text_cell(value, column, search_term)
      else
        raise ArgumentError,
              "Tipo de columna no compatible: #{column[:as].inspect}"
      end
    end

    # ============================================================
    # COLUMN BUILDER
    # ============================================================


  class ColumnBuilder
    attr_reader :columns

    VALID_TYPES = %i[text badge].freeze

    def initialize
      @columns = []
    end

    def column(attribute, header: nil, as: :text, center: false, **options, &block)
      attribute_name = attribute.to_s

      unless attribute_name.match?(/\A[a-zA-Z_]\w*[!?]?\z/)
        raise ArgumentError, "Atributo de columna no válido: #{attribute.inspect}"
      end

      type =
        begin
          as.to_sym
        rescue NoMethodError
          nil
        end

      unless VALID_TYPES.include?(type)
        raise ArgumentError, "Tipo de columna no compatible: #{as.inspect}"
      end

      truncate_length = normalize_truncate(options[:truncate])

      col = {
        attribute: attribute,
        header: header.presence || attribute_name.humanize,
        as: type,
        center: !!center,
        block: block,
        sortable: !!options[:sortable]
      }

      if type == :text
        col[:highlight] = !!options[:highlight]
        col[:truncate] = truncate_length
      elsif type == :badge
        col[:badge_class] = options[:badge_class].presence || 'info'
        col[:badge_icon] = options[:badge_icon]
      end

      @columns << col
    end

    private

    def normalize_truncate(value)
      return nil if value.nil?

      length =
        case value
        when Integer
          value
        when String
          return nil if value.strip.empty?

          unless value.match?(/\A\d+\z/)
            raise ArgumentError, 'truncate debe ser un entero mayor que cero'
          end

          value.to_i
        else
          raise ArgumentError, 'truncate debe ser un entero mayor que cero'
        end

      unless length.positive?
        raise ArgumentError, 'truncate debe ser un entero mayor que cero'
      end

      length
    end
  end


    # ============================================================
    # FILTER BUILDER
    # ============================================================

    class FilterBuilder
      attr_reader :filters

      def initialize
        @filters = {}
      end

      def search(attribute, label:, placeholder: nil, icon: 'bi-search')
        add_filter(
          attribute,
          label: label,
          placeholder: placeholder,
          icon: icon,
          primary: true
        )
      end

      def text(attribute, label:, placeholder: nil, icon: 'bi-text-left')
        add_filter(
          attribute,
          label: label,
          placeholder: placeholder,
          icon: icon,
          primary: false
        )
      end

      def number(attribute, label:, placeholder: nil, icon: 'bi-123')
        add_filter(
          attribute,
          label: label,
          placeholder: placeholder,
          icon: icon,
          primary: false,
          input_type: :number
        )
      end

      def date(attribute, label:, placeholder: nil, icon: 'bi-calendar')
        add_filter(
          attribute,
          label: label,
          placeholder: placeholder,
          icon: icon,
          primary: false,
          input_type: :date
        )
      end

      def select(
        attribute,
        label:,
        options:,
        placeholder: 'Todos',
        icon: 'bi-funnel',
        include_blank: true
      )
        add_filter(
          attribute,
          label: label,
          placeholder: placeholder,
          icon: icon,
          primary: false,
          input_type: :select,
          options: options,
          include_blank: include_blank
        )
      end

      private

      def add_filter(
        attribute,
        label:,
        placeholder: nil,
        icon:,
        primary:,
        **options
      )
        raise ArgumentError, 'El atributo del filtro no puede estar vacío' if attribute.blank?
        raise ArgumentError, 'La etiqueta del filtro no puede estar vacía' if label.blank?

        @filters[attribute] = {
          label: label,
          placeholder: placeholder || "Buscar por #{label.to_s.downcase}...",
          icon: icon,
          primary: primary
        }.merge(options)
      end
    end

    private

    # ============================================================
    # VALIDACIONES INTERNAS
    # ============================================================

    FORBIDDEN_COLUMN_METHODS = %w[
      send
      public_send
      __send__
      eval
      instance_eval
      class_eval
      destroy
      destroy!
      delete
      delete!
      save
      save!
      update
      update!
      update_attribute
      update_column
      update_columns
      assign_attributes
      attributes=
      reload
      touch
      increment!
      decrement!
      toggle!
    ].freeze

    def valid_column_attribute?(attribute)
      return false unless attribute.is_a?(String) || attribute.is_a?(Symbol)

      name = attribute.to_s

      name.match?(/\A[a-zA-Z_]\w*[!?]?\z/) &&
        !FORBIDDEN_COLUMN_METHODS.include?(name)
    end

    def valid_route_segment?(segment)
      return false unless segment.is_a?(String) || segment.is_a?(Symbol)

      segment.to_s.match?(/\A[a-zA-Z_]\w*\z/)
    end

    def normalize_route_action(action)
      return nil if action.nil?

      normalized = action.to_s

      # edit y new generan rutas distintas.
      # show, update y destroy utilizan la ruta del recurso;
      # el verbo HTTP determina la operación.
      return normalized.to_sym if %w[edit new].include?(normalized)
      return nil if %w[show update destroy].include?(normalized)

      raise ArgumentError, "Acción de ruta no compatible: #{action.inspect}"
    end

    # ============================================================
    # RENDERIZADO DE TEXTO
    # ============================================================

    def render_text_cell(value, column, search_term)
      text = value.to_s

      if column[:truncate]
        length = Integer(column[:truncate])

        if length.positive?
          text = truncate(text, length: length)
        end
      end

      term = normalize_catalog_search_term(search_term)

      if column[:highlight] && term.present?
        highlight(text, term)
      else
        text
      end
    end

    def normalize_catalog_search_term(term)
      return nil unless term.is_a?(String) || term.is_a?(Symbol)

      normalized = term.to_s.strip
      normalized.presence
    end

    # ============================================================
    # RENDERIZADO DE BADGES
    # ============================================================

    def render_badge_cell(value, column)
      badge_class = validated_css_classes(
        column[:badge_class] || 'info'
      )

      icon_class = column[:badge_icon].presence

      classes = ['bi']
      classes.concat(validated_css_classes(icon_class).split) if icon_class

      content_tag(:span, class: "badge-modern #{badge_class}") do
        parts = []

        if icon_class
          parts << content_tag(:i, '', class: classes.join(' '))
        end

        parts << value unless value.nil?

        safe_join(parts, ' ')
      end
    end

    # Permite nombres de clases CSS, no HTML ni declaraciones arbitrarias.
    def validated_css_classes(value)
      classes = value.to_s.strip

      unless classes.match?(/\A[a-zA-Z0-9_-]+(?:\s+[a-zA-Z0-9_-]+)*\z/)
        raise ArgumentError, "Clase CSS no válida: #{value.inspect}"
      end

      classes
    end
  end
end
