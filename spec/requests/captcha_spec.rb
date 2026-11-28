require 'rails_helper'

RSpec.describe 'CAPTCHA image', type: :request do
  it 'serves a decodable JPEG for a newly issued token' do
    get '/captcha'
    expect(response).to have_http_status(:ok)
    token = JSON.parse(response.body).fetch('token')

    get "/captcha/#{token}"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('image/jpeg')
    image = Magick::Image.from_blob(response.body).first
    expect(image.format).to eq('JPEG')
    expect(image.columns).to be_positive
    expect(image.rows).to be_positive
    expect(image.number_colors).to be > 1
  end
end
