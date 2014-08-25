require 'json'

module Cenit
  module Middleware
    class ProductProducer < Producer

      def self.process(object, path)
        product = process_product(object)
        super product, path
      end

      def self.process_product(object=nil)
        return {} if object.nil?

        p = JSON.parse(object.to_json)
        p.delete '_id'

        p['variants'] = process_variants(p.delete 'variants') if p['variants'].present?
        p['images'] = process_images(p.delete 'images') if p['images'].present?

        {'product' => p}
      end

      def self.process_variants(variants_params)
        variants = []
        variants_params.each do |v|
          v.delete '_id' if v.has_key? '_id'
          v.delete 'created_at' if v.has_key? 'created_at'
          v['images'] = process_images(v.delete 'images') if v['images'].present?
          variants << v
        end
        variants
      end

      def self.process_images(images_params)
        images = []
        images_params.each do |i|
          i.delete '_id' if i.has_key? '_id'
          i['dimension'] = process_dimension(i.delete 'dimension') if i['dimension'].present?
          i['position'] = i['position'].to_i
          images << i
        end
        images
      end

      def self.process_dimension(dimension_params)
        dimension_params.delete '_id' if dimension_params.has_key? '_id'
        dimension_params
      end

    end
  end
end
