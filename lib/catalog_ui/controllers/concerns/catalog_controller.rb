
# frozen_string_literal: true

module CatalogUi
  module CatalogController
    extend ActiveSupport::Concern

    MAX_SEARCH_TERM_LENGTH = 200
    VALID_SORT_DIRECTIONS = %w[asc desc].freeze
    DEFAULT_PER_PAGE = 10
    DEFAULT_MAX_PER_PAGE = 100

    included do
      before_action :set_catalog_config

      helper_method :catalog_config
      helper_method :catalog_search_term
      helper_method :catalog_per_page
      helper_method :catalog_actions
    end

    # ============================================================
    # API PÚBLICA: ORDENAMIENTO
    # ============================================================

    # Aplica ordenamiento seguro a una relación ActiveRecord.
    #
    # Ejemplos:
    #   ?sort=nombre_asc
    #   ?sort=created_at_desc
    #
    # Uso:
    #   @clients = catalog_apply_sorting(@clients)
    #
    # Solo permite columnas reales del modelo de la relación.
    def catalog_apply_sorting(relation)
      return relation unless valid_sort_relation?(relation)

      sort_param = params[:sort]
      return relation unless sort_param.is_a?(String)
      return relation if sort_param.blank?

      field, direction = parse_sort_param(sort_param)

      return relation unless valid_sort_field?(field, relation: relation)
      return relation unless VALID_SORT_DIRECTIONS.include?(direction)

      table = relation.klass.arel_table
      order_node = table[field].public_send(direction)

      relation.order(order_node)
    end

    # ============================================================
    # API PÚBLICA: BÚSQUEDA GLOBAL
    # ============================================================

    # Devuelve el texto que debe resaltarse en las vistas.
    #
    # Prioridad:
    #   1. params[:search]
    #   2. params[:nombre]
    #   3. Primer valor escalar de params[:q]
    #
    # No convierte hashes ni arrays a texto.
    def catalog_search_term
      direct_term = normalized_search_value(params[:search])
      return direct_term if direct_term.present?

      legacy_term = normalized_search_value(params[:nombre])
      return legacy_term if legacy_term.present?

      query_params = params[:q]
      return nil unless query_params.respond_to?(:each_pair)

      query_params.each_pair do |_key, value|
        normalized = normalized_search_value(value)
        return normalized if normalized.present?
      end

      nil
    end

    # Busca un término en varias columnas permitidas.
    #
    # Uso:
    #   @clients = catalog_apply_search(@clients)
    #
    # Por defecto utiliza params[:search].
    # Para utilizar otro término:
    #   catalog_apply_search(@clients, term: params[:nombre])
    #
    # Para definir columnas explícitamente:
    #   catalog_apply_search(
    #     @clients,
    #     fields: %i[nombre nit correo telefono]
    #   )
    #
    # Si la configuración define :search_fields, se utiliza esa lista.
    # Si no existe, se buscan columnas de texto y numéricas.
    def catalog_apply_search(relation, term: params[:search], fields: nil)
      return relation unless valid_sort_relation?(relation)

      search_term = normalized_search_value(term)
      return relation if search_term.blank?

      model = relation.klass
      allowed_fields = resolve_search_fields(model, fields)

      return relation if allowed_fields.empty?

      connection = model.connection
      quoted_table = connection.quote_table_name(model.table_name)
      adapter = connection.adapter_name.to_s.downcase

      escaped_term = ActiveRecord::Base.sanitize_sql_like(search_term)
      pattern = "%#{escaped_term}%"

      conditions = allowed_fields.map do |field|
        quoted_column = connection.quote_column_name(field)
        qualified_column = "#{quoted_table}.#{quoted_column}"

        search_expression(
          qualified_column,
          adapter
        )
      end

      sql = conditions.join(' OR ')
      binds = Array.new(conditions.length, pattern)

      relation.where("(#{sql})", *binds)
    end

    # ============================================================
    # API PÚBLICA: PAGINACIÓN
    # ============================================================

    # Devuelve un número positivo de registros por página.
    #
    # Respeta:
    #   CatalogUi.default_per_page
    #   CatalogUi.max_per_page
    #   catalog_config[:default_per_page]
    #
    # Uso:
    #   @clients = @clients.page(params[:page]).per(catalog_per_page)
    def catalog_per_page
      configured_default = catalog_config[:default_per_page].to_i

      unless configured_default.positive?
        configured_default = CatalogUi.default_per_page.to_i
      end

      unless configured_default.positive?
        configured_default = DEFAULT_PER_PAGE
      end

      maximum = CatalogUi.max_per_page.to_i
      maximum = DEFAULT_MAX_PER_PAGE unless maximum.positive?

      default_value = [configured_default, maximum].min
      requested = params[:per_page]

      return default_value unless requested.is_a?(String)
      return default_value unless requested.match?(/\A\d{1,3}\z/)

      value = requested.to_i
      return default_value unless value.positive?

      [value, maximum].min
    end

    private

    # ============================================================
    # VALIDACIÓN DE RELACIONES
    # ============================================================

    def valid_sort_relation?(relation)
      relation.respond_to?(:order) &&
        relation.respond_to?(:klass) &&
        relation.klass.respond_to?(:column_names) &&
        relation.klass.respond_to?(:arel_table)
    end

    # ============================================================
    # VALIDACIÓN DEL ORDENAMIENTO
    # ============================================================

    def parse_sort_param(sort_param)
      return [nil, nil] unless sort_param.is_a?(String)
      return [nil, nil] if sort_param.blank?

      # Se separa por el último guion bajo.
      # Ejemplo: created_at_desc => created_at / desc
      field, separator, direction = sort_param.rpartition('_')

      return [nil, nil] if separator.empty?
      return [nil, nil] if field.blank?

      [field, direction]
    end

    def valid_sort_field?(field, relation: nil)
      return false unless field.is_a?(String)
      return false unless field.match?(/\A[a-zA-Z_]\w*\z/)

      model =
        if valid_sort_relation?(relation)
          relation.klass
        else
          configured_catalog_model
        end

      return false unless model.respond_to?(:column_names)

      model.column_names.include?(field)
    end

    # ============================================================
    # CONFIGURACIÓN DEL CATÁLOGO
    # ============================================================

    # Debe ser implementado por el controlador que incluya el concern.
    #
    # Ejemplo:
    #
    # private
    #
    # def set_catalog_config
    #   @catalog_config = {
    #     model: Client,
    #     title: 'Clientes',
    #     icon: 'bi-people',
    #     search_fields: %i[nombre nit correo telefono],
    #     order_field: :created_at,
    #     order_direction: :desc,
    #     default_per_page: 10
    #   }
    # end
    #
    def set_catalog_config
      raise NotImplementedError,
            "Debes definir set_catalog_config en #{self.class}"
    end

    def catalog_config
      validate_catalog_config!
      @catalog_config
    end

    def catalog_actions
      allowed_actions = %i[show edit destroy]

      configured_actions =
        if catalog_config.key?(:actions)
          catalog_config[:actions]
        else
          allowed_actions
        end

      Array(configured_actions)
        .select { |action| action.is_a?(String) || action.is_a?(Symbol) }
        .map(&:to_sym)
        .uniq
        .select { |action| allowed_actions.include?(action) }
    end

    def validate_catalog_config!
      unless @catalog_config.respond_to?(:[])
        raise ArgumentError,
              'CatalogUi requiere una configuración accesible por claves. ' \
              'Define @catalog_config en set_catalog_config.'
      end

      model = @catalog_config[:model]

      unless model.respond_to?(:column_names) &&
             model.respond_to?(:arel_table)
        raise ArgumentError,
              'La configuración de CatalogUi debe incluir :model ' \
              'con una clase de ActiveRecord válida.'
      end
    end

    def configured_catalog_model
      validate_catalog_config!
      @catalog_config[:model]
    end

    # ============================================================
    # RESOLUCIÓN DE COLUMNAS PARA BÚSQUEDA
    # ============================================================

    def resolve_search_fields(model, fields)
      configured_fields =
        if fields.nil?
          @catalog_config[:search_fields]
        else
          fields
        end

      # Si se definieron columnas explícitas, no se amplía la búsqueda
      # automáticamente a otras columnas.
      if configured_fields.present?
        candidates = Array(configured_fields)
      else
        candidates = model.columns.filter_map do |column|
          column.name if searchable_column_type?(column.type)
        end
      end

      candidates
        .map(&:to_s)
        .uniq
        .select { |field| valid_search_field?(field, model) }
    end

    def searchable_column_type?(type)
      %i[
        string
        text
        integer
        bigint
        float
        decimal
      ].include?(type)
    end

    def valid_search_field?(field, model)
      return false unless field.match?(/\A[a-zA-Z_]\w*\z/)

      model.column_names.include?(field)
    end

    # ============================================================
    # EXPRESIONES SQL SEGÚN ADAPTADOR
    # ============================================================

    def search_expression(qualified_column, adapter)
      if adapter.include?('postgresql')
        "CAST(#{qualified_column} AS TEXT) ILIKE ?"
      elsif adapter.include?('mysql')
        "CAST(#{qualified_column} AS CHAR) LIKE ?"
      elsif adapter.include?('sqlserver')
        "CAST(#{qualified_column} AS NVARCHAR(MAX)) LIKE ?"
      else
        # SQLite y otros adaptadores compatibles con CAST AS TEXT.
        "CAST(#{qualified_column} AS TEXT) LIKE ?"
      end
    end

    # ============================================================
    # NORMALIZACIÓN DE TEXTO
    # ============================================================

    def normalized_search_value(value)
      # Evita convertir parámetros complejos a cadenas.
      return nil unless value.is_a?(String) || value.is_a?(Symbol)

      term = value.to_s.strip
      return nil if term.empty?

      term.truncate(MAX_SEARCH_TERM_LENGTH)
    end
  end
end
