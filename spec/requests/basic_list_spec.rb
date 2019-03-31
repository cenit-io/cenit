require 'spec_helper'

describe 'Basic List', type: :feature do
  subject { page }

  context 'when a visitor that is not log in' do
    describe 'GET /' do
      it 'responds successfully' do
        visit dashboard_path
      end
    end

    describe 'GET /whatever' do
      it "redirects to dashboard and inform should be login first" do
        visit '/whatever'
        expect(find('.alert-danger')).to have_content('You need to sign in or sign up before continuing.')
      end
    end

    describe 'GET /user' do
      it "before visit user page should be login first" do
        visit '/user'
        is_expected.to have_content('Log in')
        is_expected.to have_content('Sign up')
      end
    end
  end

  context 'when a user is log in' do
    before(:each) do
      user = FactoryGirl.create(:user)
      login_as(user, scope: :user)
    end

    describe 'GET /typo' do
      it "redirects to dashboard and inform the user the model wasn't found" do

        visit '/whatever'
        expect(find('.alert-danger')).to have_content("Model 'Whatever' could not be found")
      end
    end

    describe 'GET /user list' do
      it "success visit for user list page" do
        visit '/user'

        # Actions
        is_expected.to have_content('Add new')

        # Filter
        is_expected.to have_selector("input[placeholder='Filter']")

        # Columns
        is_expected.to have_content('Name')
        is_expected.to have_content('Email')
        is_expected.to have_content('Given name')
        is_expected.to have_content('Family name')
        is_expected.to have_content('Current Account')
        is_expected.to have_content('Users')
        is_expected.to have_content('Created at')
      end
    end
  end
end
