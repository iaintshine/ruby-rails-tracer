# OpenTracing Rails Instrumentation

This gem is an attempt to introduce OpenTracing instrumentation into Rails. It's in an early stage. 

The following instrumentation is supported:

* ActionDispatch - The library introduces a rack middleware, which is intended to be used together with `rack-tracer`, to generate more informative operation names based on information supplied by ActionDispatch.
* ActiveRecord - The library hooks up into Rails, and instruments all ActiveRecord query. 
* ActionSupport::Cache - The library hooks up into Rails, and instruments cache events.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-tracer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rails-tracer

## Rails::Tracer

The library hooks up into Rails using `ActiveSupport::Notifications`, and instruments all previously mentioned modules. 
To enable instrumentation, you can either use sub-tracers directly (see sections below) or global `Rails::Tracer` which 
will enabled all of them (except for Rack/ActionDispatch instrumentation).

### Configuration Options

* `tracer: OpenTracing::Tracer` an OT compatible tracer. Default `OpenTracing.global_tracer`
* `active_span: boolean` an active span provider. Default: `nil`.
* `active_record: boolean` whether to enable `ActiveRecord` instrumentation. Default: `true`.
* `active_support_cache: boolean` whether to enable `ActionDispatch::Cache` instrumentation. Default: `true`.
  * `dalli: boolean` if set to `true` you will hook up into `Dalli` low-level details. Default: `false`.
* `rack: boolean` whether to enable extended `Rack` instrumentation. Default: `false`.
  * `middlewares: ActionDispatch::MiddlewareStack` a middlewares stack. Default: `Rails.configuration.middleware`.

### Usage

```ruby
require 'rack/tracer'
Rails.configuration.middleware.insert_after(Rails::Rack::Logger, Rack::Tracer)

require 'rails/tracer'
Rails.configuration.middleware.insert_after(Rack::Tracer, Rails::Rack::Tracer)
Rails::Tracer.instrument(active_span: -> { OpenTracing.global_tracer.active_span })
```

## ActionDispatch 

When you use `rack-tracer`, the generated operation name corresponds to the request's http method e.g. GET, POST etc.
It's not perfect. You need to dig into the trace to understand with what url it's related. 

The `rails-tracer` introduces another rack middleware, which is intended to be used together with `rack-tracer`, to generate more informative operation names in the form `ControllerName#action`.

### Usage

```ruby
require 'rack/tracer'
require 'rails/tracer'

Rails.configuration.middleware.use(Rack::Tracer)
Rails.configuration.middleware.insert_after(Rack::Tracer, Rails::Rack::Tracer)
```

or simpler

```ruby
Rails::Rack::Tracer.instrument
```

optionally you can pass `tracer` argument to `instrument` method.

## ActiveRecord

The library hooks up into Rails using `ActiveSupport::Notifications`, and instruments all `ActiveRecord` query. 

### Usage

Auto-instrumentation example. 

```ruby
require 'rails/tracer'

ActiveRecord::Tracer.instrument(tracer: OpenTracing.global_tracer,
                               active_span: -> { OpenTracing.global_tracer.active_span })
```

There are times when you might want to skip ActiveRecord's magic, and use connection directly. Still the library 
can help you with span creation. Instead of auto-instrumenting you can manually call `ActiveRecord::Tracer.start_span` as shown below.

```ruby
def q(name, sql)
  span = ActiveRecord::Tracer.start_span(name, 
                                          tracer: OpenTracing.global_tracer,
                                          active_span: -> { OpenTracing.global_tracer.active_span },
                                          sql: sql)
  ActiveRecord::Base.
    connection.
    raw_connection.
    query(sql).
    each(as: :hash)
ensure
  span&.finish
end

q("FirstUser", "SELECT * FROM users LIMIT 1")
```

## ActiveSupport::Cache

The library hooks up into Rails using `ActiveSupport::Notifications`, and instruments all `ActiveSupport::Cache` events. 

### Usage

Auto-instrumentation example. 

```ruby
require 'rails/tracer'

ActiveSupport::Cache::Tracer.instrument(tracer: OpenTracing.global_tracer, 
                                        active_span: -> { OpenTracing.global_tracer.active_span })
```

If you use [Dalli](https://github.com/petergoldstein/dalli/) and `ActiveSupport::Cache::DalliStore` as your application's cache store, you can get low-level details about Memcached calls by setting `dalli` option to `true`. If you want to get even more details, simply require [tracing-logger](https://github.com/iaintshine/ruby-tracing-logger) and Dalli error logs will be attached to the current active span. The library will wrap current `Dalli.logger` into a `Tracing::CompositeLogger` and append additional `Tracing::Logger` with severity level set to `Logger::ERROR`.

```ruby
ActiveSupport::Cache::Tracer.instrument(tracer: OpenTracing.global_tracer, 
                                        active_span: -> { OpenTracing.global_tracer.active_span },
                                        dalli: true)
```

If you want to skip the auto-instrumentation, still the library can help you with span creation and setting up proper tags. Instead of auto-instrumenting, as shown above, you can manually call `ActiveSupport::Cache::Tracer.start_span` as shown below.

```ruby
def read(key)
  span = ActiveSupport::Cache::Tracer.start_span("InMemoryCache#read", 
                                                 tracer: OpenTracing.global_tracer,
                                                 active_span: -> { OpenTracing.global_tracer.active_span },
                                                 key: key)
  result = in_memory_cache[key]
  span.set_tag('cache.hit', !!result) 
  result
ensure
  span&.finish
end

read("user-1")
```

## Development

After checking out the repo, install dependencies. 

```
bundle install
appraisal install
```

The tests depends on having memcached running locally within docker container. It means you need to install docker, and docker-compose first.
Once you're done to run the containers:

```
docker-compose up -d
```

Then, to run tests for all appraisals: 

```
appraisal bundle exec rspec spec
```

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iaintshine/ruby-rails-tracer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
