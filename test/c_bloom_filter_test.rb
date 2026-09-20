require "test_helper"

class CBloomFilterTest < Minitest::Spec
  subject { CBloomFilter.new }

  describe ".new" do
    it "rejects more than two arguments" do
      error = assert_raises(ArgumentError) { CBloomFilter.new(1, 2, 3) }
      assert_equal "wrong number of arguments (given 3, expected 0..2)", error.message
    end
  end

  %i[dup clone].each do |copy_method|
    describe "##{copy_method}" do
      subject { CBloomFilter.new(111, 5) }

      it "preserves the dimensions, bitmap, and membership" do
        ["foo", "bar", "\x00\xFF".b].each { |key| subject.add(key) }
        copy = subject.public_send(copy_method)

        refute_same subject, copy
        assert_equal 111, copy.m
        assert_equal 5, copy.k
        assert_equal subject.bitmap, copy.bitmap
        assert_equal subject.set_bits, copy.set_bits
        assert_includes copy, "foo"
        assert_includes copy, "bar"
        assert_includes copy, "\x00\xFF".b
      end

      it "isolates changes to the copy from the original" do
        subject.add("foo")
        bitmap = subject.bitmap
        copy = subject.public_send(copy_method)

        copy.clear
        assert_equal 0, copy.set_bits
        assert_equal bitmap, subject.bitmap

        copy.add("bar")
        assert_predicate copy.set_bits, :positive?
        assert_includes copy, "bar"
        assert_equal bitmap, subject.bitmap
      end

      it "isolates changes to the original from the copy" do
        subject.add("foo")
        bitmap = subject.bitmap
        copy = subject.public_send(copy_method)

        subject.clear
        subject.add("bar")
        assert_equal bitmap, copy.bitmap
        assert_includes copy, "foo"
      end

      it "independently copies an empty filter" do
        copy = subject.public_send(copy_method)
        assert_equal 0, copy.set_bits

        copy.add("foo")
        assert_predicate copy.set_bits, :positive?
        assert_equal 0, subject.set_bits
      end

      it "preserves subclasses and their instance variables" do
        klass = Class.new(CBloomFilter) do
          attr_reader :label

          def initialize(label)
            @label = label
            super(111, 5)
          end
        end
        original = klass.new("label")
        original.add("foo")
        copy = original.public_send(copy_method)

        assert_instance_of klass, copy
        assert_equal "label", copy.label
        assert_equal original.bitmap, copy.bitmap
        copy.clear
        assert_includes original, "foo"
      end
    end
  end

  describe "copying frozen filters" do
    it "preserves Ruby's dup and clone frozen-state behavior" do
      subject.add("foo")
      subject.freeze

      copy = subject.dup
      refute_predicate copy, :frozen?
      assert_predicate subject.clone, :frozen?
      refute_predicate subject.clone(freeze: false), :frozen?
      assert_equal subject.bitmap, copy.bitmap
      copy.clear
      assert_includes subject, "foo"
    end
  end

  describe "#initialize_copy" do
    it "can replace an existing filter's dimensions and bitmap" do
      source = CBloomFilter.new(111, 5)
      source.add("foo")
      subject.add("bar")

      assert_same subject, subject.send(:initialize_copy, source)
      assert_equal 111, subject.m
      assert_equal 5, subject.k
      assert_equal source.bitmap, subject.bitmap
      subject.clear
      assert_includes source, "foo"
    end

    it "leaves the bitmap intact when copying itself" do
      subject.add("foo")
      bitmap = subject.bitmap

      assert_same subject, subject.send(:initialize_copy, subject)
      assert_equal bitmap, subject.bitmap
    end

    it "rejects a different object type" do
      assert_raises(TypeError) { subject.send(:initialize_copy, Object.new) }
    end

    it "rejects replacing a frozen receiver" do
      subject.freeze
      assert_raises(FrozenError) { subject.send(:initialize_copy, CBloomFilter.new) }
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

    it "rejects negative values that would wrap to a positive int" do
      assert_raises(ArgumentError, RangeError) { CBloomFilter.new(-(1 << 32) + 16) }
    end

    it "rejects integers outside the native long range" do
      [1 << 100, -(1 << 100)].each do |size|
        assert_raises(RangeError) { CBloomFilter.new(size) }
      end
    end

    it "requires an integer bit length" do
      [16.5, 16.0, Float::NAN, Float::INFINITY, Rational(33, 2), nil, "16"].each do |size|
        assert_raises(TypeError) { CBloomFilter.new(size) }
      end
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

    it "accepts the full salt table" do
      bf = CBloomFilter.new(1000, 256)
      assert_equal 256, bf.k
      bf.add("key")
      assert_includes bf, "key"
    end

    it "rejects negative values that would wrap to a positive int" do
      assert_raises(ArgumentError, RangeError) { CBloomFilter.new(1000, -(1 << 32) + 4) }
    end

    it "rejects values larger than the native int range" do
      assert_raises(RangeError) { CBloomFilter.new(1000, 1 << 31) }
    end

    it "rejects integers outside the native long range" do
      [1 << 100, -(1 << 100)].each do |hashes|
        assert_raises(RangeError) { CBloomFilter.new(1000, hashes) }
      end
    end

    it "requires an integer hash count" do
      [4.5, 4.0, Float::NAN, Float::INFINITY, Rational(9, 2), nil, "4"].each do |hashes|
        assert_raises(TypeError) { CBloomFilter.new(1000, hashes) }
      end
    end
  end

  describe "#empty?" do
    it "returns true for a new filter" do
      assert_equal true, subject.empty? # rubocop:disable Minitest/AssertTruthy
    end

    it "returns false after adding a key and true after clearing" do
      subject.add("foo")
      assert_equal false, subject.empty? # rubocop:disable Minitest/RefuteFalse

      subject.clear
      assert_empty subject
    end

    it "detects a set bit in the first byte" do
      bf = CBloomFilter.new(20, 4)
      bf.load("\x01\x00\x00\x00".b)
      refute_empty bf
    end

    it "detects the last valid bit across byte boundaries without changing the bitmap" do
      [1, 7, 8, 9, 16, 20, 1000].each do |size|
        bf = CBloomFilter.new(size, 1)
        bitmap = bf.bitmap
        bitmap.setbyte((size - 1) / 8, 1 << ((size - 1) % 8))
        bf.load(bitmap)

        refute_empty bf
        assert_equal bitmap, bf.bitmap
      end
    end

    it "recognizes an empty bitmap loaded over a populated filter" do
      bitmap = subject.bitmap
      subject.add("foo")
      subject.load(bitmap)
      assert_empty subject
    end

    it "reports empty when only padding bits were present in the loaded bitmap" do
      bf = CBloomFilter.new(20, 4)
      bf.load("\x00\x00\xF0\xFF".b)
      assert_empty bf
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
