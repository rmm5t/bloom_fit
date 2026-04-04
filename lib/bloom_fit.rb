require "forwardable"

require "cbloomfilter"
require "bloom_fit/configuration_mismatch"
require "bloom_fit/version"

class BloomFit
  extend Forwardable

  attr_reader :bf

  # @param size [Integer] number of buckets in a bloom filter
  # @param hashes [Integer] number of hash functions
  def initialize(size: 1_000, hashes: 4)
    @bf = CBloomFilter.new(size, hashes)
  end

  def_delegators :@bf, :m, :k, :bitmap, :include?, :clear, :set_bits

  alias size m
  alias hashes k
  alias key? include?
  alias [] include?
  alias n set_bits

  def empty?
    set_bits.zero?
  end

  # Adds the given key to the set and returns +self+.  Mimics the behavior of
  # +Set#add+
  def add(key)
    @bf.add(key)
    self
  end
  alias << add

  # Adds the given key to the set if the value is truthy.  Mimics the behavior of
  # +Hash#[]=+
  def []=(key, value)
    @bf.add(key) if value
  end

  # Adds the given key to the set and returns +self+. If the key is already
  # the in set, returns +nil+. Mimics the behavior of +Set#add?+
  def add?(key)
    return nil if include?(key) # rubocop:disable Style/ReturnNilInPredicateMethodDefinition
    add(key)
  end

  # Returns a string of the set bits in hex format
  def to_hex
    length = ((size / 8.0).ceil * 8 / 4)
    bitmap.unpack1("H*")[0...length]
  end

  # Returns a string of the set bits in binary format
  def to_binary
    bitmap.unpack1("B*")[0...size]
  end

  # Adds the set from another BloomFit filter or adds all the elements from an
  # enumerable.  Mimics the behavior of +Set#merge+
  def merge(other)
    if other.is_a?(BloomFit)
      raise BloomFit::ConfigurationMismatch unless same_parameters?(other)
      @bf.merge(other.bf)
    elsif other.respond_to?(:each_key)
      other.each { |k, v| add(k) if v }
    elsif other.is_a?(Enumerable)
      other.each { |k| add(k) }
    else
      raise ArgumentError, "value must be enumerable or another BloomFit filter"
    end
  end

  # Computes the intersection of two Bloom filters. It requires that both
  # filters have the same size; otherwise, +BloomFit::ConfigurationMismatch+
  # is raised.
  def &(other)
    raise BloomFit::ConfigurationMismatch unless same_parameters?(other)
    self.class.new(size:, hashes:).tap do |result|
      result.instance_variable_set(:@bf, @bf.&(other.bf))
    end
  end
  alias intersection &

  # Computes the union of two Bloom filters. It requires that both filters
  # have the same size; otherwise, +BloomFit::ConfigurationMismatch+ is
  # raised.
  def |(other)
    raise BloomFit::ConfigurationMismatch unless same_parameters?(other)
    self.class.new(size:, hashes:).tap do |result|
      result.instance_variable_set(:@bf, @bf.|(other.bf))
    end
  end
  alias union |

  def stats
    fpr = ((1.0 - Math.exp(-(k * n).to_f / m))**k) * 100

    (+"").tap do |s|
      s << format("Number of filter buckets (m):  %d\n",     m)
      s << format("Number of set bits (n):        %d\n",     n)
      s << format("Number of filter hashes (k):   %d\n",     k)
      s << format("Predicted false positive rate: %.2f%%\n", fpr)
    end
  end

  def marshal_load(ary)
    size, hashes, bitmap = *ary

    initialize(size:, hashes:)
    @bf.load(bitmap) if bitmap
  end

  def marshal_dump
    [size, hashes, bitmap]
  end

  def self.load(filename)
    Marshal.load(File.open(filename, "r")) # rubocop:disable Security/MarshalLoad
  end

  def save(filename)
    File.open(filename, "w") do |f|
      f << Marshal.dump(self)
    end
  end

  protected

  # Returns true if parameters of the +other+ filter are
  # the same.
  def same_parameters?(other)
    bf.m == other.bf.m && bf.k == other.bf.k
  end
end
