module ActiveRecord
  module Tracer
    DEFAULT_OPERATION_NAME = "sql.query".freeze

    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        clear_subscribers
        @subscriber = ::ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          ActiveRecord::Tracer.sql(tracer: tracer, active_span: active_span, args: args)
        end

        self
      end

      def disable
        if @subscriber
          ActiveSupport::Notifications.unsubscribe(@subscriber)
          @subscriber = nil
        end

        self
      end
      alias :clear_subscribers :disable

      def sql(tracer: OpenTracing.global_tracer, active_span: nil, args:)
        event, start, finish, id, payload = *args

        connection_config = ::ActiveRecord::Base.connection_config
        name = payload.fetch(:name)
        tags = {
          'component' => 'ActiveRecord',
          'span.kind' => 'client',
          'db.user' => connection_config.fetch(:username, 'unknown'),
          'db.instance' => connection_config.fetch(:database),
          'db.vendor' => connection_config.fetch(:adapter),
          'db.connection_id' => payload.fetch(:connection_id, 'unknown'),
          'db.cached' => payload.fetch(:cached, false),
          'db.statement' => payload.fetch(:sql),
          'db.type' => 'sql'
        }

        if !Rails::Tracer::Defer.enabled
          span = tracer.start_span(name || DEFAULT_OPERATION_NAME,
                                   child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                   start_time: start,
                                   tags: tags)

          if payload[:exception]
            Rails::Tracer::SpanHelpers.set_error(span, payload[:exception_object] || payload[:exception])
          end

          span.finish(end_time: finish)
        else
          spaninfo = {
            'event' => event,
            'name' => name || DEFAULT_OPERATION_NAME,
            'start' => start,
            'finish' => finish,
            'tags' => tags,
          }

          # errors aren't being propagated yet this way...

          Rails::Tracer::Defer.defer_span(id: id, spaninfo: spaninfo)
        end
      end

      def start_span(operation_name, tracer: OpenTracing.global_tracer, active_span: nil, start_time: Time.now, **fields)
        connection_config = ::ActiveRecord::Base.connection_config

        span = tracer.start_span(operation_name || DEFAULT_OPERATION_NAME,
                                 child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                 start_time: start_time,
                                 tags: {
                                  'component' => 'ActiveRecord',
                                  'span.kind' => 'client',
                                  'db.user' => connection_config.fetch(:username, 'unknown'),
                                  'db.instance' => connection_config.fetch(:database),
                                  'db.vendor' => connection_config.fetch(:adapter),
                                  'db.connection_id' => fields.fetch(:connection_id, 'unknown'),
                                  'db.cached' => fields.fetch(:cached, false),
                                  'db.statement' => fields.fetch(:sql),
                                  'db.type' => 'sql'
                                 })
        span
      end
    end
  end
end
