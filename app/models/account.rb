class Account
  include Mongoid::Document
  include NumberGenerator

  def generate_number(options = {})
    options[:prefix] ||= 'A'
    super(options) 
  end 
    
  belongs_to :owner, :class_name => "User"
  accepts_nested_attributes_for :owner

  has_many :users, inverse_of: :account
  accepts_nested_attributes_for :users
  
  field :name, type: String

  def self.create_with_owner(params={})
    account = new(params)
    if account.save
      account.users << account.owner
    end
    account
  end

  def owner?(user)
    owner == user
  end
  
  class << self
    def current
      Thread.current[:current_account]
    end
  
    def current=(account)
      Thread.current[:current_account] = account
    end
  end
  
end