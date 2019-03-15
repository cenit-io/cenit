module Cenit
  ###
  # Setup notebooks.
  class Notebooks
    include RailsAdmin::RestApiHelper
    include RailsAdmin::RestApi::Notebooks

    def self.startup
      ranb = self.new
      ranb.create_default_directories
      ranb.create_rest_api
    end

    ###
    # Create default directories.
    def create_default_directories
      default_directories.each do |attrs|
        attrs[:type] = :directory
        directory = Setup::Notebook.where(attrs).first_or_create
        directory.origin = :shared
      end
    end

    ###
    # Create all rest-api doc as notebooks.
    def create_rest_api
      Setup::CenitDataType.all.each do |dt|
        @params = {}
        @data_type = dt
        @abstract_model = abstract_model_class
        @properties = @abstract_model.properties

        # Generate rest-api doc as notebook.
        api_langs.each { |lang| api_notebook(lang) if lang[:runnable] }
      end
    end

    def abstract_model_class
      model = @data_type.records_model
      model.is_a?(Class) ? RailsAdmin::AbstractModel.new(model) : RailsAdmin::MongoffAbstractModel.new(model)
    end

    def default_directories
      [
        {name: 'REST-API', parent: ''},
        {name: 'SHOWCASE', parent: ''},
        {name: 'COMMUNITY', parent: ''},
      ]
    end
  end
end