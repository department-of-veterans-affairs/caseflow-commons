# frozen_string_literal: true

desc "Runs the continuous integration scripts"
task ci: [:spec, :security, :lint]

task default: :ci
