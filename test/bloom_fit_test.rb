require "test_helper"

class BloomFitTest < Minitest::Spec
  subject { BloomFit.new }

  it "clears" do
    bf = BloomFit.new(size: 100, hashes: 2)
    bf.insert("test")
    assert_includes bf, "test"
    bf.clear
    refute_includes bf, "test"
  end

  it "merges" do
    bf1 = BloomFit.new(size: 100, hashes: 2)
    bf2 = BloomFit.new(size: 100, hashes: 2)
    bf2.insert("test")
    refute_includes bf1, "test"
    bf1.merge!(bf2)
    assert_includes bf1, "test"
    assert_includes bf2, "test"
  end

  it "tests set membership" do
    bf = BloomFit.new(size: 100, hashes: 2)
    bf.insert("test")
    bf.insert("test1")

    assert_includes bf, "test"
    refute_includes bf, "abcd"
    assert bf.include?("test", "test1") # rubocop:disable Minitest/AssertIncludes
    refute bf.include?("test1", "abcd") # rubocop:disable Minitest/RefuteIncludes
  end

  it "works with any object's to_s" do
    subject.insert(:test)
    subject.insert(:test1)
    subject.insert(12_345)

    assert_includes subject, "test"
    refute_includes subject, "abcd"
    assert_includes subject, "12345"
  end

  it "returns the number of bits set to 1" do
    bf = BloomFit.new(hashes: 4)
    bf.insert("test")
    assert_equal 4, bf.set_bits

    bf = BloomFit.new(hashes: 1)
    bf.insert("test")
    assert_equal 1, bf.set_bits
  end

  it "returns intersection with other filter" do
    bf1 = BloomFit.new
    bf1.insert("test")
    bf1.insert("test1")

    bf2 = BloomFit.new
    bf2.insert("test")
    bf2.insert("test2")

    bf3 = bf1 & bf2
    assert_includes bf3, "test"
    refute_includes bf3, "test1"
    refute_includes bf3, "test2"
  end

  it "raises an exception when intersection is to be computed for incompatible filters" do
    bf1 = BloomFit.new(size: 10)
    bf1.insert("test")

    bf2 = BloomFit.new(size: 20)
    bf2.insert("test")

    assert_raises(BloomFit::ConfigurationMismatch) { bf1 & bf2 }
  end

  it "returns union with other filter" do
    bf1 = BloomFit.new
    bf1.insert("test")
    bf1.insert("test1")

    bf2 = BloomFit.new
    bf2.insert("test")
    bf2.insert("test2")

    bf3 = bf1 | bf2
    assert_includes bf3, "test"
    assert_includes bf3, "test1"
    assert_includes bf3, "test2"
  end

  it "raises an exception when union is to be computed for incompatible filters" do
    bf1 = BloomFit.new(size: 10)
    bf1.insert("test")

    bf2 = BloomFit.new(size: 20)
    bf2.insert("test")

    assert_raises(BloomFit::ConfigurationMismatch) { bf1 | bf2 }
  end

  it "outputs current stats" do
    subject.insert("test")
    assert subject.stats
  end

  describe "serialization" do
    after { File.unlink("bf.out") }

    it "marshalls" do
      bf = BloomFit.new
      assert bf.save("bf.out")
    end

    it "loads from marshalled" do
      subject.insert("foo")
      subject.insert("bar")
      subject.save("bf.out")

      bf2 = BloomFit.load("bf.out")
      assert_includes bf2, "foo"
      assert_includes bf2, "bar"
      refute_includes bf2, "baz"

      assert subject.send(:same_parameters?, bf2)
    end
  end
end
