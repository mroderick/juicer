#!/usr/bin/env ruby
['base', '../dependency_resolver/javascript_dependency_resolver'].each do |lib|
  require File.expand_path(File.join(File.dirname(__FILE__), lib))
end

module Juicer
  module Merger
    # Merge several files into one single output file. Resolves and adds in files from @depend comments
    class JavaScriptMerger < Base

      # Constructor
      def initialize(files = [], options = {})
        @dependency_resolver = JavaScriptDependencyResolver.new
        super(files, options)
      end
    end
  end
end

# Run file from command line
# TODO: Refactor to testable Juicer::Merger::JavaScript::FileMerger.cli method
# or similar.
#
if $0 == __FILE__
  puts("Usage: javascript_merger.rb file[...] output") and exit if $*.length < 2

  fm = JavaScriptMerger.new()
  fm << $*[0..-2]
  fm.save($*[-1])
end
