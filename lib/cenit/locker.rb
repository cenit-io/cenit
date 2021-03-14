module Cenit
  module Locker
    extend self

    def adapter
      @adapter ||=
        if Cenit::Redis.client?
          RedisAdapter
        else
          MongoidAdapter
        end
    end

    delegate :lock_key,
             :unlock_key,
             :key_locked?,
             :clear,

             to: :adapter

    def key(obj)
      id = obj.respond_to?(:id) ? obj.id.to_s : obj.to_s
      "#{obj.class.to_s.collectionize.singularize}##{id}"
    end

    def lock(obj)
      lock_key(key(obj))
    end

    def unlock(obj)
      unlock_key(key(obj))
    end

    def locked?(obj)
      key_locked?(key(obj))
    end

    def locking(obj)
      if lock(obj)
        begin
          yield if block_given?
        ensure
          unlock(obj)
        end
      end
    end

    module MongoidAdapter
      extend self

      def lock_key(key)
        collection.insert_one(_id: key)
        true
      rescue
        false
      end

      def key_locked?(key)
        collection.find(_id: key).count > 0
      end

      def unlock_key(key)
        if (query = collection.find(_id: key)).count > 0
          query.delete_one
          true
        else
          false
        end
      end

      def clear
        collection.drop
      end

      def collection
        Mongoid.default_client[:locker]
      end
    end

    module RedisAdapter
      extend self

      LOCKED = 'locked'
      KEY_PREFIX = 'locker_'

      def prefixed(key)
        "#{KEY_PREFIX}#{key}"
      end

      def lock_key(key)
        key = prefixed(key)
        if Cenit::Redis.exists?(key)
          false
        else
          Cenit::Redis.set(key, LOCKED)
          true
        end
      end

      def key_locked?(key)
        Cenit::Redis.exists?(prefixed(key))
      end

      def unlock_key(key)
        Cenit::Redis.del(prefixed(key)) > 0
      end

      def clear
        keys = Cenit::Redis.keys("#{KEY_PREFIX}*")
        Cenit::Redis.del(*keys) if keys.count > 0
      end
    end
  end
end