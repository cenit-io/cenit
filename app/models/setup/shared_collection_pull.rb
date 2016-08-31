module Setup
  class SharedCollectionPull < Setup::BasePull

    build_in_data_type

    belongs_to :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    def source_shared_collection
      shared_collection
    end

    def run(message)
      fail 'No shared collection to pull' unless source_shared_collection
      super
    end

    class << self

      def process(message = {}, &block)
        case message
        when Setup::CrossSharedCollection
          shared_collection = message
          message = {}
        when Hash
          shared_collection = message.delete(:shared_collection)
        else
          fail 'Invalid message'
        end
        message[:task] = create!(shared_collection: shared_collection)
        super
      end
    end

    protected

    def ask_for_install?
      User.current_super_admin? && !shared_collection.installed?
    end
  end
end
