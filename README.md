# OpenTracing Rails Instrumentation

This gem is an attempt to introduce OpenTracing instrumentation into Rails. It's in a very early stage. 

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

If you use [Dalli](https://github.com/petergoldstein/dalli/) and `ActiveSupport::Cache::DalliStore`, as your application's cache store, you can get low-level details about Memcached calls by setting `dalli` option to `true`.

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iaintshine/ruby-rails-tracer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
