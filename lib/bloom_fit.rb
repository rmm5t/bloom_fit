require "cbloomfilter"
require "bloom_fit/version"

class BloomFit
  class ConfigurationMismatch < ArgumentError
  end

  attr_reader :bf

  def initialize(size: 1_000, hashes: 4)
    @size = size
    @hashes = hashes

    # arg 1: m => size : number of buckets in a bloom filter
    # arg 2: k => hashes : number of hash functions
    # arg 3: b => bucket : number of bits per bucket
    # arg 4: r => raise : whether to raise on bucket overflow
    @bf = CBloomFilter.new(@size, @hashes)
  end

  def insert(key)
    @bf.insert(key)
  end
  alias []= insert

  def include?(*keys)
    @bf.include?(*keys)
  end
  alias key? include?
  alias [] include?

  def clear; @bf.clear; end
  def size; @bf.set_bits; end
  def merge!(o); @bf.merge!(o.bf); end

  # Returns the number of bits that are set to 1 in the filter.
  def set_bits
    @bf.set_bits
  end

  # Computes the intersection of two Bloom filters.
  # It assumes that both filters have the same size -
  # if this is not true +BloomFit::ConfigurationMismatch+ is raised.
  def &(o)
    raise BloomFit::ConfigurationMismatch.new unless same_parameters?(o)
    result = self.class.new
    result.instance_variable_set(:@bf,@bf.&(o.bf))
    result
  end

  # Computes the union of two Bloom filters.
  # It assumes that both filters have the same size -
  # if this is not true +BloomFit::ConfigurationMismatch+ is raised.
  def |(o)
    raise BloomFit::ConfigurationMismatch.new unless same_parameters?(o)
    result = self.class.new
    result.instance_variable_set(:@bf,@bf.|(o.bf))
    result
  end

  def bitmap
    @bf.bitmap
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
    Marshal.load(File.open(filename, "r"))
  end

  def save(filename)
    File.open(filename, "w") do |f|
      f << Marshal.dump(self)
    end
  end

  def stats
    fp = ((1.0 - Math.exp(-(@hashes * size).to_f / @size))**@hashes) * 100
    printf "Number of filter buckets (m): %d\n", @size
    printf "Number of set bits (n): %d\n", set_bits
    printf "Number of filter hashes (k) : %d\n", @hashes
    printf "Predicted false positive rate = %.2f%%\n", fp
  end

  protected

  # Returns true if parameters of the +other+ filter are
  # the same.
  def same_parameters?(other)
    bf.m == other.bf.m && bf.k == other.bf.k
  end
end
