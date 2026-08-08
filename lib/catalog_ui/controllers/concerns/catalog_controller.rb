# frozen_string_literal: true

module CatalogUi
  module CatalogController
    extend ActiveSupport::Concern

    included do
      before_action :set_catalog_config
      helper_method :catalog_config
    end

    # ============================================================
    # HELPERS OPT-IN: úsalos desde tus propias acciones
    # ============================================================

    # Aplica ordenamiento por columna clickeable.
    # Uso en tu index: @clients = catalog_apply_sorting(@clients)
    def catalog_apply_sorting(relation)
      return relation unless params[:sort].present?

      field, direction = parse_sort_param(params[:sort])
      return relation unless valid_sort_field?(field)

      safe_direction = %w[asc desc].include?(direction) ? direction : 'asc'
      relation.order(field => safe_direction)
    end

    # Devuelve el término de búsqueda activo para mostrar en la vista
    def catalog_search_term
      params[:q]&.values&.first || params[:nombre] || params[:search]
    end

    private

    # ============================================================
    # LÓGICA DE ORDENAMIENTO (privada)
    # ============================================================

    def parse_sort_param(sort_param)
      return [nil, nil] unless sort_param.is_a?(String) && sort_param.include?('_')

      parts = sort_param.rpartition('_')
      [parts[0], parts[2]]
    end

    def valid_sort_field?(field)
      return false if field.blank?
      return false unless catalog_config[:model].respond_to?(:column_names)
      catalog_config[:model].column_names.include?(field)
    end

    # ============================================================
    # CONFIGURACIÓN (debes implementar en tu controlador)
    # ============================================================

    def set_catalog_config
      raise NotImplementedError, "Debes definir set_catalog_config en #{self.class}"
    end

    def catalog_config
      @catalog_config
    end
  end
end