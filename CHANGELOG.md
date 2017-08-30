## v0.4.1

* Use tracing matchers in tests [#19](https://github.com/iaintshine/ruby-rails-tracer/pull/19)

## v0.4.0

* Start maintaining CHANGELOG.md [#18](https://github.com/iaintshine/ruby-rails-tracer/pull/18)
* Auto enable tracing-logger when Dalli is auto-instrumented [#17](https://github.com/iaintshine/ruby-rails-tracer/pull/17)
* Introduce Dalli and ActiveSupport::Cache::DalliStore auto-instrumentation [#9](https://github.com/iaintshine/ruby-rails-tracer/pull/9)
* Introduce docker-compose with all required external dependencies. 

## v0.3.0

* Introduce ActiveSupport::Cache auto-instrumentation [#4](https://github.com/iaintshine/ruby-rails-tracer/pull/4)
* Add ActiveRecord::Tracer tests for active span propagation

## v0.2.0

* Introduce ActiveRecord auto-instrumentation [#3](https://github.com/iaintshine/ruby-rails-tracer/pull/3)
* Add Rails test application to be used in specs

## v0.1.1

* Replace RecordingTracer with Test::Tracer [#6](https://github.com/iaintshine/ruby-rails-tracer/pull/6)
* README typo fix [#2](https://github.com/iaintshine/ruby-rails-tracer/pull/2) 

## v0.1.0

* Initial release
* Introduced a rack middleware, to generate more informative operation names based on information supplied by ActionDispatch. [#1](https://github.com/iaintshine/ruby-rails-tracer/pull/1)
