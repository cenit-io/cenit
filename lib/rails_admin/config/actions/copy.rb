module RailsAdmin
  module Config
    module Actions
      class Copy < RailsAdmin::Config::Actions::Base

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            model = abstract_model.model rescue nil
            if model
              if @object.is_a?(Mongoff::GridFs::File)
                copy = model.new(@object.default_hash(ignore: [:id, :data]))
                copy.filename =
                  if (match = @object.filename.match(/\A(.*)(\.[^.]*)\Z/))
                    "#{match[1]}_copy#{match[2]}"
                  else
                    "#{@object.filename}(copy)"
                  end
                copy.data = @object
                copy.save
                if copy.errors.blank?
                  redirect_to rails_admin.edit_path(model_name: abstract_model.to_param, id: copy.id)
                else
                  do_flash(:error, 'File copy failed', copy.errors.full_messages)
                  redirect_to back_or_index
                end
              else
                hash = @object.is_a?(::Mongoff::Record) ? @object.share_hash : @object.copy_hash
                hash.delete('_primary')
                token = Cenit::Token.create(data: hash.to_json, token_span: 300).token
                redirect_to rails_admin.new_path(model_name: model.to_s.underscore.gsub('/', '~'), params: { json_token: token })
              end
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-files-o'
        end
      end
    end
  end
end