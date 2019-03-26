require 'rails_helper'

RSpec.feature "Log in flow", type: :feature do
  scenario "Not login with invalid password" do
    visit "/users/sign_in"

    expect(page).to have_text("Cenit IO Continue with GitHub Google Facebook or Email Password")

    fill_in "Email", with: "test@cenit.io"
    fill_in "Password", with: "wrognsecret"

    click_button "Log in"

    expect(page).to have_text("Invalid email or password.")
  end
end
