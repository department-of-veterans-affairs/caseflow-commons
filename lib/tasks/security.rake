# frozen_string_literal: true

require "open3"
require "rainbow"
require "yaml"
require_relative "support/shell_command"

desc "shortcut to run all linting tools, at the same time."
task security: :environment do
  puts "running Brakeman security scan..."
  brakeman_result = ShellCommand.run(
    "brakeman --exit-on-warn --run-all-checks --confidence-level=2"
  )

  puts "running bundle-audit to check for insecure dependencies..."
  unless ShellCommand.run("bundle-audit update")
    puts Rainbow("Bundle Audit failed.").red
    exit!(1)
  end

  snoozed_cves = []
  security_yml = File.expand_path("../../.security.yml", __dir__)
  if defined? Rails
    security_yml = Rails.root.join(".security.yml")
  end

  puts "Looking for #{security_yml}"

  if File.exist?(security_yml)
    puts "Reading #{security_yml} config"
    security_config = YAML.load_file(security_yml)
    security_config["CVES"].each do |cve, ignore_until|
      puts "cve #{cve} ignore_until #{ignore_until}"
      snoozed_cves << { cve_name: cve, until: ignore_until }
    end
  end

  alerting_cves = snoozed_cves
    .select { |cve| cve[:until] >= Time.now.utc.to_date }
    .map { |cve| cve[:cve_name] }

  audit_cmd = "bundle-audit check --ignore=#{alerting_cves.join(' ')}"

  puts audit_cmd

  audit_result = ShellCommand.run(audit_cmd)

  puts "\n"
  if brakeman_result && audit_result
    puts Rainbow("Passed. No obvious security vulnerabilities.").green
  else
    puts Rainbow(
      "Failed. Security vulnerabilities were found. Find the dependency in Gemfile.lock,\n"\
      "then specify a safe version of the dependency in the Gemfile (preferred) or\n"\
      "snooze the CVE in .security.yml for a week."
    ).red
    exit!(1)
  end
end
