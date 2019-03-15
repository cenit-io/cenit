module Setup
  module UploaderHelper
    extend ActiveSupport::Concern

    included do
      before_save do
        self.class.before_store_callbacks.each do |callback|
          instance_eval(&callback)
        end
        reset_lazy_storage.each do |field, store_options|
          store_on(field, store_options)
        end
      end

      after_save do
        readables.each { |file| file.try(:close) rescue nil }
        true
      end
    end

    def store(source, opts)
      uploader = opts.is_a?(CarrierWave::Uploader) ? opts : opts[:on]
      fail "Invalid options argument #{opts}, an uploader expected :on" unless uploader.is_a?(CarrierWave::Uploader::Base)
      field = uploader.mounted_as
      if source.is_a?(CarrierWave::Uploader::Base)
        send("#{field}=", uploader)
      else
        store_options = { data: source }
        %w(filename contentType metadata).each do |option|
          if (value = opts[option.to_sym] || opts[option])
            store_options[option] = value
          end
        end
        store_options.symbolize_keys!
        if opts[:immediately]
          store_on(field, store_options)
        else
          lazy_storage[field] = store_options
        end
      end
    end

    module ClassMethods
      def before_store(&block)
        before_store_callbacks << block
      end

      def before_store_callbacks
        @before_store_callbacks ||= []
      end
    end

    protected

    def lazy_storage
      @lazy_storage ||= {}
    end

    def store_on(field, store_options)
      data = store_options.delete(:data)
      if data.is_a?(String)
        temporary_file = Tempfile.new('data_')
        temporary_file.binmode
        temporary_file.write(data)
        temporary_file.rewind
        data = Cenit::Utility::Proxy.new(temporary_file,
                                         original_filename: store_options[:filename] || temporary_file.path.split('/').last,
                                         contentType: store_options[:contentType] || 'application/octet-stream')
      end
      readables << data
      send("#{field}=", data)
      send(field).try(:file_attributes=, store_options)
    end

    private

    def reset_lazy_storage
      tmp = lazy_storage
      @lazy_storage = nil
      tmp
    end

    def readables
      @temp_files ||= []
    end
  end
end
