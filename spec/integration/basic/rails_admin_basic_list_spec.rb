# coding: utf-8
require 'spec_helper'

describe 'RailsAdmin Basic List', type: :feature, inaccessible: true do
  subject { page }

  context "Sing up" do 
    it 'responds successfully' do
      visit '/hub/users/sign_up/'
      fill_in 'user_email', with: "test@example.com"
      fill_in 'user_password', with: '12345678'
      fill_in 'user_password_confirmation', with: '12345678'
      click_button 'Sign up'
      #visit rails_admin.dashboard_path
    end
  end
  
end  