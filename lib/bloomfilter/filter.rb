module BloomFilter
  class Filter
    def stats
      fp = ((1.0 - Math.exp(-(@opts[:hashes] * size).to_f / @opts[:size])) ** @opts[:hashes]) * 100
      printf "Number of filter buckets (m): %d\n", @opts[:size]
      printf "Number of bits per buckets (b): %d\n", @opts[:bucket]
      printf "Number of set bits (n): %d\n", set_bits
      printf "Number of filter hashes (k) : %d\n", @opts[:hashes]
      printf "Predicted false positive rate = %.2f%%\n", fp
    end
  end
end
