module Setup
  class Schema
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    belongs_to :library, class_name: Setup::Library.to_s

    field :uri, type: String
    field :schema, type: String

    has_many :data_types, class_name: Setup::DataType.to_s

    validates_length_of :uri, :maximum => 255
    validates_uniqueness_of :uri
    validates_presence_of :library, :uri, :schema

    before_save :create_data_types
    after_save :bind_data_types
    before_destroy :destroy_data_types

    def load_models(force_load=true)
      models = []
      data_types.each do |data_type|
        if data_type.activated && model = data_type.load_model(force_load)
          models << model
        end
      end
      RailsAdmin::AbstractModel.update_model_config(models)
    end

    rails_admin do

      object_label_method do
        :uri
      end

      edit do
        field :library do
          read_only { !bindings[:object].new_record? }
          inline_edit false
        end

        field :uri do
          read_only { !bindings[:object].new_record? }
        end

        field :schema
      end
      list do
        fields :library, :uri, :schema, :data_types
      end
    end

    private

    def create_data_types
      @created_data_types = []
      begin
        (schemas = parse_schemas).each do |name, schema|
          name = name.underscore.camelize
          data_type = Setup::DataType.create(name: name, schema: schema.to_json, auto_load_model: true)
          if data_type.errors.blank?
            @created_data_types << data_type
          else
            data_type.errors.each do |attribute, error|
              errors.add(:schema, "when defining model #{name} on attribute '#{attribute}': #{error}")
            end
            destroy_data_types
            return false
          end
        end
      rescue Exception => ex
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        destroy_data_types
        return false
      end
      return true
    end

    def bind_data_types
      @created_data_types.each do |data_type|
        data_type.uri = self
        data_type.save
      end
    end

    def destroy_data_types
      Schema.shutdown_data_type_model(@created_data_types || self.data_types, true)
    end

    def self.shutdown_data_type_model(data_types, destroy_data_type=false)
      return unless data_types
      data_types = [data_types] unless data_types.is_a?(Enumerable)
      report={destroyed: Set.new, affected: Set.new}
      data_types.each do |data_type|
        begin
          r = data_type.destroy_model
          report[:destroyed] = report[:destroyed] + r[:destroyed]
          report[:affected] = report[:affected] + r[:affected]
          data_type.destroy if destroy_data_type
        rescue Exception => ex
          #raise ex
          puts "Error destroying model #{data_type.name}: #{ex.message}"
        end
      end
      puts "Report: #{report.to_s}"
      post_process_report(report)
      puts "Post processed report #{report}"
      puts 'Reloading affected models...' unless report[:affected].empty?
      report[:affected].each do |model|
        begin
          if data_type = DataType.find_by(:id => model.data_type_id) rescue nil
            puts "Reloading #{model.to_s}"
            data_type.load_model
          else
            puts "Model #{model.to_s} reload on parent reload!"
          end
        rescue
          report[:destroyed] << model
          report[:affected].delete(model)
        end
        puts "Model #{model.to_s} reloaded!"
      end
      puts "Final report #{report}"
      RailsAdmin::AbstractModel.update_model_config([], report[:destroyed], report[:affected])
    end

    def self.post_process_report(report)
      affected_children =[]
      report[:affected].each { |model| affected_children << model if ancestor_included(model, report[:affected]) }
      report[:affected].delete_if { |model| affected_children.include?(model) }
    end

    def self.ancestor_included(model, container)
      parent = model.parent
      while !parent.eql?(Object)
        return true if container.include?(parent)
        parent = parent.parent
      end
      return false
    end

    def parse_schemas
      self.schema = self.schema.strip
      if self.schema.start_with?('{')
        parse_json_schema
      else
        parse_xml_schema
      end
    end

    def parse_json_schema
      json = JSON.parse(self.schema)
      if json['type'] || json['allOf']
        name = self.uri
        if (index = name.rindex('/')) || index = name.rindex('#')
          name = name[index+1, name.length-1]
        end
        if index = name.rindex('.')
          name = name[0..index-1]
        end
        {name => json}
      else
        json
      end
    end

    def parse_xml_schema
      Xsd::Document.new(uri, self.schema).schema.json_schemas
    end
  end
end