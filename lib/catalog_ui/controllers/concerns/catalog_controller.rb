
# frozen_string_literal: true

module CatalogUi
  module CatalogController
    extend ActiveSupport::Concern

    MAX_SEARCH_TERM_LENGTH = 200
    VALID_SORT_DIRECTIONS = %w[asc desc].freeze

    included do
      before_action :set_catalog_config
      helper_method :catalog_config
    end

    # ============================================================
    # API PÚBLICA: ORDENAMIENTO
    # ============================================================

    # Aplica ordenamiento seguro a una relación de ActiveRecord.
    #
    # Uso:
    #   @clients = catalog_apply_sorting(@clients)
    #
    # Parámetro esperado:
    #   ?sort=nombre_asc
    #   ?sort=created_at_desc
    #
    # Las columnas se validan contra el modelo de la relación.
    # Si el parámetro es inválido, se conserva la relación original.
    def catalog_apply_sorting(relation)
      return relation unless valid_sort_relation?(relation)

      sort_param = params[:sort]

      return relation unless sort_param.is_a?(String)
      return relation if sort_param.blank?

      field, direction = parse_sort_param(sort_param)

      return relation unless valid_sort_field?(field, relation: relation)
      return relation unless VALID_SORT_DIRECTIONS.include?(direction)

      # Arel genera una expresión de ordenamiento asociada a la tabla.
      # No se interpola directamente el parámetro recibido en SQL.
      table = relation.klass.arel_table
      order_node = table[field].public_send(direction)

      relation.order(order_node)
    end

    # ============================================================
    # API PÚBLICA: BÚSQUEDA
    # ============================================================

    # Devuelve un término textual para resaltar coincidencias en la vista.
    #
    # Prioridad:
    #   1. params[:nombre]
    #   2. params[:search]
    #   3. Primer valor textual escalar de params[:q]
    #
    # Los parámetros anidados de Ransack no se convierten en texto.
    def catalog_search_term
      direct_term = normalized_search_value(params[:nombre])
      direct_term ||= normalized_search_value(params[:search])

      return direct_term if direct_term.present?

      ransack_params = params[:q]

      return nil unless ransack_params.respond_to?(:each_pair)

      ransack_params.each_pair do |_key, value|
        normalized = normalized_search_value(value)
        return normalized if normalized.present?
      end

      nil
    end

    private

    # ============================================================
    # ORDENAMIENTO: VALIDACIÓN
    # ============================================================

    def valid_sort_relation?(relation)
      relation.respond_to?(:order) &&
        relation.respond_to?(:klass) &&
        relation.klass.respond_to?(:column_names) &&
        relation.klass.respond_to?(:arel_table)
    end

    def parse_sort_param(sort_param)
      return [nil, nil] unless sort_param.is_a?(String)
      return [nil, nil] if sort_param.blank?

      # Se divide por el último guion bajo para permitir
      # nombres de columnas como created_at o numero_documento.
      field, separator, direction = sort_param.rpartition('_')

      return [nil, nil] if separator.empty?
      return [nil, nil] if field.blank?

      [field, direction]
    end

    def valid_sort_field?(field, relation: nil)
      return false unless field.is_a?(String)
      return false unless field.match?(/\A[a-zA-Z_]\w*\z/)

      model = if valid_sort_relation?(relation)
                relation.klass
              else
                configured_catalog_model
              end

      return false unless model
      return false unless model.respond_to?(:column_names)

      model.column_names.include?(field)
    end

    # ============================================================
    # CONFIGURACIÓN DEL CATÁLOGO
    # ============================================================

    # Debe implementarse en el controlador que incorpora el concern.
    #
    # Ejemplo:
    #
    # private
    #
    # def set_catalog_config
    #   @catalog_config = {
    #     model: Client,
    #     title: 'Clientes'
    #   }
    # end
    #
    def set_catalog_config
      raise NotImplementedError,
            "Debes definir set_catalog_config en #{self.class}"
    end

    # Conserva el acceso público usado por helpers y vistas.
    def catalog_config
      validate_catalog_config!

      @catalog_config
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
    # NORMALIZACIÓN DE BÚSQUEDA
    # ============================================================

    def normalized_search_value(value)
      # No convertir hashes, arrays ni parámetros complejos a texto.
      return nil unless value.is_a?(String) || value.is_a?(Symbol)

      term = value.to_s.strip
      return nil if term.empty?

      term.truncate(MAX_SEARCH_TERM_LENGTH)
    end
  end
end
