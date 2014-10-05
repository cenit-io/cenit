class VisitorsController < ApplicationController
  skip_filter :authenticate_user!
end
