# BloomFit makes Bloom Filter tuning easy

BloomFit provides a MRI/C-based non-counting bloom filter for use in your Ruby projects. It is heavily based on [bloomfilter-rb]'s native implementation, but provides a better hashing distribution by using DJB2 over CRC32, avoids the need to supply a seed, removes counting abilities, improves performance for very large datasets, and will automatically calculate the bit size (m) and the number of hashes (k) when given a capacity and false-positive-rate.

A [Bloom filter](http://en.wikipedia.org/wiki/Bloom_filter) is a space-efficient probabilistic data structure that is used to test whether an element is a member of a set. False positives are possible, but false negatives are not. Instead of using k different hash functions, this implementation a DJB2 hash with k seeds from the CRC table.

Performance of the Bloom filter depends on the following:

- size of the bit array
- number of hash functions

BloomFit is a fork of [bloomfilter-rb].

## Resources

- Background: [Bloom filter](http://en.wikipedia.org/wiki/Bloom_filter)
- Determining parameters: [Scalable Datasets: Bloom Filters in Ruby](http://www.igvita.com/2008/12/27/scalable-datasets-bloom-filters-in-ruby/)
- Applications & reasons behind bloom filter: [Flow analysis: Time based bloom filter](http://www.igvita.com/2010/01/06/flow-analysis-time-based-bloom-filters/)

## Examples

MRI/C implementation which creates an in-memory filter which can be saved and reloaded from disk.

If you'd like to specifcy the expected item count and the false-positive rate you can tolerate:

```ruby
require "bloom_fit'

bf = BloomFit.new(capacity: 250, false_positive_rate: 0.001)
bf.add("cat")
bf.include?("cat")     # => true
bf.include?("dog")     # => false

# Hash syntax with a bloom filter!
bf["bird"] = "bar"
bf["bird"]             # => true
bf["mouse"]            # => false

bf.stats
# => Number of filter bits (m): 3600
# => Number of set bits (n): 20
# => Number of filter hashes (k) : 10
# => Predicted false positive rate = 0.00%
```

If you'd like more control over the traditional inputs like bit size and the number of hashes:

```ruby
require "bloom_fit'

bf = BloomFit.new(size: 100, hashes: 2)
bf.add("cat")
bf.include?("cat")     # => true
bf.include?("dog")     # => false

# Hash syntax with a bloom filter!
bf["bird"] = "bar"
bf["bird"]             # => true
bf["mouse"]            # => false

bf.stats
# => Number of filter bits (m): 100
# => Number of set bits (n): 4
# => Number of filter hashes (k) : 2
# => Predicted false positive rate = 10.87%
```

## Credits

- Tatsuya Mori <valdzone@gmail.com> (Original C implementation)
- Ilya Grigorik [@igrigorik](https://github.com/igrigorik) ([bloomfilter-rb] gem)
- Bharanee Rathna [@deepfryed](https://github.com/deepfryed) ([bloom-filter](https://github.com/deepfryed/bloom-filter) gem)

## License

[MIT License](https://rmm5t.mit-license.org/)

[bloomfilter-rb]: https://github.com/igrigorik/bloomfilter-rb
