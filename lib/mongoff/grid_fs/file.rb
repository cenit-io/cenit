module Mongoff
  module GridFs
    class File < Mongoff::Record

      include FileStuff

      def initialize(model, document = nil, new_record = true)
        raise "Illegal file model #{model}" unless model.is_a?(FileModel)
        super
        seek(0)
      end

      def initialize_attrs(model, attributes)
        writing_content { super }
      end

      def do_validate(options = {})
        validate_file_stuff(options)
        super
      end

      def insert_or_update(options = {})
        insert_or_update_file_stuff(options) &&
          super
      end

      def destroy
        destroy_file_stuff
        super
      end
    end
  end
end