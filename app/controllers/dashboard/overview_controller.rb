module Dashboard
  class OverviewController < ApplicationController
    def index
      @users = User.all
    end
  end
end