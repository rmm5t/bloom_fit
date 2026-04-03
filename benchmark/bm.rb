#!/usr/bin/env ruby

require "benchmark"
require "bloom_fit"
require "securerandom"

n = 1_000_000
c = 0

Benchmark.bm do |x|
  # Expecting 0.0001 false-positive
  # See: https://hur.st/bloomfilter/?n=1000000&p=.0001&m=&k=
  bf = BloomFit.new(size: 19_000_000, hashes: 13)
  bf.insert("exists")

  x.report("insert") do
    n.times do
      bf.insert("exists")
    end
  end

  x.report("lookup present") do
    n.times do
      bf.include?("exists")
    end
  end

  x.report("lookup missing") do
    n.times do
      bf.include?("missing")
    end
  end

  x.report("false-positive check") do
    n.times do
      bf.insert(SecureRandom.uuid)
    end
    n.times do
      c += 1 if bf.include?(SecureRandom.uuid)
    end
  end
end

puts
puts   "expected false-positive rate:  0.0001"
printf "actual false-positive rate:    %.4f\n", (c.to_f / n)

#                           user     system      total        real
# insert                0.059581   0.000363   0.059944 (  0.059973)
# lookup present        0.104014   0.000898   0.104912 (  0.104924)
# lookup missing        0.092725   0.000854   0.093579 (  0.093591)
# false-positive check  1.381140   1.695013   3.076153 (  3.077911)

# expected false-positive rate:  0.0001
# actual false-positive rate:    0.0001
