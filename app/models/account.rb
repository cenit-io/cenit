class Account
  include Mongoid::Document
  include NumberGenerator

  belongs_to :owner, class_name: User.name
  has_many :users, inverse_of: :account, class_name: User.name

  field :name, type: String

  accepts_nested_attributes_for :owner
  accepts_nested_attributes_for :users

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

  def generate_number(options = {})
    options[:prefix] ||= 'A'
    super(options)
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
