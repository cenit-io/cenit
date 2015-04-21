module Cenit
  class GridFs < CarrierWave::Storage::GridFS
    class File < CarrierWave::Storage::GridFS::File

      def initialize(uploader, path, grid = nil)
        super(uploader, path)
        @_grid = grid
      end

      def grid
        @_grid || super
      end

      self.grid = Mongoid::GridFs.build_namespace_for(Cenit)

      self.grid.file_model.store_in collection: Proc.new { "#{Account.tenant_collection_prefix}.files" }
      self.grid.chunk_model.store_in collection: Proc.new { "#{Account.tenant_collection_prefix}.chunks" }
    end

    def store!(file)
      if (data_type = uploader.model.try(:data_type)).is_a?(Setup::FileDataType)
        data_type.validate_file!(file)
      end
      stored = Cenit::GridFs::File.new(uploader, uploader.store_path, uploader.try(:grid))
      stored.write(file)
      stored
    end

    def retrieve!(identifier)
      Cenit::GridFs::File.new(uploader, uploader.store_path(identifier), uploader.try(:grid))
    end

    class << self

      NamespaceMixin = proc do
        class << self
          attr_accessor :prefix
          attr_accessor :file_model
          attr_accessor :chunk_model

          # def to_s
          #   prefix
          # end

          def namespace
            prefix
          end

          def put(readable, attributes = {})
            chunks = []
            file = file_model.new
            attributes.to_options!

            if attributes.has_key?(:id)
              file.id = attributes.delete(:id)
            end

            if attributes.has_key?(:_id)
              file.id = attributes.delete(:_id)
            end

            if attributes.has_key?(:content_type)
              attributes[:contentType] = attributes.delete(:content_type)
            end

            if attributes.has_key?(:upload_date)
              attributes[:uploadDate] = attributes.delete(:upload_date)
            end

            if attributes.has_key?(:meta_data)
              attributes[:metadata] = attributes.delete(:meta_data)
            end

            if attributes.has_key?(:aliases)
              attributes[:aliases] = Array(attributes.delete(:aliases)).flatten.compact.map { |a| "#{ a }" }
            end

            md5 = Digest::MD5.new
            length = 0
            chunkSize = file.chunkSize
            n = 0

            Mongoid::GridFs.reading(readable) do |io|
              unless attributes.has_key?(:filename)
                attributes[:filename] =
                  [file.id.to_s, Mongoid::GridFs.extract_basename(io)].join('/').squeeze('/')
              end

              unless attributes.has_key?(:contentType)
                attributes[:contentType] =
                  Mongoid::GridFs.extract_content_type(attributes[:filename]) || file.contentType
              end

              Cenit::GridFs.chunking(io, chunkSize) do |buf|
                md5 << buf
                length += buf.size
                chunk = file.chunks.build
                chunk.data = binary_for(buf)
                chunk.n = n
                n += 1
                chunk.save!
                chunks.push(chunk)
              end
            end

            attributes[:length] ||= length
            attributes[:uploadDate] ||= Time.now.utc
            attributes[:md5] ||= md5.hexdigest

            #file.update_attributes(attributes)
            file.assign_attributes(attributes)

            file.save!
            file
          rescue
            chunks.each { |chunk| chunk.destroy rescue nil }
            raise
          end

          def binary_for(*buf)
            if defined?(Moped::BSON)
              Moped::BSON::Binary.new(:generic, buf.join)
            else
              BSON::Binary.new(buf.join, :generic)
            end
          end

          def get(id)
            file_model.find(id)
          end

          def delete(id)
            file_model.find(id).destroy
          rescue
            nil
          end

          def where(conditions = {})
            case conditions
            when String
              file_model.where(:filename => conditions)
            else
              file_model.where(conditions)
            end
          end

          def find(*args)
            where(*args).first
          end

          def [](filename)
            file_model.
              where(:filename => filename.to_s).
              order_by(:uploadDate => :desc).
              limit(1).
              first
          end

          def []=(filename, readable)
            put(readable, :filename => filename.to_s)
          end

          def clear
            file_model.destroy_all
          end

          # TODO - opening with a mode = 'w' should return a GridIO::IOProxy
          # implementing a StringIO-like interface
          #
          def open(filename, mode = 'r', &block)
            raise NotImplementedError
          end
        end
      end

      def build_grid_file_model(parent)
        model_name = :File.to_s
        file_model_name = "#{parent}::#{model_name}"
        file_model = build_file_model(parent, file_model_name)
        chunk_model = build_chunk_model(file_model_name)

        grid = Class.new { class_eval(&NamespaceMixin); self }
        file_model.namespace = grid
        chunk_model.namespace = grid

        file_model.chunk_model = chunk_model
        chunk_model.file_model = file_model

        grid.file_model = file_model
        grid.chunk_model = chunk_model

        parent.const_set(model_name, file_model)
        file_model.const_set(:Chunk, chunk_model)

        file_model.uploader = Class.new(CenitUploader) do
          self.grid = grid
        end

        prefix = file_model.to_s.collectionize
        grid.prefix = prefix
        file_model.store_in collection: Proc.new { "#{Account.tenant_collection_name(parent.to_s)}.files" }
        chunk_model.store_in collection: Proc.new { "#{Account.tenant_collection_name(parent.to_s)}.chunks" }

        file_model
      end

      def build_file_model(parent, file_model_name)
        chunk_model_name = "#{ file_model_name }::Chunk"

        Class.new do
          include Mongoid::Document
          include Mongoid::Timestamps
          include Mongoid::Attributes::Dynamic if Mongoid::VERSION.to_i >= 4

          singleton_class = class << self;
            self;
          end

          singleton_class.instance_eval do
            define_method(:name) { file_model_name }
            attr_accessor :namespace
            attr_accessor :chunk_model
            attr_accessor :defaults
            attr_accessor :uploader
          end


          self.defaults = Mongoid::GridFs::Defaults.new

          self.defaults.chunkSize = 4 * (mb = 2**20)
          self.defaults.contentType = 'application/octet-stream'

          field(:filename, :type => String)
          field(:contentType, :type => String, :default => defaults.contentType)
          field(:length, :type => Integer, :default => 0)
          field(:uploadDate, :type => Time, :default => Time.now.utc)


          field(:chunkSize, :type => Integer, :default => defaults.chunkSize)
          field(:md5, :type => String, :default => Digest::MD5.hexdigest(''))


          field(:aliases, :type => Array)
          field(:metadata) rescue nil

          required = %w( length chunkSize uploadDate md5 )

          required.each do |f|
            validates_presence_of(f)
          end

          index({:filename => 1})
          index({:aliases => 1})
          index({:uploadDate => 1})
          index({:md5 => 1})

          has_many(:chunks, :class_name => chunk_model_name, :inverse_of => :files, :dependent => :destroy, :order => [:n, :asc])

          def path
            filename
          end

          def basename
            ::File.basename(filename) if filename
          end

          def attachment_filename(*paths)
            return basename if basename

            if paths.empty?
              paths.push('attachment')
              paths.push(id.to_s)
              paths.push(updateDate.iso8601)
            end

            path = paths.join('--')
            base = ::File.basename(path).split('.', 2).first
            ext = Mongoid::GridFs.extract_extension(contentType)

            "#{ base }.#{ ext }"
          end

          def prefix
            self.class.namespace.prefix
          end

          def each(&block)
            fetched, limit = 0, 7

            while fetched < chunks.size
              chunks.where(:n.lt => fetched+limit, :n.gte => fetched).
                order_by([:n, :asc]).each do |chunk|
                block.call(chunk.to_s)
              end

              fetched += limit
            end
          end

          def slice(*args)
            case args.first
            when Range
              range = args.first
              first_chunk = (range.min / chunkSize).floor
              last_chunk = (range.max / chunkSize).floor
              offset = range.min % chunkSize
              length = range.max - range.min + 1
            when Fixnum
              start = args.first
              start = self.length + start if start < 0
              length = args.size == 2 ? args.last : 1
              first_chunk = (start / chunkSize).floor
              last_chunk = ((start + length) / chunkSize).floor
              offset = start % chunkSize
            end

            data = ''

            chunks.where(:n => (first_chunk..last_chunk)).order_by(n: 'asc').each do |chunk|
              data << chunk
            end

            data[offset, length]
          end

          def data
            data = ''
            each { |chunk| data << chunk }
            data
          end

          def base64
            Array(to_s).pack('m')
          end

          def data_uri(options = {})
            data = base64.chomp
            "data:#{ content_type };base64,".concat(data)
          end

          def bytes(&block)
            if block
              each { |data| block.call(data) }
              length
            else
              bytes = []
              each { |data| bytes.push(*data) }
              bytes
            end
          end

          def close
            self
          end

          def content_type
            contentType
          end

          def updateDate
            updatet_at
          end

          def update_date
            updateDate
          end

          # def created_at
          #   updateDate
          # end

          def namespace
            self.class.namespace
          end

          after_save do
              parent.update_for(self)
          end
        end
      end

      def build_chunk_model(file_model_name)
        chunk_model_name = "#{ file_model_name }::Chunk"

        Class.new do
          include Mongoid::Document

          singleton_class = class << self;
            self;
          end

          singleton_class.instance_eval do
            define_method(:name) { chunk_model_name }
            attr_accessor :file_model
            attr_accessor :namespace
          end

          field(:n, :type => Integer, :default => 0)
          field(:data, :type => (defined?(Moped::BSON) ? Moped::BSON::Binary : BSON::Binary))

          belongs_to(:file, :foreign_key => :files_id, :class_name => file_model_name)

          index({:files_id => 1, :n => -1}, :unique => true)

          def namespace
            self.class.namespace
          end

          def to_s
            data.data
          end

          alias_method 'to_str', 'to_s'
        end
      end

      def chunking(io, chunk_size, &block)
        if io.method(:read).arity == 0
          data = io.read
          i = 0
          loop do
            offset = i * chunk_size
            length = i + chunk_size < data.size ? chunk_size : data.size - offset

            break if offset >= data.size

            buf = data[offset, length]
            block.call(buf)
            i += 1
          end
        else
          while((buf = io.read(chunk_size)) && buf.size > 0)
            block.call(buf)
          end
        end
      end
    end
  end
end