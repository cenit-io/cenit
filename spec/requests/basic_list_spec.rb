require 'spec_helper'

describe 'Basic List', type: :request do
  subject { page }

  describe 'GET /' do
    it 'responds successfully' do
      visit dashboard_path
    end
  end

  context 'the user is log in' do
    describe 'GET /typo' do
      it "redirects to dashboard and inform the user the model wasn't found" do
        user = FactoryGirl.create(:user)
        login_as(user, scope: :user)
        visit '/whatever'
        expect(find('.alert-danger')).to have_content("Model 'Whatever' could not be found")
      end
    end

    describe 'GET /user list' do
      it "success visit for user list page" do
        user = FactoryGirl.create(:user)
        login_as(user, scope: :user)
        visit '/user'
        is_expected.to have_content("Add new")
        is_expected.to have_content("Name")
        is_expected.to have_content("Email")
        is_expected.to have_content("Given name")
        is_expected.to have_content("Family name")
        is_expected.to have_content("Current Account")
        is_expected.to have_content("Users")
        is_expected.to have_content("Created at")
        is_expected.to have_selector("input[placeholder='Filter']")
      end
    end
  end
end
