# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = github.pr_title.include? "#trivial"

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "WIP"

# Warn when there is a big PR
warn("Big PR") if git.lines_of_code > 500

# Don't let testing shortcuts get into master by accident
fail("focus: true is left in test") if `git diff #{github.base_commit} spec/ | grep ':focus => true'`.length > 1

if git.modified_files.grep(/lib\/caseflow\/version.rb/).empty?
  fail("Please bump the `lib/caseflow/version.rb` version")
end
