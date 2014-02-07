module Stompede
  class Session
    def initialize(socket)
      @mutex = Mutex.new
      @socket = socket
      @subscriptions = {}
    end

    def subscriptions
      @subscriptions.values
    end

    def write(value)
      @mutex.synchronize do
        @socket.write(value.to_str)
      end
    end

    def subscribe(frame)
      subscription = Subscription.new(self, frame)
      subscription.validate!
      if @subscriptions[subscription.id]
        raise ClientError, "subscription with id #{subscription.id.inspect} already exists"
      end
      @subscriptions[subscription.id] = subscription
      subscription
    end

    def unsubscribe(frame)
      subscription = Subscription.new(self, frame)
      subscription.validate!
      unless @subscriptions[subscription.id]
        raise ClientError, "subscription with id #{subscription.id.inspect} does not exist"
      end
      @subscriptions.delete(subscription.id)
    end
  end
end
