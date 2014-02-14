module Stompede
  class Session
    def initialize(connector)
      @connector = connector
      @subscriptions = {}
      @mutex = Mutex.new
    end

    def subscriptions
      @mutex.synchronize { @subscriptions.values }
    end

    def write(value)
      @connector.write(self, value.to_str)
    end

    def write_and_wait_for_ack(message, timeout)
      @connector.write_and_wait_for_ack(self, message, timeout)
    end

    def error(exception, headers = {})
      safe_write(ErrorFrame.new(exception, headers))
      close
    end

    def safe_write(value)
      write(value)
    rescue Disconnected
    end

    def close
      @connector.close(self)
    end

    def subscribe(frame)
      subscription = Subscription.new(self, frame)
      @mutex.synchronize do
        if @subscriptions[subscription.id]
          raise ClientError, "subscription with id #{subscription.id.inspect} already exists"
        end
        @subscriptions[subscription.id] = subscription
      end
      subscription
    end

    def unsubscribe(frame)
      subscription = Subscription.new(self, frame)
      @mutex.synchronize do
        unless @subscriptions[subscription.id]
          raise ClientError, "subscription with id #{subscription.id.inspect} does not exist"
        end
        @subscriptions.delete(subscription.id)
      end
    end

    def inspect
      "#<Stompede::Session #{object_id}>"
    end
  end
end
