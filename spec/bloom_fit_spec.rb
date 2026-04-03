require "helper"

describe BloomFit do
  it "clears" do
    bf = BloomFit.new(size: 100, hashes: 2)
    bf.insert("test")
    expect(bf.include?("test")).to be true
    bf.clear
    expect(bf.include?("test")).to be false
  end

  it "merges" do
    bf1 = BloomFit.new(size: 100, hashes: 2)
    bf2 = BloomFit.new(size: 100, hashes: 2)
    bf2.insert("test")
    expect(bf1.include?("test")).to be false
    bf1.merge!(bf2)
    expect(bf1.include?("test")).to be true
    expect(bf2.include?("test")).to be true
  end

  it "tests set membership" do
    bf = BloomFit.new(size: 100, hashes: 2)
    bf.insert("test")
    bf.insert("test1")

    expect(bf.include?("test")).to be true
    expect(bf.include?("abcd")).to be false
    expect(bf.include?("test", "test1")).to be true
    expect(bf.include?("test1", "abcd")).to be false
  end

  it "works with any object's to_s" do
    subject.insert(:test)
    subject.insert(:test1)
    subject.insert(12_345)

    expect(subject.include?("test")).to be true
    expect(subject.include?("abcd")).to be false
    expect(subject.include?("12345")).to be true
  end

  it "returns the number of bits set to 1" do
    bf = BloomFit.new(hashes: 4)
    bf.insert("test")
    expect(bf.set_bits).to eq 4

    bf = BloomFit.new(hashes: 1)
    bf.insert("test")
    expect(bf.set_bits).to eq 1
  end

  it "returns intersection with other filter" do
    bf1 = BloomFit.new
    bf1.insert("test")
    bf1.insert("test1")

    bf2 = BloomFit.new
    bf2.insert("test")
    bf2.insert("test2")

    bf3 = bf1 & bf2
    expect(bf3.include?("test")).to be true
    expect(bf3.include?("test1")).to be false
    expect(bf3.include?("test2")).to be false
  end

  it "raises an exception when intersection is to be computed for incompatible filters" do
    bf1 = BloomFit.new(size: 10)
    bf1.insert("test")

    bf2 = BloomFit.new(size: 20)
    bf2.insert("test")

    expect { bf1 & bf2 }.to raise_error(BloomFit::ConfigurationMismatch)
  end

  it "returns union with other filter" do
    bf1 = BloomFit.new
    bf1.insert("test")
    bf1.insert("test1")

    bf2 = BloomFit.new
    bf2.insert("test")
    bf2.insert("test2")

    bf3 = bf1 | bf2
    expect(bf3.include?("test")).to be true
    expect(bf3.include?("test1")).to be true
    expect(bf3.include?("test2")).to be true
  end

  it "raises an exception when union is to be computed for incompatible filters" do
    bf1 = BloomFit.new(size: 10)
    bf1.insert("test")

    bf2 = BloomFit.new(size: 20)
    bf2.insert("test")

    expect { bf1 | bf2 }.to raise_error(BloomFit::ConfigurationMismatch)
  end

  it "outputs current stats" do
    subject.insert("test")
    expect { subject.stats }.not_to raise_error
  end

  context "serialization" do
    after { File.unlink("bf.out") }

    it "marshalls" do
      bf = BloomFit.new
      expect { bf.save("bf.out") }.not_to raise_error
    end

    it "loads from marshalled" do
      subject.insert("foo")
      subject.insert("bar")
      subject.save("bf.out")

      bf2 = BloomFit.load("bf.out")
      expect(bf2.include?("foo")).to be true
      expect(bf2.include?("bar")).to be true
      expect(bf2.include?("baz")).to be false

      expect(subject.send(:same_parameters?, bf2)).to be true
    end
  end
end
