require 'factory_girl'

FactoryGirl.define  do |d|

  factory :image, class: Hub::Image do
	  position 1
	  url "http://dummyimage.com/600x400/000/fff.jpg&text=Spree T-Shirt"
	  title "Spree T-Shirt - Grey Small"
    type "thumbnail"
  end
  
end


