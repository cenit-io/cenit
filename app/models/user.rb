class User
  include Mongoid::Document
  include Mongoid::Timestamps
  extend DeviseOverrides
  include NumberGenerator
  rolify
  
  belongs_to :account, inverse_of: :users, class_name: Account.name
  before_validation { self.account ||= Account.current }
  scope :by_account, -> { where(account: Account.current ) }
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String
  field :authentication_token, type: String
  field :number, as: :key, type: String

  before_save :ensure_authentication_token
  validates_uniqueness_of :authentication_token
  
  def ensure_authentication_token
    self.authentication_token ||= generate_authentication_token
  end
  
  rails_admin do
    list do 
      scopes [:by_account]
    end        
    list do
      field :email
      field :roles
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :authentication_token do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :sign_in_count
      field :last_sign_in_at
      field :last_sign_in_ip
    end
    show do
      field :_id
      field :created_at
      field :updated_at
      field :email
      field :roles
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :authentication_token do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :sign_in_count
      field :current_sign_in_at
      field :last_sign_in_at
      field :current_sign_in_ip
      field :last_sign_in_ip
      field :reset_password_sent_at
    end
    edit do
      field :email 
      field :password
      field :password_confirmation
      field :roles
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :authentication_token do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      #field :reset_password_token
    end
    navigation_label 'Account'
  end  

  # accepts_nested_attributes_for :account
  
  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end
  
end
