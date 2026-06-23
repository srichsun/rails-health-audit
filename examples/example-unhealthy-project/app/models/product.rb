# Intentionally smelly model — used to demonstrate rails-health-audit.
class Product < ApplicationRecord
  belongs_to :owner, optional: true
  has_many :tags

  # Model validations with no matching DB constraint — active_record_doctor flags these:
  #   name validated for presence, but the column is nullable (missing_non_null_constraint)
  #   sku validated for uniqueness, but there is no unique index (missing_unique_indexes)
  validates :name, presence: true
  validates :sku, uniqueness: true

  # Law of Demeter violations (rails_best_practices flags these)
  def owner_city
    owner.address.city
  end

  def owner_zip
    owner.address.zip
  end

  # Feature envy + duplicated string building (reek / flay)
  def summary
    "#{name} by #{owner.name} (#{owner.address.city})"
  end

  def long_summary
    "#{name} by #{owner.name} (#{owner.address.city}) - #{description.to_s[0, 200]}"
  end

  # Needlessly complex; uncommunicative names (reek, flog)
  def s(x)
    r = 0
    x.each do |i|
      if i > 0
        r += i
      else
        r -= i
      end
    end
    r
  end
end
