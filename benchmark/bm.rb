$:<< "lib"

require "benchmark"
require "bloom_fit"
require "securerandom"

n = 100_000
c = 0

Benchmark.bm do |x|
  bf = BloomFit.new(size: 1_900_000, hashes: 13)
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

printf "false-positive rate:  %.4f\n", (c.to_f / n.to_f)

#       user     system      total        real
# insert  1.000000   0.380000   1.380000 (  1.942181)
# lookup present  1.030000   0.470000   1.500000 (  2.577577)
# lookup missing  0.370000   0.160000   0.530000 (  1.060429)
