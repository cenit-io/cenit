module Cenit
  module Locker
    class << self

      def locking(obj)
        if lock(obj)
          begin
            yield if block_given?
          ensure
            unlock(obj)
          end
        end
      end

      def lock(obj)
        collection.insert_one(_id: obj_id(obj))
        true
      rescue
        false
      end

      def locked?(obj)
        collection.find(_id: obj_id(obj)).present?
      end

      def unlock(obj)
        if (query = collection.find(_id: obj_id(obj))).present?
          query.delete_one
          true
        else
          false
        end
      end

      def clear
        collection.drop
      end

      private

      def obj_id(obj)
        id = obj.respond_to?(:id) ? obj.id.to_s : obj.to_s
        "#{obj.class.to_s.collectionize.singularize}_#{id}"
      end

      def collection
        Mongoid.default_client[:locker]
      end
    end
  end
end