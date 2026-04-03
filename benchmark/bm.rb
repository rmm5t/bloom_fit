#!/usr/bin/env ruby

require "benchmark"
require "bloom_fit"
require "securerandom"

n = 1_000_000
c = 0

Benchmark.bm do |x|
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

printf "false-positive rate:  %.4f\n", (c.to_f / n)

#                           user     system      total        real
# insert                0.006178   0.000063   0.006241 (  0.006244)
# lookup present        0.009735   0.000039   0.009774 (  0.009795)
# lookup missing        0.008206   0.000030   0.008236 (  0.008239)
# false-positive check  0.127271   0.163654   0.290925 (  0.290971)
# false-positive rate:  0.0001
