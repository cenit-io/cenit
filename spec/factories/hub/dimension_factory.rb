require 'factory_girl'

FactoryGirl.define  do |d|

  factory :dimension, class: Hub::Dimension do
	  height 250
	  width 250
  end

end


