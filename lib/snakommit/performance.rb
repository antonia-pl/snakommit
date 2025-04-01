# frozen_string_literal: true

require 'benchmark'

module Snakommit
  # Performance optimization utilities for Snakommit
  class Performance
    # Cache for expensive Git operations
    class Cache
      # Initialize a new cache
      # @param max_size [Integer] Maximum number of items to cache
      # @param ttl [Integer] Time-to-live in seconds for cached items
      def initialize(max_size = 100, ttl = 300) # 5 minutes TTL by default
        @cache = {}
        @max_size = max_size
        @ttl = ttl
        @hits = 0
        @misses = 0
      end

      # Get a value from the cache
      # @param key [Object] Cache key
      # @return [Object, nil] Cached value or nil if not found or expired
      def get(key)
        return nil unless @cache.key?(key)
        entry = @cache[key]
        
        if Time.now - entry[:timestamp] > @ttl
          @misses += 1
          return nil
        end

        @hits += 1
        entry[:value]
      end

      # Set a value in the cache
      # @param key [Object] Cache key
      # @param value [Object] Value to cache
      # @return [Object] The value that was cached
      def set(key, value)
        cleanup if @cache.size >= @max_size
        @cache[key] = { value: value, timestamp: Time.now }
        @misses += 1
        value
      end

      # Remove a specific key from the cache
      # @param key [Object] Cache key to invalidate
      # @return [nil]
      def invalidate(key)
        @cache.delete(key)
        nil
      end

      # Clear the entire cache
      # @return [Hash] Empty hash
      def clear
        @cache = {}
      end
      
      # Get cache stats
      # @return [Hash] Cache statistics
      def stats
        {
          size: @cache.size,
          max_size: @max_size,
          ttl: @ttl,
          hits: @hits,
          misses: @misses,
          hit_rate: hit_rate
        }
      end
      
      # Calculate cache hit rate
      # @return [Float] Cache hit rate as a percentage
      def hit_rate
        total = @hits + @misses
        return 0.0 if total.zero?
        (@hits.to_f / total) * 100
      end

      private

      # Clean up expired or oldest entries when cache is full
      # @return [nil]
      def cleanup
        # Remove expired entries first
        expired_keys = @cache.select { |_, v| Time.now - v[:timestamp] > @ttl }.keys
        @cache.delete_if { |k, _| expired_keys.include?(k) }

        # If still too large, remove oldest entries
        if @cache.size >= @max_size
          sorted_keys = @cache.sort_by { |_, v| v[:timestamp] }.map(&:first)
          sorted_keys[0...(@cache.size - @max_size / 2)].each { |k| @cache.delete(k) }
        end
        
        nil
      end
    end

    # Batch processing for Git operations
    class BatchProcessor
      # Initialize a new batch processor
      # @param batch_size [Integer] Default batch size for processing
      def initialize(batch_size = 100)
        @batch_size = batch_size
        @total_processed = 0
        @batch_count = 0
      end

      # Process files in batches
      # @param files [Array<String>] List of files to process
      # @param batch_size [Integer, nil] Optional override for batch size
      # @yield [batch] Yields each batch of files for processing
      # @yieldparam batch [Array<String>] A batch of files
      # @return [Array] Combined results from all batches
      def process_files(files, batch_size = nil, &block)
        size = batch_size || @batch_size
        results = []
        
        files.each_slice(size).each_with_index do |batch, index|
          @batch_count += 1
          batch_result = block.call(batch)
          @total_processed += batch.size
          results.concat(Array(batch_result))
        end
        
        results
      end
      
      # Get batch processing stats
      # @return [Hash] Batch processing statistics
      def stats
        {
          batch_size: @batch_size,
          total_processed: @total_processed,
          batch_count: @batch_count,
          average_batch_size: average_batch_size
        }
      end
      
      # Calculate average batch size
      # @return [Float] Average batch size
      def average_batch_size
        return 0.0 if @batch_count.zero?
        @total_processed.to_f / @batch_count
      end
    end

    # Helper for parallel processing where appropriate
    class ParallelHelper
      # Check if parallel processing is available
      # @return [Boolean] True if the parallel gem is available
      def self.available?
        begin
          require 'parallel'
          true
        rescue LoadError
          false
        end
      end

      # Process items in parallel if possible, otherwise sequentially
      # @param items [Array] Items to process
      # @param options [Hash] Options for parallel processing
      # @option options [Integer] :threshold Minimum number of items to use parallel processing
      # @option options [Integer] :workers Number of workers to use (defaults to processor count)
      # @yield [item] Block to process each item
      # @yieldparam item [Object] An item to process
      # @return [Array] Results of processing all items
      def self.process(items, options = {}, &block)
        threshold = options.delete(:threshold) || 10
        workers = options.delete(:workers) || processor_count
        
        if available? && items.size > threshold
          require 'parallel'
          Parallel.map(items, { in_processes: workers }.merge(options)) { |item| block.call(item) }
        else
          items.map(&block)
        end
      end
      
      # Get number of available processors
      # @return [Integer] Number of processors available
      def self.processor_count
        if defined?(Etc) && Etc.respond_to?(:nprocessors)
          Etc.nprocessors
        else
          2 # Conservative default
        end
      end
    end

    # Performance monitoring and reporting
    class Monitor
      # Initialize a new monitor
      def initialize
        @timings = {}
        @counts = {}
      end

      # Measure execution time of a block
      # @param label [String, Symbol] Label for the measurement
      # @yield Block to measure
      # @return [Object] Result of the block
      def measure(label)
        start_time = Time.now
        result = yield
        duration = Time.now - start_time
        
        @timings[label] ||= 0
        @timings[label] += duration
        
        @counts[label] ||= 0
        @counts[label] += 1
        
        result
      end

      # Get a report of all timings
      # @return [Array<String>] Formatted timing report lines
      def report
        @timings.sort_by { |_, v| -v }.map do |k, v|
          count = @counts[k]
          avg = count > 0 ? v / count : 0
          "#{k}: #{v.round(3)}s total, #{count} calls, #{avg.round(3)}s avg"
        end
      end
      
      # Reset all timings
      # @return [nil]
      def reset
        @timings.clear
        @counts.clear
        nil
      end
    end
    
    # Benchmarking utility for snakommit operations
    class Benchmark
      # Run a benchmark test
      # @param label [String] Label for the benchmark
      # @param iterations [Integer] Number of iterations to run
      # @yield Block to benchmark
      # @return [Hash] Benchmark results
      def self.run(label, iterations = 1)
        results = {}
        
        # Warm up
        yield
        
        # Run the benchmark
        results[:real] = ::Benchmark.realtime do
          iterations.times { yield }
        end
        
        results[:avg] = results[:real] / iterations
        results[:label] = label
        results[:iterations] = iterations
        
        results
      end
      
      # Compare performance of multiple implementations
      # @param options [Hash] Options for comparison
      # @option options [Integer] :iterations Number of iterations
      # @option options [Boolean] :verbose Print results
      # @yield Block that returns a hash of callable objects to compare
      # @return [Hash] Comparison results
      def self.compare(options = {})
        iterations = options[:iterations] || 100
        verbose = options[:verbose] || false
        
        implementations = yield
        results = {}
        
        implementations.each do |name, callable|
          results[name] = run(name, iterations) { callable.call }
        end
        
        if verbose
          puts "Performance comparison (#{iterations} iterations):"
          results.sort_by { |_, v| v[:avg] }.each do |name, result|
            puts "  #{name}: #{result[:avg].round(6)}s avg (total: #{result[:real].round(3)}s)"
          end
        end
        
        results
      end
    end
    
    # Memory usage tracking
    class Memory
      # Get current memory usage in KB
      # @return [Integer] Memory usage in KB
      def self.usage
        case RbConfig::CONFIG['host_os']
        when /linux/
          `ps -o rss= -p #{Process.pid}`.to_i
        when /darwin/
          `ps -o rss= -p #{Process.pid}`.to_i
        when /windows|mswin|mingw/
          # Not implemented for Windows
          0
        else
          0
        end
      end
      
      # Measure memory usage before and after a block execution
      # @yield Block to measure
      # @return [Hash] Memory usage statistics
      def self.measure
        before = usage
        result = yield
        after = usage
        
        {
          before: before,
          after: after,
          diff: after - before,
          result: result
        }
      end
    end
  end
end 