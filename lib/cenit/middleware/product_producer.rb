require 'json'

module Cenit
  module Middleware
    class ProductProducer < Producer

      def self.process(object, path)
        product = process_product(object)
        super product, path, object.connection_id
      end

      def self.process_product(object)
        p = JSON.parse(object.to_json)
        p.delete 'connection_id'
        p.delete '_id'
        
        p['variants'] = process_variants(p.delete 'variants') if p['variants'].present?
        p['taxons'] = process_taxons(p.delete 'taxons')  if p['taxons'].present?
        p['properties'] = process_properties(p.delete 'properties') if p['properties'].present?
        p['images'] = process_properties(p.delete 'images') if p['images'].present?
        
        {'product' => p}
      end

      def self.process_taxons(taxons_params)
        taxons_params.map { |t| t['breadcrumb'] }
      end  

      end

      def self.process_properties(properties_params)
        properties = {}
        properties_params.each { |p| properties[p['name']] = p['presentation'] }
        properties
      end

      def self.process_variants(variants_params)
        variants = []
        variants_params.each do |v|
          v.delete '_id' if v.has_key? '_id'
          v['options'] = process_options(v.delete 'options') if v['options'].present?
          v['images'] = process_images(v.delete 'images') if v['images'].present?
          variants << v
        end
        variants
      end
      
      def self.process_options(options_params)
        options = {}
        options.each {|o| options[o['option_type']] = o['option_value']} 
        options
      end  
      
      def self.process_images(images_params)
        images = []
        images_params.each do |i|
          i.delete '_id' if i.has_key? '_id'
          i['dimension'] = process_dimension(i.delete 'dimension') if i['dimension'].present?          
          images << i
        end
        images
      end
      
      def self.process_images(dimension_params)
        dimension_params.delete '_id' if dimension_params.has_key? '_id'
        dimension_params
      end

    end
  end
end
