module Setup
  module UploaderHelper
    extend ActiveSupport::Concern

    included do

      before_save do
        self.class.before_store_callbacks.each do |callback|
          instance_eval(&callback)
        end
        reset_lazy_storage.each do |field, data|
          store_on(field, data)
        end
      end

      after_save do
        readables.each { |file| file.try(:close) rescue nil }
        true
      end
    end

    def store(source, opts)
      uploader = opts.is_a?(CarrierWave::Uploader) ? opts : opts[:on]
      fail "Ivalid options argument #{opts}, an uploader expected :on" unless uploader.is_a?(CarrierWave::Uploader::Base)
      field = uploader.mounted_as
      if source.is_a?(CarrierWave::Uploader::Base)
        send("#{field}=", uploader)
      else
        if opts[:immediately]
          store_on(field, source)
        else
          lazy_storage[field] = source
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

    def store_on(field, data)
      if data.is_a?(String)
        temporary_file = Tempfile.new('data_')
        temporary_file.binmode
        temporary_file.write(data)
        temporary_file.rewind
        data =  File.open(temporary_file)
      end
      readables << data
      send("#{field}=", data)
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