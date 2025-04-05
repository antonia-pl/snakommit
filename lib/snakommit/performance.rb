# frozen_string_literal: true

require 'benchmark'

module Snakommit
  # Performance optimization utilities for Snakommit
  class Performance
    # Cache for expensive Git operations
    class Cache
      attr_reader :max_size, :ttl
      
      def initialize(max_size = 100, ttl = 300)
        @cache = {}
        @max_size = max_size
        @ttl = ttl
        @hits = 0
        @misses = 0
      end

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

      def set(key, value)
        cleanup if @cache.size >= @max_size
        @cache[key] = { value: value, timestamp: Time.now }
        @misses += 1
        value
      end

      def invalidate(key)
        @cache.delete(key)
        nil
      end

      def clear
        @cache = {}
      end
      
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
      
      def hit_rate
        total = @hits + @misses
        return 0.0 if total.zero?
        (@hits.to_f / total) * 100
      end

      private

      def cleanup
        # Remove expired entries first
        @cache.delete_if { |_, v| Time.now - v[:timestamp] > @ttl }

        # If still too large, remove oldest entries
        if @cache.size >= @max_size
          sorted_keys = @cache.sort_by { |_, v| v[:timestamp] }.map(&:first)
          sorted_keys.first(@cache.size - @max_size / 2).each { |k| @cache.delete(k) }
        end
        
        nil
      end
    end

    # Batch processing for Git operations
    class BatchProcessor
      attr_reader :batch_size, :total_processed, :batch_count
      
      def initialize(batch_size = 100)
        @batch_size = batch_size
        @total_processed = 0
        @batch_count = 0
      end

      def process_files(files, batch_size = nil, &block)
        size = batch_size || @batch_size
        results = []
        
        files.each_slice(size).each do |batch|
          @batch_count += 1
          batch_result = block.call(batch)
          @total_processed += batch.size
          results.concat(Array(batch_result))
        end
        
        results
      end
      
      def stats
        {
          batch_size: @batch_size,
          total_processed: @total_processed,
          batch_count: @batch_count,
          average_batch_size: average_batch_size
        }
      end
      
      def average_batch_size
        return 0.0 if @batch_count.zero?
        @total_processed.to_f / @batch_count
      end
    end

    # Helper for parallel processing where appropriate
    class ParallelHelper
      def self.available?
        @available ||= begin
          require 'parallel'
          true
        rescue LoadError
          false
        end
      end

      def self.process(items, options = {}, &block)
        threshold = options.delete(:threshold) || 10
        workers = options.delete(:workers) || processor_count
        
        if available? && items.size > threshold
          require 'parallel'
          Parallel.map(items, { in_processes: workers }.merge(options), &block)
        else
          items.map(&block)
        end
      end
      
      def self.processor_count
        if defined?(Etc) && Etc.respond_to?(:nprocessors)
          Etc.nprocessors
        else
          2
        end
      end
    end

    # Performance monitoring and reporting
    class Monitor
      def initialize
        @timings = {}
        @counts = {}
      end

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

      def report
        @timings.sort_by { |_, v| -v }.map do |k, v|
          count = @counts[k]
          avg = count > 0 ? v / count : 0
          "#{k}: #{v.round(3)}s total, #{count} calls, #{avg.round(3)}s avg"
        end
      end
      
      def reset
        @timings.clear
        @counts.clear
        nil
      end
    end
    
    # Benchmarking utility for snakommit operations
    class Benchmark
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
      def self.usage
        case RbConfig::CONFIG['host_os']
        when /linux/, /darwin/
          `ps -o rss= -p #{Process.pid}`.to_i
        else
          0
        end
      end
      
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