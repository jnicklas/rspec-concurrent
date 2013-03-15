require "rspec"
require "celluloid"

require "rspec/concurrent/version"

module Rspec
  module Concurrent
    class ExampleRunner
      include Celluloid

      def run_example(group, example, reporter)
        instance = group.new
        group.set_ivars(instance, group.before_all_ivars)
        succeeded = example.run(instance, reporter)
        RSpec.wants_to_quit = true if group.fail_fast? && !succeeded
        succeeded
      end
    end

    POOL = ExampleRunner.pool(:size => 8)

    class CommandLine
      def initialize(options, configuration=RSpec::configuration, world=RSpec::world)
        if Array === options
          options = ConfigurationOptions.new(options)
          options.parse_options
        end
        @options       = options
        @configuration = configuration
        @world         = world
      end

      # Configures and runs a suite
      #
      # @param [IO] err
      # @param [IO] out
      def run(err, out)
        @configuration.error_stream = err
        @configuration.output_stream ||= out
        @options.configure(@configuration)
        @configuration.load_spec_files
        @world.announce_filters

        @configuration.reporter.report(@world.example_count, @configuration.randomize? ? @configuration.seed : nil) do |reporter|
          begin
            @configuration.run_hook(:before, :suite)
            @world.example_groups.ordered.map do |g|
              run_group(g, reporter).map(&:value).all?
            end.all? ? 0 : @configuration.failure_exit_code
          ensure
            @configuration.run_hook(:after, :suite)
          end
        end
      end

      def run_group(group, reporter)
        if RSpec.wants_to_quit
          RSpec.clear_remaining_example_groups if top_level?
          return
        end
        reporter.example_group_started(group)

        begin
          group.run_before_all_hooks(group.new)
          result_for_this_group = run_examples(group, reporter)
          results_for_descendants = group.children.ordered.map do |child|
            run_group(child, reporter)
          end.flatten
          result_for_this_group + results_for_descendants
        rescue Exception => ex
          RSpec.wants_to_quit = true if group.fail_fast?
          group.fail_filtered_examples(ex, reporter)
        ensure
          group.run_after_all_hooks(group.new)
          group.before_all_ivars.clear
          reporter.example_group_finished(group)
        end
      end

      def run_examples(group, reporter)
        group.filtered_examples.ordered.map do |example|
          next if RSpec.wants_to_quit
          POOL.future.run_example(group.clone, example.clone, reporter.clone)
        end
      end
    end

    class Runner
      def self.trap_interrupt
        trap('INT') do
          exit!(1) if RSpec.wants_to_quit
          RSpec.wants_to_quit = true
          STDERR.puts "\nExiting... Interrupt again to exit immediately."
        end
      end

      # Run a suite of RSpec examples.
      #
      # This is used internally by RSpec to run a suite, but is available
      # for use by any other automation tool.
      #
      # If you want to run this multiple times in the same process, and you
      # want files like spec_helper.rb to be reloaded, be sure to load `load`
      # instead of `require`.
      #
      # #### Parameters
      # * +args+ - an array of command-line-supported arguments
      # * +err+ - error stream (Default: $stderr)
      # * +out+ - output stream (Default: $stdout)
      #
      # #### Returns
      # * +Fixnum+ - exit status code (0/1)
      def self.run(args, err=$stderr, out=$stdout)
        trap_interrupt
        options = RSpec::Core::ConfigurationOptions.new(args)
        options.parse_options

        if options.options[:drb]
          require 'rspec/core/drb_command_line'
          begin
            DRbCommandLine.new(options).run(err, out)
          rescue DRb::DRbConnError
            err.puts "No DRb server is running. Running in local process instead ..."
            CommandLine.new(options).run(err, out)
          end
        else
          CommandLine.new(options).run(err, out)
        end
      ensure
        RSpec.reset
      end
    end
  end
end
