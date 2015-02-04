# coding: utf-8
require 'spec_helper'

describe 'RailsAdmin Basic List', type: :request do
  subject { page }

  describe 'GET /data' do
    it 'responds successfully' do
      visit '/hub/users/sign_up/'
      fill_in 'user_email', with: "test@example.com"
      fill_in 'user_password', with: '12345678'
      fill_in 'user_password_confirmation', with: '12345678'
      click_button 'Sign up'
      FactoryGirl.create(:connection_store_i)
      byebug
      sleep 2 
      #visit rails_admin.dashboard_path
    end
  end
end  