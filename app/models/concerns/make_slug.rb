module MakeSlug
  extend ActiveSupport::Concern

  included do
    field :slug, type: String
    validates :slug, uniqueness: { scope: :account_id }
    validates_presence_of :slug 
    before_validation :make_slug, on: :create
  end
  
  def self.by_slug(slug)
    where(number: slug)
  end

  def make_slug
    self.slug = self.name.parameterize
  end
end
