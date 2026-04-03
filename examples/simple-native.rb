#!/usr/bin/env ruby
require "bloom_fit"

WORDS = %w(duck penguin bear panda)
TEST = %w(penguin moose racooon)

bf = BloomFit.new(size: 1000, hashes: 2)

WORDS.each { |w| bf.insert(w) }
TEST.each do |w|
  puts "#{w}: #{bf.include?(w)}"
end

puts
bf.stats

# penguin: true
# moose: false
# racooon: false

# Number of filter buckets (m): 1000
# Number of bits per buckets (b): 1
# Number of set bits (n): 8
# Number of filter hashes (k) : 2
# Predicted false positive rate = 0.03%
