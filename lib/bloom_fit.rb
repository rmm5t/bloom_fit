require "forwardable"

require "cbloomfilter"
require "bloom_fit/version"

# BloomFit is an in-memory Bloom filter with a small, Set-like API.
#
# Bloom filters are probabilistic membership structures: they can report false
# positives, but they do not report false negatives for values that have been
# added. That makes BloomFit useful for cheaply ruling out missing values
# before doing more expensive work, while keeping memory usage low.
#
# The class wraps the native +CBloomFilter+ implementation in Ruby-friendly
# methods such as +add+, +include?+, +merge+, +&+, and +|+. Instances can be
# serialized with +save+ and reloaded with +BloomFit.load+.
#
# Filters can only be combined when they were created with the same +size+ and
# +hashes+ values; otherwise the native extension raises +ArgumentError+.
#
#   filter = BloomFit.new(size: 10_000, hashes: 6)
#   filter.add("cat")
#   filter.include?("cat") # => true
#   filter.include?("dog") # => false
#
# Choose +size+ and +hashes+ based on the expected number of inserts and the
# false-positive rate you can tolerate.
class BloomFit
  extend Forwardable

  LN2 = Math.log(2.0).freeze

  # The wrapped native +CBloomFilter+ instance.
  #
  # This is mostly useful for low-level integrations and internal filter
  # operations such as merge, union, and intersection.
  attr_reader :bf

  # Creates an empty Bloom filter.
  #
  # The defaults are a reasonable starting point for small in-memory filters,
  # but the best values depend on how many keys you expect to insert and how
  # many false positives you can tolerate.
  #
  # @param capacity [Integer] expected number of elements to store in the set
  # @param false_positive_rate [Integer] expected number of elements to store in the set
  # @param size [Integer] number of buckets in a bloom filter
  # @param hashes [Integer] number of hash functions
  def initialize(capacity: 100, false_positive_rate: 0.001, size: nil, hashes: 4)
    if size.nil? || hashes.nil?
      raise ArgumentError, "capacity must be > 0" unless capacity.positive?
      raise ArgumentError, "false_positive_rate must be between 0 and 1" if false_positive_rate <= 0.0 || false_positive_rate >= 1.0

      size = (-capacity.to_f * Math.log(false_positive_rate) / (LN2**2)).ceil
      hashes = (size / capacity * LN2).ceil
    end

    @bf = CBloomFilter.new(size, hashes)
  end

  # :method: m
  #
  # Returns the configured filter width.

  # :method: k
  #
  # Returns the number of hash functions applied to each key.

  # :method: bitmap
  #
  # Returns the raw bitmap as a binary string.
  #
  # The returned bytes reflect the native representation, so the string may
  # include padding beyond the configured filter size.

  # :method: include?
  #
  # Returns +true+ when +key+ may be present and +false+ when it is definitely
  # absent.
  #
  # Positive results are probabilistic and may be false positives.

  # :method: clear
  #
  # Clears the filter by resetting all bits to +0+.

  # :method: set_bits
  #
  # Returns the number of bits currently set to +1+.

  def_delegators :@bf, :m, :k, :bitmap, :include?, :clear, :set_bits

  # Returns the configured filter width.
  alias size m
  # Returns the number of hash functions used for each inserted key.
  alias hashes k
  alias key? include?
  alias [] include?
  alias n set_bits

  # Returns +true+ when no bits are set.
  #
  # This is an exact check on the filter state, unlike +include?+, which is
  # probabilistic for positive matches.
  def empty?
    set_bits.zero?
  end

  # Adds +key+ to the filter and returns +self+.
  #
  # This mimics the behavior of Set#add and allows chaining with #<<.
  def add(key)
    @bf.add(key)
    self
  end
  alias << add

  # Adds +key+ to the filter when +value+ is truthy.
  #
  # This makes BloomFit behave like a write-only membership hash: truthy values
  # add the key, while +false+ and +nil+ are ignored.
  def []=(key, value)
    @bf.add(key) if value
  end

  # Adds +key+ only if it does not already appear to be present.
  #
  # Returns +self+ when the key is added and +nil+ when +include?+ is already
  # true. This mimics Set#add?.
  #
  # Because Bloom filters can return false positives, +add?+ may occasionally
  # return +nil+ for a key that has not actually been inserted before.
  def add?(key)
    return nil if include?(key) # rubocop:disable Style/ReturnNilInPredicateMethodDefinition
    add(key)
  end

  # Returns the bitmap as a hexadecimal string.
  #
  # This is useful for debugging, logging, or comparing filter state in a more
  # compact form than +to_binary+.
  def to_hex
    length = ((size / 8.0).ceil * 8 / 4)
    bitmap.unpack1("H*")[0...length]
  end

  # Returns the bitmap as a binary string of +0+ and +1+ characters.
  #
  # The output is truncated to the configured filter width, so it omits any
  # trailing padding present in the native bitmap.
  def to_binary
    bitmap.unpack1("B*")[0...size]
  end

  # Merges another filter or collection of keys into this filter.
  #
  # When +other+ is a +BloomFit+, the merge is performed bitwise and both
  # filters must have the same +size+ and +hashes+ values. When +other+
  # behaves like a hash, only keys with truthy values are added. Any other
  # enumerable is treated as a list of keys.
  #
  # This method mutates the receiver and mimics Set#merge.
  def merge(other)
    if other.is_a?(BloomFit)
      @bf.merge(other.bf)
    elsif other.respond_to?(:each_key)
      other.each { |k, v| add(k) if v }
    elsif other.is_a?(Enumerable)
      other.each { |k| add(k) }
    else
      raise ArgumentError, "value must be enumerable or another BloomFit filter"
    end
  end

  # Returns a new filter containing the bitwise intersection of two filters.
  #
  # Both filters must have the same +size+ and +hashes+ values or the native
  # extension raises +ArgumentError+.
  #
  # Like all Bloom filter operations, membership checks on the result remain
  # probabilistic and may still produce false positives.
  def &(other)
    self.class.new(size:, hashes:).tap do |result|
      result.instance_variable_set(:@bf, @bf.&(other.bf))
    end
  end
  alias intersection &

  # Returns a new filter containing the bitwise union of two filters.
  #
  # Both filters must have the same +size+ and +hashes+ values or the native
  # extension raises +ArgumentError+.
  #
  # The receiver and +other+ are left unchanged.
  def |(other)
    self.class.new(size:, hashes:).tap do |result|
      result.instance_variable_set(:@bf, @bf.|(other.bf))
    end
  end
  alias union |

  # Returns a human-readable summary of the filter's current state.
  #
  # The report includes the configured width (+m+), the current number of set
  # bits (+n+), the hash count (+k+), and the predicted false-positive rate
  # based on the current fill level.
  def stats
    fpr = ((1.0 - Math.exp(-(k * n).to_f / m))**k) * 100

    format <<~STATS, m, n, k, fpr
      Number of filter buckets (m):  %d
      Number of set bits (n):        %d
      Number of filter hashes (k):   %d
      Predicted false positive rate: %.2f%%
    STATS
  end

  # Rebuilds the filter from the serialized data returned by +marshal_dump+.
  #
  # This hook is used by Ruby's +Marshal+ support.
  def marshal_load(ary)
    size, hashes, bitmap = *ary

    initialize(size:, hashes:)
    @bf.load(bitmap) if bitmap
  end

  # Returns the data Ruby's +Marshal+ uses to serialize this filter.
  def marshal_dump
    [size, hashes, bitmap]
  end

  # Loads a filter from a file previously written by +save+.
  #
  # The file is read using Ruby's +Marshal+ format, so it should only be used
  # with trusted input.
  def self.load(filename)
    Marshal.load(File.open(filename, "r")) # rubocop:disable Security/MarshalLoad
  end

  # Writes the filter to +filename+ using Ruby's +Marshal+ format.
  def save(filename)
    File.open(filename, "w") do |f|
      f << Marshal.dump(self)
    end
  end
end
