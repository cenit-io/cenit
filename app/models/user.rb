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
  # :recoverable, :rememberable, :confirmable, :lockable, :timeoutable and :omniauthable
  if ENV['UNABLE_REGISTERABLE'].to_b
    devise :trackable, :validatable, :omniauthable, :database_authenticatable
  else
    devise :registerable, :trackable, :validatable, :omniauthable, :database_authenticatable
  end

  # Database authenticatable
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
  field :authentication_token, as: :token, type: String
  field :number, as: :key, type: String
  
  field :doorkeeper_uid, type: String 
  field :doorkeeper_access_token, type: String

  before_save :ensure_token
  validates_uniqueness_of :token

  def self.find_or_initialize_for_doorkeeper_oauth(oauth_data)
    user = User.where(email: oauth_data.info.email).first
    user ||= User.new(email: oauth_data.info.email,password: Devise.friendly_token[0,20])
    user.doorkeeper_uid = oauth_data.uid
    user
  end
  
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.doorkeeper_data"] && session["devise.doorkeeper_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
      end
    end
  end

  def update_doorkeeper_credentials(oauth_data)
    self.doorkeeper_access_token = oauth_data.credentials.token
  end

  def ensure_token
    self.token ||= generate_token
  end
  
  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(token: token).first
    end
  end

  rails_admin do
    weight -15
    navigation_label 'Account'

    object_label_method do
      :email
    end

    configure :key do
      visible do
        bindings[:view]._current_user.has_role? :admin
      end
    end

    configure :authentication_token do
      visible do
        bindings[:view]._current_user.has_role? :admin
      end
    end

    list do
      scopes [:by_account]
    end

    show do
      field :email
      field :roles
      field :key
      field :authentication_token
      field :sign_in_count
      field :current_sign_in_at
      field :last_sign_in_at
      field :current_sign_in_ip
      field :last_sign_in_ip
      field :reset_password_sent_at

      field :_id
      field :created_at
      field :updated_at
    end
    fields :email, :roles, :key, :authentication_token, :sign_in_count, :last_sign_in_at, :last_sign_in_ip
  end

end
