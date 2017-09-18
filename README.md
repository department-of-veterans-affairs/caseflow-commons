# Caseflow

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/caseflow`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'caseflow'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install caseflow

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/department-of-veterans-affairs/caseflow-commons.

## Feature Toggle

To enable and disable features using `rails c`. Example usage:

```
# users
user1 = User.new(regional_office: "RO03")
user2 = User.new(regional_office: "RO04")

# enable for everyone
FeatureToggle.enable!(:apple)
=> true
FeatureToggle.enabled?(:apple, user1)
=> true

# enable for a list of regional offices
FeatureToggle.enable!(:apple, regional_offices: ["RO03", "RO08"])
=> true

# add more regional offices to the same feature
FeatureToggle.enable!(:apple, regional_offices: ["RO03", "RO09"])
=> true

# view the details
FeatureToggle.details_for(:apple)
=> { :regional_offices => ["RO03", "RO08", "RO09"] }

# check if the feature is enabled for a given user
FeatureToggle.enabled?(:apple, user1)
=> true
FeatureToggle.enabled?(:apple, user2)
=> false

# disable a few regional offices
FeatureToggle.disable!(:apple, regional_offices: ["RO03", "RO09"])
=> true
FeatureToggle.details_for(:apple)
=> { :regional_offices =>["RO08"] }
```

## Functions

Functions module is used to grant and deny user permissions/roles. Example usage:

```
# Add a role to the list of users and overwrite the list before
# Caution: Empty array will remove all users who were granted the function.
Functions.grant!("Reader", users: ["CSS_ID_1", "CSS_ID_2"])
=> true

# Deny a role
Functions.deny!("Reader", users: ["CSS_ID_1"])
=> true

# Method to check if a given function is granted for a user
 Functions.granted?("Reader", "CSS_ID_1")
=> false

# Method to check if a given function is denied to a user
 Functions.denied?("Reader", "CSS_ID_1")
=> true

# Returns a hash result for a given function
Functions.details_for("Reader")
=> {:granted=>["CSS_ID_2"], :denied=>["CSS_ID_1"]}

# Returns a hash result for all functions with granted and denied users
Functions.list_all
=> {"Reader"=>{:granted=>["CSS_ID_2"], :denied=>["CSS_ID_1"]}}
```
