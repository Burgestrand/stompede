module Helpers
  extend RSpec::Matchers::DSL
  extend self

  class Latch
    def initialize
      @queue = Queue.new
    end

    def push(object)
      @queue.push(object)
    end

    def invocations_until(method)
      messages_until(method).map(&:first)
    end

    def receive(method)
      messages_until(method).last.drop(1)
    end

  private

    def messages_until(method)
      Timeout.timeout(0.5) do
        list = []
        loop do
          list.push(@queue.pop)
          break if list.last[0] == method
        end
        list
      end
    rescue Timeout::Error
      raise "Latch timed out!"
    end
  end

  def self.included(rspec)
    rspec.before do
      @_latch = Latch.new
    end
  end

  def latch
    @_latch
  end

  def send_message(io, command, *args)
    headers = if args.last.is_a?(Hash)
      args.pop
    else
      {}
    end
    body = args.shift || ""
    io.write(Stompede::Stomp::Message.new(command, headers, body).to_str)
  end

  def parse_message(io)
    parser = Stompede::Stomp::Parser.new

    Timeout.timeout(0.5) do
      parser.parse(io.readpartial(Stompede::BUFFER_SIZE)) do |message|
        return message
      end
    end
  rescue Timeout::Error
    raise "Parsing message timed out!"
  end

  matcher :receive_error do |klass, body, headers = {}|
    match do |io|
      begin
        message = Helpers.parse_message(io)
        message.command.should eq("ERROR")
        message["content-type"].should eq("text/plain")
        message.body.should =~ Regexp.new(Regexp.quote("#{klass}: #{body}"))
        headers.each do |key, value|
          message[key.to_s].should == value.to_s
        end
        io.should be_eof
      rescue => e
        @error = e
        raise
      end
    end

    failure_message_for_should do
      @error
    end
  end
end

