class Account
  include Mongoid::Document
  include NumberGenerator

  belongs_to :owner, class_name: User.to_s, inverse_of: nil
  has_many :users, class_name: User.to_s, inverse_of: :account

  field :name, type: String

  belongs_to :tenant_account, class_name: Account.to_s, inverse_of: nil

  def label
    owner.present? ? owner.label : Account.to_s + '#' + id.to_s
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

    def create_with_owner(params={})
      account = new(params)
      if account.save
        account.owner.roles << ::Role.where(name: :admin).first
        account.users << account.owner
      end
      account
    end

    def set_current_with_connection(key, token)
      all.each do |account|
        self.current = account
        if (connection = Setup::Connection.where(key: key).first).present? && Devise.secure_compare(connection.token, token)
          return connection
        end
      end
      self.current = nil
    end

    def tenant_collection_prefix(sep = '')
      if current.present?
        acc_id =
          if current.owner.super_admin? && current.tenant_account.present?
            current.tenant_account.id
          else
            current.id
          end
        "acc#{acc_id}#{sep}"
      else
        ''
      end
    end

    def tenant_collection_name(model_name, sep='_')
      tenant_collection_prefix(sep) + model_name.collectionize
    end

    def data_type_collection_name(data_type)
      tenant_collection_name(data_type.data_type_name)
    end
  end

end
