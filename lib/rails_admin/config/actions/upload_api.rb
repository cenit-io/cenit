require 'yaml'
require 'fileutils'

module RailsAdmin
  module Config
    module Actions
      class UploadApi < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Setup::Collection]
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            selector_config = RailsAdmin::Config.model(Forms::UploadApi)
            model = @abstract_model.model rescue nil
            @form_object ||= Forms::UploadApi.new
            if request.get?
              @model_config = selector_config
              render :form
            end
            if request.post?
              spec = {}
              @model_config = selector_config
              if !(data = params['forms_upload_api']['data']).present? &&
                 !(file = params['forms_upload_api']['file']).present?
                flash[:error]= 'You must select data or file'
                render :form
              else
                spec = data if data
                spec = file.read() if file
                puts spec
                do_flash_process_result Setup::UploadApi.process(data: spec)
                redirect_to back_or_index
              end
            end
            end
          end

        register_instance_option :link_icon do
          'icon-upload'
        end


      end
    end
  end
end
