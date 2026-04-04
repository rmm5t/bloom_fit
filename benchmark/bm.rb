#!/usr/bin/env ruby

require "benchmark"
require "bloom_fit"
require "securerandom"

n = 100_000

# Expecting 0.0001 false-positive
# See: https://hur.st/bloomfilter/?n=100000&p=.0001&m=&k=
bf = BloomFit.new(capacity: 100_000, false_positive_rate: 0.0001)
bf << "exists"

Benchmark.bm do |x|
  x.report("add") do
    n.times do
      bf << "exists"
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
end

puts
puts "EXPECTED FALSE-POSITIVE RATES:  0.0001"

puts
puts "Constant length adds"
bf.clear
n.times do
  bf << Random.alphanumeric(64)
end

puts "Constant length checks"
c = 0
n.times do
  c += 1 if bf.include?(Random.alphanumeric(64))
end
printf "  false-positive rate:          %.6f\n", (c.to_f / n)

puts "Variable length checks"
c = 0
n.times do
  c += 1 if bf.include?(Random.alphanumeric(rand(20..512)))
end
printf " false-positive rate:           %.6f\n", (c.to_f / n)

# ----------------------------------------

puts
puts "Variable length adds"
bf.clear
n.times do
  bf << Random.alphanumeric(rand(20..512))
end

puts "Constant length checks"
c = 0
n.times do
  c += 1 if bf.include?(Random.alphanumeric(64))
end
printf "  false-positive rate:          %.6f\n", (c.to_f / n)

puts "Variable length checks"
c = 0
n.times do
  c += 1 if bf.include?(Random.alphanumeric(rand(20..512)))
end
printf "  false-positive rate:          %.6f\n", (c.to_f / n)

# ----------------------------------------

puts
puts "8x uuid adds"
bf.clear
n.times do
  bf << (Random.uuid * 8)
end

puts "8x uuid checks"
c = 0
n.times do
  c += 1 if bf.include?(Random.uuid * 8)
end
printf "  false-positive rate:          %.6f\n", (c.to_f / n)
