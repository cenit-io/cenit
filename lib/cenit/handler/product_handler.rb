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
        count = 0
        params.each do |p|

          next if p[:id].empty?

          p[:variants_attributes] = process_variants(p.delete :variants) if p.has_key?(:variants)
          p[:images_attributes] = process_images(p.delete :images) if p.has_key?(:images)

          @product = Hub::Product.where(id: p[:id]).first
          if @product
            @product.update_attributes(p)
          else
            @product = Hub::Product.new(p)
          end
          count += 1 if @product.save
        end
        {'products' => count}
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

      def process_options(options_params)
        return [] if options_params.nil?
        options_params.map {|k, v| {:option_type => k, :option_value => v}}
      end

    end
  end
end
