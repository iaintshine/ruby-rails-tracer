# OpenTracing Rails Instrumentation

This gem is an attempt to introduce OpenTracing instrumentation into Rails. It's in a very early stage. 

When you use `rack-tracer`, the generated operation name corresponds to the request's http method e.g. GET, POST etc.
It's not perfect. You need to dig into the trace to understand with what url it's related. 

The `rails-tracer` introduces another rack middleware, which is intended to be used together with `rack-tracer`, to generate more informative operation names in the form `ControllerName#action`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-tracer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rails-tracer

## Usage

```ruby
require 'rack/tracer'
require 'rails/tracer'

Rails.configuration.middleware.user(Rack::Tracer)
Rails.configuration.middleware.insert_after(Rack::Tracer, Rails::Rack::Tracer)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iaintshine/ruby-rails-tracer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
