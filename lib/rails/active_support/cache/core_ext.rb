module ActiveSupport
  module Cache
    class Store
      # See the PR https://github.com/rails/rails/pull/15943/files
      # In order to make the instrumentation to work we need to override the original implementation
      def self.instrument
        true
      end
    end
  end
end
