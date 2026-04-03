require 'cbloomfilter'
require 'bloom_fit/version'

class BloomFit
  BloomFit::ConfigurationMismatch = Class.new(ArgumentError)

  attr_reader :bf

  def initialize(opts = {})
    @opts = {
      :size    => 100,
      :hashes  => 4,
      :bucket  => 1,
      :raise   => false
    }.merge(opts)

    # arg 1: m => size : number of buckets in a bloom filter
    # arg 2: k => hashes : number of hash functions
    # arg 3: b => bucket : number of bits per bucket
    # arg 4: r => raise : whether to raise on bucket overflow

    @bf = CBloomFilter.new(@opts[:size], @opts[:hashes], @opts[:bucket], @opts[:raise])
  end

  def insert(key)
    @bf.insert(key)
  end
  alias :[]= :insert

  def include?(*keys)
    @bf.include?(*keys)
  end
  alias :key? :include?
  alias :[] :include?

  def delete(key); @bf.delete(key); end
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
    opts, bitmap = *ary

    initialize(opts)
    @bf.load(bitmap) if !bitmap.nil?
  end

  def marshal_dump
    [@opts, @bf.bitmap]
  end

  def self.load(filename)
    Marshal.load(File.open(filename, 'r'))
  end

  def save(filename)
    File.open(filename, 'w') do |f|
      f << Marshal.dump(self)
    end
  end

  def stats
    fp = ((1.0 - Math.exp(-(@opts[:hashes] * size).to_f / @opts[:size])) ** @opts[:hashes]) * 100
    printf "Number of filter buckets (m): %d\n", @opts[:size]
    printf "Number of bits per buckets (b): %d\n", @opts[:bucket]
    printf "Number of set bits (n): %d\n", set_bits
    printf "Number of filter hashes (k) : %d\n", @opts[:hashes]
    printf "Predicted false positive rate = %.2f%%\n", fp
  end

  protected

  # Returns true if parameters of the +o+ther filter are
  # the same.
  def same_parameters?(o)
    @bf.m == o.bf.m && @bf.k == o.bf.k && @bf.b == o.bf.b
  end
end
