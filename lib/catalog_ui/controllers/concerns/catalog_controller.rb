# frozen_string_literal: true

module CatalogUi
  module CatalogController
    extend ActiveSupport::Concern

    included do
      before_action :set_catalog_config
      helper_method :catalog_config
    end

    def index
      @q = build_search_query
      @collection = paginate_results(@q.result(distinct: true))
      respond_to_format
    end

    def show
      set_resource
    end

    def new
      @resource = catalog_config[:model].new
      set_instance_variable
    end

    def create
      @resource = catalog_config[:model].new(resource_params)

      if @resource.save
        redirect_to polymorphic_path(@resource),
                    notice: "#{resource_name} creado exitosamente."
      else
        set_instance_variable
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      set_resource
      set_instance_variable
    end

    def update
      set_resource

      if @resource.update(resource_params)
        redirect_to polymorphic_path(@resource),
                    notice: "#{resource_name} actualizado exitosamente."
      else
        set_instance_variable
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      set_resource

      if @resource.destroy
        redirect_to polymorphic_path(catalog_config[:model]),
                    notice: "#{resource_name} eliminado exitosamente."
      else
        redirect_back fallback_location: root_path,
                      alert: "No se pudo eliminar #{resource_name.downcase}."
      end
    end

    def search
      @q = build_search_query
      @collection = paginate_results(@q.result(distinct: true))
      render :index
    end

    def export
      @q = build_search_query
      @collection = @q.result(distinct: true)

      respond_to do |format|
        format.xlsx do
          response.headers["Content-Disposition"] = "attachment; filename=#{export_filename}.xlsx"
          render xlsx: "export", template: "shared/export"
        end
        format.csv do
          send_data generate_csv, filename: "#{export_filename}.csv"
        end
      end
    end

    private

    def set_resource
      @resource = catalog_config[:model].find(params[:id])
      set_instance_variable
    end

    def set_instance_variable
      var_name = "@#{resource_name.underscore}"
      instance_variable_set(var_name, @resource)
    end

    def resource_name
      catalog_config[:model].model_name.human
    end

    def resource_params
      raise NotImplementedError, "Define resource_params en #{self.class}"
    end

    def set_catalog_config
      raise NotImplementedError, "Debes definir set_catalog_config en #{self.class}"
    end

    def catalog_config
      @catalog_config
    end

    def build_search_query
      model = catalog_config[:model]
      search_params = params[:q] || {}

      if defined?(Ransack)
        model.ransack(search_params.merge(build_ransack_conditions))
      else
        apply_search_scopes(model.all)
      end
    end

    def apply_search_scopes(relation)
      search_fields = catalog_config[:search_fields] || []
      search_term = extract_search_term

      if search_term.present? && search_fields.any?
        conditions = search_fields.map { |field| "#{field} ILIKE ?" }.join(" OR ")
        relation = relation.where(conditions, *search_fields.map { "%#{search_term}%" })
      end

      catalog_config[:filter_fields]&.each do |field|
        relation = relation.where(field => params[field]) if params[field].present?
      end

      relation
    end

    def build_ransack_conditions
      conditions = {}
      search_fields = catalog_config[:search_fields] || []
      search_term = extract_search_term

      if search_fields.any? && search_term.present?
        conditions[:groupings] = search_fields.map do |field|
          { "#{field}_cont" => search_term }
        end
      end

      conditions
    end

    def extract_search_term
      params[:q]&.values&.first || params[:nombre]
    end

    def paginate_results(relation)
      per_page = (params[:per_page] || catalog_config[:default_per_page] || CatalogUi.default_per_page).to_i
      per_page = [per_page, CatalogUi.max_per_page].min

      relation
        .order(catalog_config[:order_field] || :created_at => catalog_config[:order_direction] || :desc)
        .page(params[:page])
        .per(per_page)
    end

    def respond_to_format
      respond_to do |format|
        format.html
        format.json { render json: @collection }
        format.xlsx { export } if catalog_config[:export_formats]&.include?(:xlsx)
      end
    end

    def export_filename
      "#{catalog_config[:model].name.downcase.pluralize}_#{Date.current}"
    end

    def generate_csv
      require "csv"
      columns = catalog_config[:export_columns] || catalog_config[:search_fields]

      CSV.generate(headers: true) do |csv|
        csv << columns.map { |col| col.to_s.humanize }

        @collection.find_each do |item|
          csv << columns.map { |col| item.public_send(col) }
        end
      end
    end
  end
end