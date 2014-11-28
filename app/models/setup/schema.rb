module Setup
  class Schema
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    def self.model_listeners
      @model_listeners ||= []
    end

    field :uri, type: String
    field :schema, type: String

    has_many :data_types, class_name: 'Setup::DataType'

    validates_length_of :uri, :maximum => 255
    validates_uniqueness_of :uri
    validates_presence_of :uri, :schema

    before_save :create_data_types
    after_save :bind_data_types
    before_destroy :destroy_data_types

    def load_models(force_load=true)
      models = []
      data_types.each { |data_type| models << data_type.load_model(force_load) }
      notify(:model_loaded, models)
    end

    rails_admin do

      object_label_method do
        :uri
      end

      edit do
        field :uri do
          read_only { !bindings[:object].new_record? }
        end

        field :schema
      end
      list do
        fields :uri, :schema, :data_types
      end
    end

    private

    def notify(call_sym, model=self.name)
      return unless model
      Schema.model_listeners.each do |listener|
        begin
          puts "Notifying #{listener.to_s}.#{call_sym.to_s}(#{model.to_s})"
          listener.send(call_sym, model)
        rescue Exception => ex
          puts "'ERROR: invoking \'#{call_sym}\' on #{listener.to_s}: #{ex.message}"
        end
      end
    end

    def create_data_types
      @created_data_types = []
      begin
        (schemas = parse_schemas).each do |name, schema|
          name = name.underscore.camelize
          data_type = Setup::DataType.create(name: name, schema: schema.to_json)
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
        models = []
        @created_data_types.each do|data_type|
          models << data_type.load_model
          create_default_events(data_type)
        end
        notify(:model_loaded, models)
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
      if @created_data_types ||= self.data_types
        report={destroyed: Set.new, affected: Set.new}
        @created_data_types.each do |data_type|
          begin
            r = data_type.destroy_model
            report[:destroyed] = report[:destroyed] + r[:destroyed]
            report[:affected] = report[:affected] + r[:affected]
            data_type.destroy
          rescue Exception => ex
            #raise ex
            puts "Error destroying model #{data_type.name}: #{ex.message}"
          end
        end
        puts "Report: #{report.to_s}"
        post_process_report(report)
        puts "Post processed report #{report}"
        report[:affected].each do |model|
          begin
            data_type = DataType.find_by(:name => model.to_s)
            puts "Reloading #{model.to_s}"
            data_type.load_model
          rescue
            report[:destroyed] << model
            report[:affected].delete(model)
          end
          puts "Model #{model.to_s} reloaded!"
        end
        puts "Final report #{report}"
        notify(:remove_model, report[:destroyed])
        notify(:model_loaded, report[:affected])
      end
    end

    def post_process_report(report)
      affected_children =[]
      report[:affected].each { |model| affected_children << model if ancestor_included(model, report[:affected]) }
      report[:affected].delete_if { |model| affected_children.include?(model) }
    end

    def ancestor_included(model, container)
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
      name = self.uri
      if (index = name.rindex('/')) || index = name.rindex('#')
        name = name[index+1, name.length-1]
      end
      if index = name.rindex('.')
        name = name[0..index-1]
      end
      {name => json}
    end

    def parse_xml_schema
      Xsd::Document.new(uri, self.schema).schema.json_schemas
    end

    def create_default_events(data_type)
      if data_type.is_object
        puts "Creating default events for #{data_type.name}"
        Setup::Event.create(data_type: data_type, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}} ').save
        Setup::Event.create(data_type: data_type, triggers: '{"updated_at":{"0":{"o":"_change","v":["","",""]}}} ').save
      end
    end
  end
end