module RailsAdmin
  module Config
    module Fields
      module Types
        FileUpload.class_eval do
          register_instance_option :pretty_value do
            if value.presence
              v = bindings[:view]
              url = resource_url
              if image
                thumb_url = resource_url(thumb_method)
                logo_background = bindings[:object].try(:logo_background)
                image_html = v.image_tag(thumb_url, class: logo_background ? 'logo' : 'img-thumbnail')
                if logo_background
                  image_html = "<div style=\"background-color:##{logo_background}\">#{image_html}</div>".html_safe
                end
                url != thumb_url ? v.link_to(image_html, url, target: '_blank') : image_html
              else
                v.link_to(nil, url, target: '_blank')
              end
            end
          end
        end
      end
    end
  end
end
