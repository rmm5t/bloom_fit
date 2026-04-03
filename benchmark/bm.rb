#!/usr/bin/env ruby

require "benchmark"
require "bloom_fit"
require "securerandom"

n = 100_000
c = 0

# Expecting 0.0001 false-positive
# See: https://hur.st/bloomfilter/?n=100000&p=.0001&m=&k=
bf = BloomFit.new(size: 1_917_012, hashes: 14)
bf.insert("exists")

Benchmark.bm do |x|
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
end

puts
puts "false-positive checks - constant adds; constant checks:"
bf.clear
c = 0
n.times do
  bf.insert(Random.alphanumeric(64))
end
n.times do
  c += 1 if bf.include?(Random.alphanumeric(64))
end
puts   "expected false-positive rate:  0.0001"
printf "actual false-positive rate:    %.6f\n", (c.to_f / n)

# ----------------------------------------

puts
puts "false-positive checks - variable adds; constant checks:"
bf.clear
c = 0
n.times do
  bf.insert(Random.alphanumeric(rand(20..512)))
end
n.times do
  c += 1 if bf.include?(Random.alphanumeric(64))
end
puts   "expected false-positive rate:  0.0001"
printf "actual false-positive rate:    %.6f\n", (c.to_f / n)

# ----------------------------------------

puts
puts "false-positive checks - constant adds and variable checks:"
bf.clear
c = 0
n.times do
  bf.insert(Random.alphanumeric(64))
end
n.times do
  c += 1 if bf.include?(Random.alphanumeric(rand(20..512)))
end
puts   "expected false-positive rate:  0.0001"
printf "actual false-positive rate:    %.6f\n", (c.to_f / n)

# ----------------------------------------

puts
puts "false-positive checks - variable adds; variable checks:"
bf.clear
c = 0
n.times do
  bf.insert(Random.alphanumeric(rand(20..512)))
end
n.times do
  c += 1 if bf.include?(Random.alphanumeric(rand(20..512)))
end
puts   "expected false-positive rate:  0.0001"
printf "actual false-positive rate:    %.6f\n", (c.to_f / n)

# # ----------------------------------------

puts
puts "false-positive checks - 8x uuid adds; 8x uuid checks:"
bf.clear
c = 0
n.times do
  bf.insert(Random.uuid * 8)
end
n.times do
  c += 1 if bf.include?(Random.uuid * 8)
end
puts   "expected false-positive rate:  0.0001"
printf "actual false-positive rate:    %.6f\n", (c.to_f / n)
