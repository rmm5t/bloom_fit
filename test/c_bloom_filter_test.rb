require "test_helper"

class CBloomFilterTest < Minitest::Spec
  subject { CBloomFilter.new }

  describe ".new" do
    it "rejects more than two arguments" do
      error = assert_raises(ArgumentError) { CBloomFilter.new(1, 2, 3) }
      assert_equal "wrong number of arguments (given 3, expected 0..2)", error.message
    end
  end

  describe "#m" do
    it "defaults" do
      assert_equal 1000, subject.m
    end

    it "is set by the 1st arg of the contructor" do
      bf = CBloomFilter.new(10_000)
      assert_equal 10_000, bf.m
    end

    it "rejects values less than 1" do
      error = assert_raises(ArgumentError) { CBloomFilter.new(-1) }
      assert_equal "bit length must be >= 1", error.message
    end

    it "rejects values that overflow internal byte sizing" do
      error = assert_raises(RangeError) { CBloomFilter.new((1 << 31) - 7) }
      assert_equal "bit length is too large", error.message
    end
  end

  describe "#k" do
    it "defaults" do
      assert_equal 4, subject.k
    end

    it "is set by the 2nd arg of the contructor" do
      bf = CBloomFilter.new(10_000, 9)
      assert_equal 9, bf.k
    end

    it "rejects values less than 1" do
      error = assert_raises(ArgumentError) { CBloomFilter.new(1000, 0) }
      assert_equal "hash length must be >= 1", error.message
    end

    it "rejects values larger than the salt table" do
      error = assert_raises(ArgumentError) { CBloomFilter.new(10_000, 257) }
      assert_equal "hash length must be <= 256", error.message
    end
  end

  describe "#set_bits" do
    it "initializes to zero" do
      assert_equal 0, subject.set_bits
    end

    it "counts the bits when active" do
      subject.add("foo")
      assert_equal 4, subject.set_bits
    end
  end

  describe "#add" do
    it "adds keys to the filter set" do
      subject.add("foo")
      subject.add("bar")
      assert_includes subject, "foo"
      assert_includes subject, "bar"
      refute_includes subject, "baz"
    end

    it "treats binary bytes as unsigned when hashing" do
      bf = CBloomFilter.new(20, 4)
      bf.add("\xFF".b)
      assert_equal "\x00\x05\x05\x00".b, bf.bitmap
    end
  end

  describe "#include?" do
    it "returns true when a key is in the set" do
      subject.add("foo")
      assert_equal true, subject.include?("foo") # rubocop:disable Minitest/AssertTruthy
    end

    it "returns false when a key is not in the set" do
      subject.add("foo")
      assert_equal false, subject.include?("bar") # rubocop:disable Minitest/RefuteFalse
    end
  end

  describe "#clear" do
    it "clears a set" do
      subject.add("foo")
      subject.add("bar")
      subject.add("baz")
      assert subject.set_bits.positive?
      subject.clear
      assert subject.set_bits.zero?
    end
  end

  describe "#merge" do
    it "adds keys from another set" do
      subject.add("foo")

      bf = CBloomFilter.new
      bf.add("bar")
      bf.add("baz")

      subject.merge(bf)
      assert_includes subject, "foo"
      assert_includes subject, "bar"
      assert_includes subject, "baz"
    end

    it "rejects incompatible filters" do
      error = assert_raises(ArgumentError) { subject.merge(CBloomFilter.new(2000, 4)) }
      assert_equal "bloom filters must have matching size and hash count", error.message
    end
  end

  describe "#&" do
    it "intersects keys from another set" do
      subject.add("foo")
      subject.add("bar")

      bf = CBloomFilter.new
      bf.add("bar")
      bf.add("baz")

      bf2 = subject & bf
      refute_includes bf2, "foo"
      assert_includes bf2, "bar"
      refute_includes bf2, "baz"

      bf3 = bf & subject
      refute_includes bf3, "foo"
      assert_includes bf3, "bar"
      refute_includes bf3, "baz"
    end

    it "rejects incompatible filters" do
      error = assert_raises(ArgumentError) { subject & CBloomFilter.new(1000, 2) }
      assert_equal "bloom filters must have matching size and hash count", error.message
    end
  end

  describe "#|" do
    it "unions keys from another set" do
      subject.add("foo")
      subject.add("bar")

      bf = CBloomFilter.new
      bf.add("bar")
      bf.add("baz")

      bf2 = subject | bf
      assert_includes bf2, "foo"
      assert_includes bf2, "bar"
      assert_includes bf2, "baz"

      bf3 = bf | subject
      assert_includes bf3, "foo"
      assert_includes bf3, "bar"
      assert_includes bf3, "baz"
    end

    it "rejects incompatible filters" do
      error = assert_raises(ArgumentError) { subject | CBloomFilter.new(2000, 4) }
      assert_equal "bloom filters must have matching size and hash count", error.message
    end
  end

  describe "#bitmap" do
    it "returns a binary bitmap of all zeros when empty (including a terminating byte)" do
      bf = CBloomFilter.new(16)
      assert_equal "\x00\x00\x00".b, bf.bitmap
    end

    it "returns a binary bitmap representing the set" do
      bf = CBloomFilter.new(16, 4)
      bf.add("something")
      assert_equal "(\x82\x00".b, bf.bitmap
    end

    it "returns a binary bitmap representing the set even if not a multiple of 8 bits (includes padding)" do
      bf = CBloomFilter.new(20, 4)
      bf.add("wow")
      assert_equal "\x04\x14\x00\x00".b, bf.bitmap
    end
  end

  describe "#load" do
    it "overwrites the bitmap" do
      bf = CBloomFilter.new(1000, 4)
      bf.add("foo")
      bf.add("bar")
      subject.load(bf.bitmap)
      assert_includes subject, "foo"
      assert_includes subject, "bar"
    end

    it "rejects a short bitmap" do
      error = assert_raises(ArgumentError) { subject.load("\x00".b) }
      assert_equal "bitmap length must be 126 bytes", error.message
    end

    it "rejects a long bitmap" do
      error = assert_raises(ArgumentError) { subject.load("\x00".b * 127) }
      assert_equal "bitmap length must be 126 bytes", error.message
    end

    it "coerces bitmap-like objects to strings before loading" do
      bitmap_data = subject.bitmap
      bitmap = Object.new
      bitmap.define_singleton_method(:to_str) { bitmap_data }
      subject.load(bitmap)
      assert_equal 0, subject.set_bits
    end

    it "clears loaded padding bits beyond the configured size" do
      bf = CBloomFilter.new(20, 4)

      bf.load("\x00\x00\xF0\xFF".b)

      assert_equal 0, bf.set_bits
      assert_equal "\x00\x00\x00\x00".b, bf.bitmap
    end
  end
end
