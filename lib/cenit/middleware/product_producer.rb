require 'json'


module Cenit
  module Middleware
    class ProductProducer < Producer

      def self.process(object, path)
        product = process_product(object)
        super product, path, object.connection_id
      end

      def self.process_product(object)
        product = JSON.parse(object.to_json)
        product.delete 'connection_id'
        product.delete '_id'

        if product['variants'].present?
          product['variants'] = process_variants(product.delete 'variants')
        end
        if product['taxons'].present?
          product['taxons'] = process_taxons(product.delete 'taxons')
        end
        if product['properties'].present?
          product['properties'] = process_properties(product.delete 'properties')
        end

        {'product' => product}
      end

      def self.process_taxons(taxons_params)
        taxons_params.map {|x| x['breadcrumb']}
      end

      def self.process_properties(properties_params)
        properties = {}
        properties_params.each do |x|
          properties[x['name']] = x['presentation']
        end
        properties
      end

      def self.process_variants(variants_params)
        variants = []
        variants_params.each do |x|
          if x['options'].present?
            options = x.delete 'options'
            x['options'] = {}
            options.each do |o|
              x['options'][o['option_type']] = o['option_value']
            end
          end
          x.delete 'images'
          variants << x
        end
        variants
      end

    end
  end
end
