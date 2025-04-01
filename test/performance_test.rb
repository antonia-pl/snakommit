require "test_helper"
require "fileutils"

class PerformanceTest < Minitest::Test
  def test_cache_operations
    cache = Snakommit::Performance::Cache.new(10, 0.1) # Small cache, short TTL
    
    # Set and get operations
    key = "test_key"
    value = "test_value"
    
    # Set value
    result = cache.set(key, value)
    assert_equal value, result
    
    # Get value
    result = cache.get(key)
    assert_equal value, result
    
    # Get non-existent key
    result = cache.get("non_existent")
    assert_nil result
    
    # Wait for TTL to expire
    sleep 0.2
    
    # Get expired key
    result = cache.get(key)
    assert_nil result
    
    # Test stats
    stats = cache.stats
    assert_kind_of Hash, stats
    assert_includes stats.keys, :hits
    assert_includes stats.keys, :misses
    assert_includes stats.keys, :hit_rate
  end
  
  def test_cache_cleanup
    cache = Snakommit::Performance::Cache.new(5, 60) # Very small max size
    
    # Add more items than max size
    10.times do |i|
      cache.set("key_#{i}", "value_#{i}")
    end
    
    # Check if cleanup worked
    stats = cache.stats
    assert stats[:size] <= 5, "Cache size should be limited to max_size"
    
    # Test invalidate
    cache.invalidate("key_0")
    assert_nil cache.get("key_0")
    
    # Test clear
    cache.clear
    assert_equal 0, cache.stats[:size]
  end
  
  def test_batch_processor
    processor = Snakommit::Performance::BatchProcessor.new(3)
    
    # Test with array of items
    items = (1..10).to_a
    processed = []
    
    result = processor.process_files(items) do |batch|
      processed.concat(batch)
      batch # Return the batch
    end
    
    # All items should have been processed
    assert_equal items, processed.sort
    assert_equal items, result.sort
    
    # Stats should be accurate
    stats = processor.stats
    assert_equal 10, stats[:total_processed]
    assert_equal 4, stats[:batch_count] # 3 batches of 3 + 1 batch of 1
    assert_in_delta 2.5, stats[:average_batch_size], 0.1
  end
  
  def test_parallel_helper_availability
    # Should return true or false based on whether parallel gem is available
    availability = Snakommit::Performance::ParallelHelper.available?
    assert_includes [true, false], availability
    
    # Processor count should be a positive integer
    count = Snakommit::Performance::ParallelHelper.processor_count
    assert count > 0, "Processor count should be positive"
    assert_kind_of Integer, count
  end
  
  def test_parallel_helper_process
    items = (1..10).to_a
    
    # Process sequentially regardless of gem availability
    result = Snakommit::Performance::ParallelHelper.process(items, threshold: 100) do |item|
      item * 2
    end
    
    assert_equal items.map { |i| i * 2 }, result
  end
  
  def test_monitor
    monitor = Snakommit::Performance::Monitor.new
    
    # Measure a block
    result = monitor.measure(:test_operation) do
      sleep 0.1
      "test_result"
    end
    
    # Block should return its value
    assert_equal "test_result", result
    
    # Report should include the measurement
    report = monitor.report
    assert_kind_of Array, report
    assert report.any? { |line| line.include?("test_operation") }
    
    # Measure the same operation again
    monitor.measure(:test_operation) do
      sleep 0.1
    end
    
    # Report should show 2 calls
    report = monitor.report
    assert report.any? { |line| line.include?("test_operation") && line.include?("2 calls") }
    
    # Reset should clear timings
    monitor.reset
    assert_empty monitor.report
  end
  
  def test_benchmark
    # Run a benchmark
    result = Snakommit::Performance::Benchmark.run("test_benchmark", 5) do
      sleep 0.01
    end
    
    # Result should include expected keys
    assert_kind_of Hash, result
    assert_includes result.keys, :real
    assert_includes result.keys, :avg
    assert_includes result.keys, :label
    assert_includes result.keys, :iterations
    
    # Avg should be approximately real / iterations
    assert_in_delta result[:real] / 5, result[:avg], 0.0001
  end
  
  def test_benchmark_compare
    # Compare two implementations
    implementations = {
      "fast" => lambda { sleep 0.01 },
      "slow" => lambda { sleep 0.02 }
    }
    
    results = Snakommit::Performance::Benchmark.compare(iterations: 3) do
      implementations
    end
    
    # Results should include both implementations
    assert_includes results.keys, "fast"
    assert_includes results.keys, "slow"
    
    # Fast implementation should be faster
    assert results["fast"][:avg] < results["slow"][:avg]
  end
  
  def test_memory_usage
    # Test memory usage functions
    usage = Snakommit::Performance::Memory.usage
    assert_kind_of Integer, usage
    
    # Measure memory usage
    result = Snakommit::Performance::Memory.measure do
      # Allocate some memory
      array = Array.new(1000) { "x" * 1000 }
      "test_result"
    end
    
    # Result should include memory stats and block result
    assert_kind_of Hash, result
    assert_includes result.keys, :before
    assert_includes result.keys, :after
    assert_includes result.keys, :diff
    assert_includes result.keys, :result
    assert_equal "test_result", result[:result]
  end
end 