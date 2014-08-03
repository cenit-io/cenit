module Dashboard
  class BaseController < ApplicationController
    private
      def days
        %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
      end
      def hours
        %w(12am 1am 2am 3am 4am 5am 6am 7am 8am 9am 10am 11am 12m 1pm 2pm 3pm 4pm 5pm 6pm 7pm 8pm 9pm 10pm 11pm)
      end
  end
end