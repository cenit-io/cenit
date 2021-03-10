class FileController < ApplicationController

  include OAuth2AccountAuthorization
  include CorsCheck

  before_action :allow_origin_header
  before_action :soft_authorize_account, except: [:cors_check]
  before_action :check_user_signed_in, except: [:cors_check]

  def index
    model = nil
    if (model_desc = params[:model])
      model = Object
      model_desc.split('~').each do |token|
        next unless model
        model =
          begin
            model.const_get(token.camelize)
          rescue
            nil
          end
      end
    end
    if model && (record = model.where(id: params[:id]).first)
      if authorization_adapter.can?(:show, record) || (model == User && params[:field] == 'picture') #TODO remove when authorize to view users profile
        uploader = record.try(field = params[:field])
        if uploader.is_a?(BasicUploader)
          if (filename = params[:file])
            filename = "#{filename}.#{params[:format]}" if params[:format]
          end
          if (filename.nil? || (uploader = find_version(uploader, uploader.path_for(record, field, filename)))) &&
            (content = uploader.read)
            send_data content,
                      filename: uploader.identifier,
                      type: uploader.file.content_type,
                      disposition: 'inline'
          else
            not_found
          end
        else
          not_found
        end
      else
        unauthorized
      end
    else
      not_found
    end
  end

  protected

  def authorization_adapter
    @authorization_adapter ||= Ability.new(current_user)
  end

  def find_version(uploader, path)
    if uploader.path == path
      uploader
    else
      uploader.versions.values.each do |uploader_version|
        if (uploader = find_version(uploader_version, path))
          return uploader
        end
      end
      nil
    end
  end

  def not_found
    render plain: 'Not found', status: :not_found
  end

  def unauthorized
    render plain: 'Unauthorized', status: :unauthorized
  end
end