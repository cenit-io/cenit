module Setup
  class FileDataType < Model

    SCHEMA =
      {
        type: :object,
        properties:
          {
            filename: {
              title: 'File name',
              type: :string
            },
            contentType: {
              title: 'Content type',
              type: :string
            },
            length: {
              title: 'Size',
              type: :integer
            },
            uploadDate: {
              title: 'Uploaded at',
              type: :string,
              format: :time
            },
            file: {
              type: :object,
              properties: {
                chunks: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {},
                  },
                  referenced: true,
                  visible: false
                }
              },
              referenced: true,
              visible: false,
              virtual: true
            }
          }
      }.to_json.freeze

    BuildInDataType.regist(self).referenced_by(:name, :library).with(:title, :name, :_type, :validator)

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :file_data_types
    belongs_to :validator, class_name: Setup::Validator.to_s, inverse_of: nil

    attr_readonly :library

    validates_presence_of :library

    before_save do
      self.title = self.name if title.blank?
    end

    def data_type_collection_name
      Account.tenant_collection_name(data_type_name)
    end

    def all_data_type_collections_names
      [name = data_type_collection_name, name + '.files', name + '.chunks']
    end

    def is_object?
      true
    end

    def model_schema
      SCHEMA
    end

    def validate_file!(readable)
      readable.rewind
      validator.validate_data!(readable.read) if validator.present?
      readable.rewind
    end

    def new_from(readable, attributes={})
      raise Exception("Model '#{on_library_title}' is not loaded") unless model = self.model
      validate_file!(readable)
      attributes = attributes.merge(filename: readable.original_filename) unless attributes[:filename]
      file = model.file_model.namespace.put(readable, attributes)
      model.where(file: file).first
    end

    protected

    def do_load_model(report)
      Object.const_set(data_type_name, model = Class.new { class_eval(&FILE_MODEL_MIXIN); self })
      file_model = Cenit::GridFs.build_grid_file_model(model)
      model.belongs_to(:file, class_name: file_model.to_s, inverse_of: nil)
      [file_model, file_model.chunk_model].each { |m| m.include(Setup::ClassAffectRelation) }
      file_model.affects_to(model)
      {
        model => ['', title],
        file_model => %w(/properties/file File),
        file_model.chunk_model => %w(/properties/file/properties/chunks/items Chunk)
      }.each do |model, values|
        model.class_eval("def self.data_type
            Setup::FileDataType.where(id: '#{self.id}').first
          end
          def self.schema_path
            '#{values[0]}'
          end
          def self.title
            '#{values[1]}'
          end
          def orm_model
            self.class
          end")
      end
      model.class_eval do
        class << self

          def file_model
            const_get(:File.to_s)
          end

          def chunk_model
            file_model.chunk_model
          end

          def all_collections_names
            [collection_name, file_model.collection_name, chunk_model.collection_name]
          end
        end
      end
      model
    end

    private

    FILE_MODEL_MIXIN = proc do
      Setup::Model.to_include_in_models.each do |module_to_include|
        include(module_to_include) unless include?(module_to_include) || [RailsAdminDynamicCharts::Datetime].include?(module_to_include)
      end

      field :filename, type: String
      field :contentType, type: String
      field :length, type: Integer
      field :uploadDate, type: Time

      def update_from(grid_file)
        self.file = grid_file
        %w(filename contentType length uploadDate).each { |method| send("#{method}=", grid_file.send(method)) }
        save
      end

      before_destroy do
        file.destroy
      end

      class << self
        def update_for(grid_file)
          wrapper = where(file: grid_file).first || new
          wrapper.update_from(grid_file)
        end
      end
    end
  end
end