module Mongoff
  module GridFs
    class File < Mongoff::Record

      include FileFormatter

      attr_accessor :encoding
      attr_reader :stash_data, :cursor

      def initialize(model, document = nil, new_record = true)
        raise "Illegal file model #{model}" unless model.is_a?(FileModel)
        super
        seek(0)
      end

      def to_s
        filename
      end

      def seek(pos)
        @cursor = pos
      end

      def rewind
        seek(0)
        stash_data.try(:rewind)
      end

      def file_store
        orm_model.data_type.file_store
      end

      def read(*args)
        file_store.read(self, *args) unless self.new_record?
      end

      def path
        filename
      end

      def save(options = {})
        if stash_data.nil?
          errors.add(:data, "can't be nil") if new_record?
        else
          self[:metadata] =
            if options.key?(:metadata)
              options[:metadata]
            else
              self[:metadata] || {}
            end
          self[:encoding] = options[:encoding] || self[:encoding]
          self[:length] = stash_data.size

          unless @custom_filename
            self[:filename] = options[:filename] || extract_basename(stash_data) || self[:filename] || options[:default_filename] || 'file'
          end

          unless @custom_content_type
            self[:contentType] = options[:contentType] || extract_content_type_from_io(stash_data) || extract_content_type(self[:filename]) || options[:default_contentType] || 'application/octet-stream'
          end

          self[:uploadDate] ||= Time.now.utc

          run_callbacks_and do
            file_data_errors =
              if options[:valid_data]
                []
              else
                orm_model.data_type.validate_file(self)
              end

            if file_data_errors.present?
              errors.add(:base, "Invalid file data: #{file_data_errors.to_sentence}")
            else
              begin
                file_store.save(self, stash_data, options)
              rescue Exception => ex
                errors.add(:data, ex.message)
              end
            end
          end
        end

        errors.blank? && super
      end

      def destroy
        file_store.destroy(self)
        super
      end

      def data
        rewind
        read
      end

      def data=(string_or_readable)
        seek(0)
        if (@stash_data = string_or_readable)
          self.length = stash_data.size
        end
      end

      def [](field)
        field = field.to_s.to_sym
        case field
        when :data
          data
        when :encoding
          encoding
        else
          super
        end
      end

      def []=(field, value)
        field = field.to_s.to_sym
        case field
        when :data
          self.data = value
        when :encoding
          self.encoding = value
        else
          value = super
          case field
          when :filename
            @custom_filename = value
          when :contentType
            @custom_content_type = value
          end
        end
      end

      def decode(data)
        case encoding
        when 'base64', 'strict_base64', 'urlsafe_base64'
          Base64.send(encoding.gsub('base', 'decode'), data)
        else
          data
        end
      end

      def extract_basename(object)
        m = [
          :original_path, :original_filename, :path, :filename, :pathname, :path, :to_path
        ].detect { |m| object.respond_to?(m) }
        file_name = m && object.send(m)
        file_name && clean(file_name).squeeze('/')
      end

      def extract_content_type_from_io(object)
        m = [:content_type, :contentType].detect { |m| object.respond_to?(m) }
        m && object.send(m)
      end

      def extract_content_type(filename)
        mime_type = MIME::Types.type_for(::File.basename(filename.to_s)).first
        mime_type ? mime_type.to_s : self[:contentType]
      end

      def clean(path)
        basename = ::File.basename(path.to_s)
        CGI.unescape(basename).gsub(%r/[^0-9a-zA-Z_@)(~.-]/, '_').gsub(%r/_+/, '_')
      end

      private :extract_basename, :extract_content_type_from_io, :extract_content_type, :clean

    end
  end
end