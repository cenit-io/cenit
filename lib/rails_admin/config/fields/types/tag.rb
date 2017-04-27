module RailsAdmin
  module Config
    module Fields
      module Types
        class Tag < RailsAdmin::Config::Fields::Base

          register_instance_option :partial do
            :form_tag
          end

          register_instance_option :tag_enum_method do
            @tag_enum_method ||= bindings[:object].class.respond_to?("#{name}_values") || bindings[:object].respond_to?("#{name}_values") ? "#{name}_values" : nil
          end

          register_instance_option :all_tags do
            if tag_enum_method
              if bindings[:object].class.respond_to?(tag_enum_method)
                bindings[:object].class
              else
                bindings[:object]
              end.send(tag_enum_method)
            else
              abstract_model.model.distinct(name).flatten.collect do |tags|
                tags = JSON.parse(tags) rescue [tags.to_s]
                tags.to_a
              end.flatten.uniq
            end
          end

          register_instance_option :selected_tags do
            tags = JSON.parse(value) rescue [value.to_s]
            tags.to_a
          end

          register_instance_option :pretty_value do
            html='<div class="tag">'
            html+=
              selected_tags.collect do |tag|
                "<span>#{tag}</span>"
              end.join
            html+='</div>'
            html.html_safe
          end

          def parse_input(params)
            if (tags = params[name]).is_a?(Enumerable)
              params[name] = tags.collect(&:to_s).collect(&:downcase).uniq.select(&:present?).to_json
            end
          end
        end
      end
    end
  end
end