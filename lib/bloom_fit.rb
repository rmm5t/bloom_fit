require "forwardable"

require "cbloomfilter"
require "bloom_fit/configuration_mismatch"
require "bloom_fit/version"

class BloomFit
  extend Forwardable

  attr_reader :bf

  def initialize(size: 1_000, hashes: 4)
    @size = size
    @hashes = hashes

    # arg 1: m => size : number of buckets in a bloom filter
    # arg 2: k => hashes : number of hash functions
    @bf = CBloomFilter.new(@size, @hashes)
  end

  def_delegators :@bf, :add, :include?, :clear, :set_bits, :bitmap

  alias << add
  alias []= add

  alias key? include?
  alias [] include?

  # Returns the number of bits that are set to 1 in the filter.
  def size = @bf.set_bits

  def merge!(other) = @bf.merge!(other.bf)

  # Computes the intersection of two Bloom filters.
  # It assumes that both filters have the same size -
  # if this is not true +BloomFit::ConfigurationMismatch+ is raised.
  def &(other)
    raise BloomFit::ConfigurationMismatch unless same_parameters?(other)
    result = self.class.new
    result.instance_variable_set(:@bf, @bf.&(other.bf))
    result
  end

  # Computes the union of two Bloom filters.
  # It assumes that both filters have the same size -
  # if this is not true +BloomFit::ConfigurationMismatch+ is raised.
  def |(other)
    raise BloomFit::ConfigurationMismatch unless same_parameters?(other)
    result = self.class.new
    result.instance_variable_set(:@bf, @bf.|(other.bf))
    result
  end

  def marshal_load(ary)
    size, hashes, bitmap = *ary

    initialize(size:, hashes:)
    @bf.load(bitmap) if bitmap
  end

  def marshal_dump
    [@size, @hashes, @bf.bitmap]
  end

  def self.load(filename)
    Marshal.load(File.open(filename, "r")) # rubocop:disable Security/MarshalLoad
  end

  def save(filename)
    File.open(filename, "w") do |f|
      f << Marshal.dump(self)
    end
  end

  def stats
    fpr = ((1.0 - Math.exp(-(@hashes * size).to_f / @size))**@hashes) * 100

    (+"").tap do |s|
      s << format("Number of filter buckets (m):  %d\n",     @size)
      s << format("Number of set bits (n):        %d\n",     set_bits)
      s << format("Number of filter hashes (k):   %d\n",     @hashes)
      s << format("Predicted false positive rate: %.2f%%\n", fpr)
    end
  end

  protected

  # Returns true if parameters of the +other+ filter are
  # the same.
  def same_parameters?(other)
    bf.m == other.bf.m && bf.k == other.bf.k
  end
end
