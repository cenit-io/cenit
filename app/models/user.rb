class User
  include Mongoid::Document
  include Mongoid::Timestamps
  extend DeviseOverrides
  include NumberGenerator
  rolify

  belongs_to :account, inverse_of: :users, class_name: Account.to_s
  scope :by_account, -> { where(account: Account.current) }

  # Include default devise modules. Others available are:
  # :recoverable, :rememberable, :confirmable, :lockable, :timeoutable and :omniauthable

  devise :trackable, :validatable, :omniauthable, :database_authenticatable
  devise :registerable unless ENV['UNABLE_REGISTERABLE'].to_b
  devise :confirmable unless ENV['UNABLE_CONFIRMABLE'].to_b

  # Database authenticatable
  field :email, type: String, default: ''
  field :encrypted_password, type: String, default: ''

  ## Recoverable
  field :reset_password_token, type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count, type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at, type: Time
  field :confirmed_at, type: Time
  field :confirmation_sent_at, type: Time
  field :confirmation_token, type: String
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip, type: String
  field :authentication_token, as: :token, type: String
  field :number, as: :key, type: String
  field :unique_key, type: String
  field :unconfirmed_email, type: String

  field :doorkeeper_uid, type: String
  field :doorkeeper_access_token, type: String

  field :name, type: String

  before_save :ensure_token
  before_create { self.account ||= Account.current }
  after_create { self.account ||= Account.current || Account.create_with_owner(owner: self) }
  
  validates_uniqueness_of :token
  before_save :ensure_token, :inspect_updated_fields

  def label
    if name.present?
      "#{name} (#{email})"
    else
      email
    end
  end

  def inspect_updated_fields
    changed_attributes.keys.each do |attr|
      reset_attribute!(attr) unless %w(name).include?(attr)
    end unless new_record? || (user = User.current).nil? || user.super_admin?
    true
  end

  def self.find_or_initialize_for_doorkeeper_oauth(oauth_data)
    user = User.where(email: oauth_data.info.email).first
    user ||= User.new(email: oauth_data.info.email, password: Devise.friendly_token[0, 20])
    user.confirmed_at ||= Time.now
    user.doorkeeper_uid = oauth_data.uid
    user
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session['devise.doorkeeper_data'] && session['devise.doorkeeper_data']['extra']['raw_info']
        user.email = data['email'] if user.email.blank?
      end
    end
  end

  def update_doorkeeper_credentials(oauth_data)
    self.doorkeeper_access_token = oauth_data.credentials.token
  end

  def ensure_token
    self.token ||= generate_token
    md5 = Digest::MD5.new
    md5 << key
    md5 << token
    self.unique_key = md5.hexdigest
  end

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(token: token).first
    end
  end

  def admin?
    has_role?(:admin) || has_role?(:super_admin)
  end

  def super_admin?
    has_role?(:super_admin)
  end

end
