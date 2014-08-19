module Cenit
  module Handler
    class ProductHandler < Base
      attr_reader :params, :options, :taxon_ids, :parent_id, :url

      def initialize(message, endpoint)
        super message
        @params = @payload[:products]
        @url = endpoint.url.gsub('/wombat', '')
      end

      def process
        product_ids = []
        params.each do |p|

          next if p[:id].empty?

          p[:variants_attributes] = process_variants(p.delete :variants) if p.has_key?(:variants)
          p[:taxons_attributes] = process_taxons(p.delete :taxons) if p.has_key?(:taxons)
          p[:properties_attributes] = process_properties(p.delete :properties) if p.has_key?(:properties)
          p[:images_attributes] = process_images(p.delete :images) if p.has_key?(:images)

          @product = Hub::Product.where(id: p[:id]).first
          if @product
            @product.update_attributes(p)
          else
            @product = Hub::Product.new(p)
          end
          product_ids << @product.save ? @product.id : 0
        end
        response "Products saved: #{product_ids.to_s}"
      end

      def process_variants(variants_params)
        return [] if variants_params.nil?
        variants = []
        variants_params.each do |v|
          v[:options_attributes] = process_options(v.delete :options) if v.has_key?(:options)
          v[:images_attributes] = process_images(v.delete :images) if v.has_key?(:images)
          variants << v
        end
        variants
      end

      def process_images(images_params)
        return [] if images_params.nil?
        images = []
        images_params.each do |i|
          i[:dimension_attributes] = process_dimension(i.delete :dimension) if i[:dimension].present?
          i[:url] = @url + i[:url]
          images << i
        end
        images
      end

      def process_dimension(dimension_params)
        return {} if dimension_params.nil?
        dimension_params
      end

      def process_taxons(taxons_params)
        return [] if taxons_params.nil?
        taxons_params.map {|x| {:breadcrumb => x}}
      end

      def process_properties(properties_params)
        return [] if properties_params.nil?
        properties_params.map {|k, v| {:name => k, :presentation => v}}
      end

      def process_options(options_params)
        return [] if options_params.nil?
        options_params.map {|k, v| {:option_type => k, :option_value => v}}
      end

    end
  end
end
