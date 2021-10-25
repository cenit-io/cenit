require 'rails_helper'
RSpec.describe Api::V3::ApiController, type: :request do
  Setup::Models.all.each do |model|
    model_name_array = model.name.to_s.split('::')
    namespace = model_name_array.first.downcase
    underscore_model_name = model_name_array.last.underscore

    return if underscore_model_name === 'attachment' ||
              underscore_model_name === 'message' ||
              underscore_model_name === 'config' ||
              underscore_model_name === 'code' ||
              underscore_model_name === 'public_storage' ||
              underscore_model_name === 'cross_shared_collection'

    if namespace == "setup" || namespace == "cenit"
      describe "GET /api/v3/#{namespace}/#{underscore_model_name}" do
        context "fail retrieve all existing #{underscore_model_name}" do
          it "with missing header request" do
            get "/api/v3/#{namespace}/#{underscore_model_name}"
            expect(response).to have_http_status(:forbidden)
            expect(json_response[:error]).to eq("insufficient_scope")
            expect(json_response[:error_description]).to eq("The requested action is out of the access token scope")
          end

          it "with unauthorized token request" do
            get "/api/v3/#{namespace}/#{underscore_model_name}", headers: {
                Authorization: "Bearer unauthorized_token }"
            }
            expect(response).to have_http_status(:unauthorized)
            expect(json_response[:error]).to eq("invalid_token")
            expect(json_response[:error_description]).to eq("Malformed authorization header")
          end
        end

        context "successful retrieve all existing #{underscore_model_name}" do
          it "with authorized token request" do
            get "/api/v3/#{namespace}/#{underscore_model_name}", headers: header_token_authorization
            expect(response).to have_http_status(:ok)
            expect(json_response[:count]).to be
            expect(json_response[:current_page]).to be
            expect(json_response[:data_type]).to be
            expect(json_response[:items]).to be
            expect(json_response[:total_pages]).to be
          end
        end
      end
    end
  end
end