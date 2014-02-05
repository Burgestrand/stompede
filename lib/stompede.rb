require "celluloid"
require "celluloid/io"

require "stompede/version"

require "stompede/error"
require "stompede/stomp/parser"
require "stompede/stomp/message"

begin
  require "stompede/stomp/parser_native"
rescue LoadError
  # Native parser not available, fall back to pure-ruby implementation.
end

module Stompede
  BUFFER_SIZE = 10 * 1024

  class Session
    def initialize(socket)
      @socket = socket
    end

    def send(message)
      @socket.write(Stomp::Message.new("MESSAGE", {}, message).to_str)
    end
  end

  class Base
    include Celluloid

    def initialize
      @connector = Connector.new_link(self)
    end

    def dispatch(message, session)
    end

    def connect(socket)
      @connector.async.connect(socket)
    end
  end

  class Connector
    include Celluloid::IO

    def initialize(app)
      @app = app
    end

    def connect(socket)
      session = Session.new(socket)

      parser = Stomp::Parser.new

      loop do
        chunk = socket.readpartial(Stompede::BUFFER_SIZE)
        parser.parse(chunk) do |message|
          @app.dispatch(message, session)
        end
      end
    end
  end
end

__END__
Reel::Server::HTTP.supervise("0.0.0.0", 3000) do |connection|
  # Support multiple keep-alive requests per connection
  connection.each_request do |request|
    if request.websocket?
      Stompede.connect(request.websocket, app)
    end
  end
end

server = TCPServer.new do
loop do
  Stompede.connect(server.accept, app)
end
