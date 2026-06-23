# Intentionally slow Ruby idioms — used to demonstrate fasterer (Performance).
# Each method here triggers a fasterer rule. Do NOT copy.
class Report
  def first_match(items)
    # fasterer: Enumerable#detect is faster than select.first
    items.select { |i| i > 10 }.first
  end

  def has_total?(hash)
    # fasterer: Hash#key? is faster than keys.include?
    hash.keys.include?(:total)
  end

  def reverse_loop(items)
    # fasterer: reverse_each is faster than reverse.each
    items.reverse.each { |i| puts i }
  end

  def count_big(items)
    # fasterer: Array#size is faster than count on an array
    items.select { |i| i > 0 }.count
  end

  def flatten_all(items)
    # fasterer: flat_map is faster than map{}.flatten
    items.map { |i| [i, i] }.flatten
  end
end
