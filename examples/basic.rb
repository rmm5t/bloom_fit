#!/usr/bin/env ruby

require "bloom_fit"

WORDS = %w(duck penguin bear panda).freeze
TEST = %w(penguin moose racooon).freeze

bf = BloomFit.new(capacity: 40)

WORDS.each { |w| bf.add(w) }
TEST.each do |w|
  puts "#{w}: #{bf.include?(w)}"
end

puts
puts bf.stats

# penguin: true
# moose: false
# racooon: false

# Number of filter buckets (m):  576
# Number of set bits (n):        39
# Number of filter hashes (k):   10
# Predicted false positive rate: 0.08%
