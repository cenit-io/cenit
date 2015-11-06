module RailsAdmin
  module Config
    module Fields
      module Types
        class StorageFile < RailsAdmin::Config::Fields::Types::Carrierwave


          register_instance_option :pretty_value do
            if value.presence
              v = bindings[:view]
              url = resource_url
              if image
                thumb_url = resource_url(thumb_method)
                url != thumb_url ? v.link_to(v.image_tag(thumb_url, class: 'img-polaroid'), url, target: 'blank') : v.image_tag(thumb_url)
              else
                v.link_to(value, url, target: 'blank')
              end
            end
          end

        end
      end
    end
  end
end
