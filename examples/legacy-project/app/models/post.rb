class Post < ActiveRecord::Base
  belongs_to :user
  has_many :tags

  # Law of Demeter violations (rails_best_practices flags these)
  def author_city
    user.address.city
  end

  def author_zip
    user.address.zip
  end

  # Feature envy + duplicated string building (reek / flay)
  def summary
    "#{title} by #{user.name} (#{user.address.city})"
  end

  def long_summary
    "#{title} by #{user.name} (#{user.address.city}) - #{body.to_s[0, 200]}"
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
