module Setup
  class PullImport < Setup::BasePull
    include Setup::DataUploader

    build_in_data_type

    def self.enqueue_payload(request, model, options = {})
      readable = if request.media_type == 'multipart/form-data'
                   request.params[:data] || request.params[:file]
                 else
                   request.body
                 end
      raise ArgumentError, 'Missing collection data' unless readable

      readable.rewind
      data = JSON.parse(readable.read)
      data = [data] if data.is_a?(Hash)
      unless data.is_a?(Array) && !data.empty? && data.all?(Hash)
        raise ArgumentError, 'Expected a JSON object or an array of objects'
      end
      discard_collection = model != Setup::Collection
      if discard_collection
        property = Setup::Collection::COLLECTING_PROPERTIES.find do |name|
          Setup::Collection.reflect_on_association(name).klass >= model
        end
        raise ArgumentError, 'This model is not part of a collection' unless property

        data = { property => data }
      else
        raise ArgumentError, 'Expected one collection' unless data.length == 1

        data = data.first
        unless data['name'].is_a?(String) && data['name'].present?
          raise ArgumentError, 'Missing collection name'
        end
      end

      execution = process(data: data.to_json, discard_collection: discard_collection,
                          task_description: options['task_description'])
      raise ArgumentError, execution.message if execution.is_a?(Setup::SystemNotification)

      execution
    end

    def run(message)
      message[:discard_collection] = true unless message.has_key?('discard_collection')
      super
    end

    protected

    def source_collection_data
      @source_collection_data ||= hashify(data)
    end

  end
end
