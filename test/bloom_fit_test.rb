require "test_helper"

class BloomFitTest < Minitest::Spec
  subject { BloomFit.new(size: 100, hashes: 4) }

  describe ".new" do
    it "accepts size and hashes override" do
      bf = BloomFit.new(size: 10, hashes: 1)
      assert_equal 10, bf.size
      assert_equal 1, bf.hashes
    end

    it "has default capacity and false positive-rate" do
      bf = BloomFit.new
      # https://hur.st/bloomfilter/?n=100&p=0.001&m=&k=
      assert_equal 1438, bf.size
      assert_equal 10, bf.hashes
    end

    it "calculates size and hashes given a capacity and false postiive rate" do
      bf = BloomFit.new(capacity: 10_000, false_positive_rate: 0.0001)
      # https://hur.st/bloomfilter/?n=10000&p=0.0001&m=&k=
      assert_equal 191_702, bf.size
      assert_equal 14, bf.hashes
    end

    it "uses the fractional bits per element when calculating hashes" do
      bf = BloomFit.new(capacity: 100, false_positive_rate: 0.1)
      assert_equal 480, bf.size
      assert_equal 4, bf.hashes
    end

    it "uses at least one hash for probabilities near one" do
      bf = BloomFit.new(capacity: 100, false_positive_rate: 0.9)
      assert_equal 22, bf.size
      assert_equal 1, bf.hashes
      bf.add("key")
      assert_includes bf, "key"

      bf = BloomFit.new(capacity: 100, false_positive_rate: 1.0.prev_float)
      assert_equal 1, bf.size
      assert_equal 1, bf.hashes
    end

    it "supports small positive probabilities within the native hash limit" do
      bf = BloomFit.new(capacity: 1, false_positive_rate: 1e-70)
      assert_equal 336, bf.size
      assert_equal 233, bf.hashes
    end

    it "rejects probabilities requiring more hashes than the native limit" do
      assert_raises(ArgumentError) { BloomFit.new(capacity: 1, false_positive_rate: Float::MIN) }
    end

    it "requires a positive integer capacity" do
      [0, -1, 1.5, 100.0, Float::NAN, Float::INFINITY, nil, "100"].each do |capacity|
        assert_raises(ArgumentError) { BloomFit.new(capacity:) }
      end
    end

    it "rejects capacities whose calculated bit length is too large" do
      [1 << 32, 1 << 100, 1 << 1024].each do |capacity|
        assert_raises(RangeError) { BloomFit.new(capacity:) }
      end
    end

    it "requires a finite real probability strictly between zero and one" do
      [0, 1, -0.1, 1.1, Float::NAN, Float::INFINITY, -Float::INFINITY, nil, "0.1", Complex(0.1, 1)].each do |rate|
        assert_raises(ArgumentError) { BloomFit.new(false_positive_rate: rate) }
      end
    end

    it "accepts a rational probability" do
      bf = BloomFit.new(capacity: 100, false_positive_rate: Rational(1, 10))
      assert_equal 480, bf.size
      assert_equal 4, bf.hashes
    end

    it "rejects probabilities that round to zero or one as floats" do
      [Rational(1, 10**400), Rational((10**400) - 1, 10**400)].each do |rate|
        assert_raises(ArgumentError) { BloomFit.new(false_positive_rate: rate) }
      end
    end

    it "requires integer manual dimensions" do
      assert_raises(TypeError) { BloomFit.new(size: 100.5, hashes: 4) }
      assert_raises(TypeError) { BloomFit.new(size: 100, hashes: 4.5) }
    end
  end

  %i[dup clone].each do |copy_method|
    describe "##{copy_method}" do
      subject { BloomFit.new(size: 111, hashes: 5) }

      it "preserves the dimensions, membership, and serialized bytes" do
        subject.merge(["foo", "bar", "\x00\xFF".b])
        payload = subject.to_msgpack
        copy = subject.public_send(copy_method)

        refute_same subject, copy
        refute_same subject.bf, copy.bf
        assert_equal 111, copy.size
        assert_equal 5, copy.hashes
        assert_equal payload, copy.to_msgpack
        assert_includes copy, "foo"
        assert_includes copy, "bar"
        assert_includes copy, "\x00\xFF".b
      end

      it "isolates changes to the copy from the original" do
        subject.add("foo")
        bitmap = subject.bitmap
        copy = subject.public_send(copy_method)

        copy.clear
        assert_empty copy
        assert_equal bitmap, subject.bitmap

        copy.add("bar")
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
        assert_empty copy

        copy.add("foo")
        refute_empty copy
        assert_empty subject
      end

      it "preserves subclasses and their instance variables" do
        klass = Class.new(BloomFit) do
          attr_reader :label

          def initialize(label)
            @label = label
            super(size: 111, hashes: 5)
          end
        end
        original = klass.new("label").add("foo")
        copy = original.public_send(copy_method)

        assert_instance_of klass, copy
        assert_equal "label", copy.label
        assert_equal original.to_msgpack, copy.to_msgpack
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
      copy.clear
      assert_includes subject, "foo"
    end
  end

  describe "#empty?" do
    it "returns true when nothing set" do
      assert_equal true, subject.empty? # rubocop:disable Minitest/AssertTruthy
      assert_empty subject
    end

    it "returns false when something set" do
      subject << "key"
      assert_equal false, subject.empty? # rubocop:disable Minitest/RefuteFalse
      refute_empty subject
    end
  end

  describe "#add" do
    it "adds the key and returns self" do
      assert_equal subject, subject.add("test1")
      assert_equal subject, subject.add("test2")
      assert_includes subject, "test1"
      assert_includes subject, "test2"
    end

    it "is aliased as #<<" do
      subject << "test1" << "test2"
      assert_includes subject, "test1"
      assert_includes subject, "test2"
    end

    it "is aliased as #[]=, and handles truthy/falsey values" do
      subject["dog"] = :bar
      subject["cat"] = :foo
      assert_includes subject, "dog"
      assert_includes subject, "cat"

      subject["bat"] = nil
      subject["pig"] = false
      refute_includes subject, "bat"
      refute_includes subject, "pig"
    end

    it "casts using #to_s as necessary" do
      subject << :symbol << true << 12_345

      assert_includes subject, "symbol"
      assert_includes subject, :symbol
      assert_includes subject, "true"
      assert_includes subject, "12345"
      assert_includes subject, 12_345
    end
  end

  describe "#add?" do
    it "adds new key and returns self" do
      assert_equal subject, subject.add("test1")
      assert_equal subject, subject.add("test2")
      assert_includes subject, "test1"
      assert_includes subject, "test2"
    end

    it "return nil if the key already exists" do
      subject << "test1"
      subject << "test2"
      assert_includes subject, "test1"
      assert_includes subject, "test2"
      assert_nil subject.add?("test1")
      assert_nil subject.add?("test2")
    end
  end

  describe "#include?" do
    it "returns true when a key is in the set" do
      subject << "test1"
      subject << "test2"
      assert_equal true, subject.include?("test1") # rubocop:disable Minitest/AssertTruthy
      assert_equal true, subject.include?("test2") # rubocop:disable Minitest/AssertTruthy
    end

    it "returns false when a key is not in the set" do
      assert_equal false, subject.include?("test") # rubocop:disable Minitest/RefuteFalse
      assert_equal false, subject.include?("nada") # rubocop:disable Minitest/RefuteFalse
    end

    it "is aliased as #key?" do
      subject << "test1"
      subject << "test2"
      assert subject.key?("test1")
      assert subject.key?("test2")
      refute subject.key?("test3")
    end

    it "is aliased as #[]" do
      subject << "test1"
      subject << "test2"
      assert subject["test1"]
      assert subject["test2"]
      refute subject["test3"]
    end
  end

  describe "#clear" do
    it "zeroes the bits and returns self" do
      subject.add("test")
      assert_includes subject, "test"
      assert_includes subject.to_binary, "1"
      assert_equal subject, subject.clear
      refute_includes subject, "test"
      refute_includes subject.to_binary, "1"
    end
  end

  describe "#set_bits" do
    it "returns the number of bits set to 1" do
      bf = BloomFit.new(size: 100, hashes: 4)
      bf.add("bits")
      assert_equal 4, bf.set_bits

      bf = BloomFit.new(size: 100, hashes: 1)
      bf.add("bits")
      assert_equal 1, bf.set_bits
    end
  end

  describe "#bitmap" do
    it "returns a binary bitmap of all zeros when empty (including a terminating byte)" do
      bf = BloomFit.new(size: 16)
      assert_equal "\x00\x00\x00".b, bf.bitmap
    end

    it "returns a binary bitmap representing the set" do
      bf = BloomFit.new(size: 16, hashes: 4)
      bf.add("something")
      assert_equal "(\x82\x00".b, bf.bitmap
    end

    it "returns a binary bitmap representing the set even if not a multiple of 8 bits" do
      bf = BloomFit.new(size: 20, hashes: 4)
      bf.add("wow")
      assert_equal "\x04\x14\x00\x00".b, bf.bitmap
    end
  end

  describe "#to_hex" do
    it "returns a hex bitmap of all zeros when empty" do
      bf = BloomFit.new(size: 16)
      assert_equal "0000", bf.to_hex
    end

    it "returns a hex bitmap of all zeros when empty if not a multiple of 8 bits" do
      bf = BloomFit.new(size: 18)
      assert_equal "000000", bf.to_hex
    end

    it "returns a hex bitmap representing the set" do
      bf = BloomFit.new(size: 16, hashes: 4)
      bf.add("cool")
      assert_equal "1441", bf.to_hex
    end
  end

  describe "#to_binary" do
    it "returns a binary bitmap of all zeros when empty" do
      bf = BloomFit.new(size: 16)
      assert_equal "0000000000000000", bf.to_binary
    end

    it "returns a binary bitmap of all zeros when empty if not a multiple of 8 bits" do
      bf = BloomFit.new(size: 19)
      assert_equal "0000000000000000000", bf.to_binary
    end

    it "returns a binary bitmap representing the set" do
      bf = BloomFit.new(size: 16, hashes: 4)
      bf << "cool" << "cat"
      assert_equal "1001011001101001", bf.to_binary
    end
  end

  describe "#merge" do
    it "merges another BloomFit filter and returns self" do
      bf1 = BloomFit.new(size: 100, hashes: 2)
      bf2 = BloomFit.new(size: 100, hashes: 2)
      bf1 << "mouse"
      bf2 << "cat" << "dog"
      refute_includes bf1, "cat"
      refute_includes bf1, "dog"
      assert_equal bf1, bf1.merge(bf2)
      assert_includes bf1, "mouse"
      assert_includes bf1, "cat"
      assert_includes bf1, "dog"
      refute_includes bf2, "mouse"
      assert_includes bf2, "cat"
      assert_includes bf2, "dog"
    end

    it "merges an array and returns self" do
      subject << "mouse"
      assert_equal subject, subject.merge(%i[cat dog])
      assert_includes subject, "mouse"
      assert_includes subject, "cat"
      assert_includes subject, "dog"
    end

    it "merges a set" do
      subject << "mouse"
      subject.merge Set.new(%w[cat dog])
      assert_includes subject, "mouse"
      assert_includes subject, "cat"
      assert_includes subject, "dog"
    end

    it "merges a hash ignoring falsey values" do
      subject << "mouse"
      subject.merge({ cat: 1, dog: 2, ant: false, bug: nil })
      assert_includes subject, "mouse"
      assert_includes subject, "cat"
      assert_includes subject, "dog"
      refute_includes subject, "ant"
      refute_includes subject, "bug"
    end

    it "raises when merge is between incompatible filters" do
      bf1 = BloomFit.new(size: 10)
      bf2 = BloomFit.new(size: 20)
      assert_raises(ArgumentError) { bf1.merge(bf2) }
    end
  end

  describe "#&" do
    it "returns intersection of both filters" do
      bf1 = BloomFit.new(size: 35, hashes: 4)
      bf1.add("test")
      bf1.add("test1")

      bf2 = BloomFit.new(size: 35, hashes: 4)
      bf2.add("test")
      bf2.add("test2")

      bf3 = bf1 & bf2
      assert_equal 35, bf3.size
      assert_equal 4, bf3.hashes
      assert_includes bf3, "test"
      refute_includes bf3, "test1"
      refute_includes bf3, "test2"
    end

    it "is aliased as #intersection" do
      bf1 = BloomFit.new(size: 20, hashes: 4)
      bf1.add("test")
      bf1.add("test1")

      bf2 = BloomFit.new(size: 20, hashes: 4)
      bf2.add("test")

      bf3 = bf1.intersection(bf2)
      assert_includes bf3, "test"
      refute_includes bf3, "test1"
    end

    it "raises when intersection is between incompatible filters" do
      bf1 = BloomFit.new(size: 10)
      bf2 = BloomFit.new(size: 20)
      assert_raises(ArgumentError) { bf1 & bf2 }

      bf1 = BloomFit.new(size: 10, hashes: 2)
      bf2 = BloomFit.new(size: 10, hashes: 4)
      assert_raises(ArgumentError) { bf1 & bf2 }
    end
  end

  describe "#|" do
    it "returns union with other filter" do
      bf1 = BloomFit.new
      bf1.add("test")
      bf1.add("test1")

      bf2 = BloomFit.new
      bf2.add("test")
      bf2.add("test2")

      bf3 = bf1 | bf2
      assert_includes bf3, "test"
      assert_includes bf3, "test1"
      assert_includes bf3, "test2"
    end

    it "is aliased as #union" do
      bf1 = BloomFit.new(size: 20, hashes: 4)
      bf1.add("test")
      bf1.add("test1")

      bf2 = BloomFit.new(size: 20, hashes: 4)
      bf2.add("test")

      bf3 = bf1.union(bf2)
      assert_includes bf3, "test"
      assert_includes bf3, "test1"
    end

    it "raises when union is between incompatible filters" do
      bf1 = BloomFit.new(size: 10)
      bf2 = BloomFit.new(size: 20)
      assert_raises(ArgumentError) { bf1 | bf2 }
    end
  end

  describe "#stats" do
    it "returns current stats" do
      bf = BloomFit.new(size: 10, hashes: 3)
      expected = <<~STATS
        Number of filter buckets (m):  10
        Number of set bits (n):        0
        Number of filter hashes (k):   3
        Predicted false positive rate: 0.00%
      STATS
      assert_equal expected, bf.stats
    end

    it "estimates false positives from the current fill level" do
      bf = BloomFit.new(size: 10, hashes: 3)
      bf.bf.load("\x07\x00\x00".b)

      expected = <<~STATS
        Number of filter buckets (m):  10
        Number of set bits (n):        3
        Number of filter hashes (k):   3
        Predicted false positive rate: 2.70%
      STATS
      assert_equal expected, bf.stats
    end
  end

  describe "serialization" do
    after { FileUtils.rm_f("bf.out") }

    it "packs and unpacks" do
      bf = BloomFit.new(size: 111, hashes: 5)
      msg = bf.to_msgpack
      bf2 = BloomFit.unpack(msg)
      assert_equal 111, bf2.size
      assert_equal 5, bf2.hashes
      assert_empty bf2
    end

    it "saves" do
      bf = BloomFit.new
      assert bf.save("bf.out")
    end

    it "uses binary file io" do
      dumped = subject.to_msgpack
      writer = Minitest::Mock.new
      writer.expect(:call, dumped.bytesize, ["bf.out", dumped])

      reader = Minitest::Mock.new
      reader.expect(:call, dumped, ["bf.out"])

      File.stub(:binwrite, writer) do
        assert_equal dumped.bytesize, subject.save("bf.out")
      end

      File.stub(:binread, reader) do
        bf2 = BloomFit.load("bf.out")
        assert_equal subject.size, bf2.size
        assert_equal subject.hashes, bf2.hashes
      end

      writer.verify
      reader.verify
    end

    it "loads" do
      subject.add("foo")
      subject.add("bar")
      subject.save("bf.out")

      bf2 = BloomFit.load("bf.out")
      assert_includes bf2, "foo"
      assert_includes bf2, "bar"
      refute_includes bf2, "baz"

      assert_equal subject.size, bf2.size
      assert_equal subject.hashes, bf2.hashes
    end
  end
end
