module Setup
  module WithSourceOptions

    def base_execution_options(options)
      opts = super
      opts.merge!(source_options(options))
      opts
    end

    def source_options(options, source_key_options = self.source_key_options)
      data_type_key = source_key_options[:data_type_key] || :source_data_type
      if (data_type = send(data_type_key) || options[data_type_key] || options[:data_type])
        model = data_type.records_model
        offset = options[:offset] || 0
        limit = options[:limit]
        source_options =
          if source_key_options[:bulk]
            {
              source_key_options[:sources_key] || :sources =>
                if (object_ids = options[:object_ids])
                  model.any_in(id: (limit ? object_ids[offset, limit] : object_ids.from(offset))).to_enum
                elsif (objects = options[:objects])
                  objects
                else
                  enum = (limit ? model.limit(limit) : model.all).skip(offset).to_enum
                  options[:object_ids] = enum.collect { |obj| obj.id.is_a?(BSON::ObjectId) ? obj.id.to_s : obj.id }
                  enum
                end
            }
          else
            {
              source_key_options[:source_key] || :source =>
                begin
                  obj = options[:object] ||
                    ((id = (options[:object_id] || (options[:object_ids] && options[:object_ids][offset]))) && model.where(id: id).first) ||
                    model.all.skip(offset).first
                  options[:object_ids] = [obj.id.is_a?(BSON::ObjectId) ? obj.id.to_s : obj.id] unless options[:object_ids] || obj.nil?
                  obj
                end
            }
          end
        { source_data_type: data_type }.merge(source_options)
      else
        {}
      end
    end

    def source_key_options
      {}
    end
  end
end
