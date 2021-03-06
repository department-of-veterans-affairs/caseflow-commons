# frozen_string_literal: true

require "open3"
require "rainbow"

desc "shortcut to run all linting tools, at the same time."
task :lint do
  opts = ENV["CI"] ? "" : "--auto-correct"
  cmd = "bundle exec rubocop #{opts} --color"
  puts "running #{cmd}"
  rubocop_result = ShellCommand.run(cmd)
  puts "rubocop output: #{rubocop_result.inspect}"
  if rubocop_result
    puts Rainbow("Passed. Everything looks stylish!").green
  else
    puts Rainbow("Failed. Linting issues were found.").red
    exit!(1)
  end
end
