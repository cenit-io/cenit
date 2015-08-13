module Capataz
  class HashProxy < Proxy

    def []=(key, value)
      key = key.capataz_slave if key.capataz_proxy?
      @obj[key] = value
    end

    def [](key)
      key = key.capataz_slave if key.capataz_proxy?
      value = @obj[key]
      value.capataz_proxy? ? value.capataz_slave : value
    end
  end
end