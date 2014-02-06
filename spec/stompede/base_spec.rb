class TestApp
  class MooError < StandardError; end

  def initialize(latch, error: nil)
    @latch = latch
    @error = Array(error)
  end

  [:on_open, :on_connect, :on_subscribe, :on_send, :on_unsubscribe, :on_disconnect, :on_close].each do |m|
    define_method(m) do |*args|
      @latch.push([m, *args])
      raise MooError, "MOOOO!" if @error.include?(m)
    end
  end
end

describe Stompede::Base do
  let(:app) { TestApp.new(latch) }
  let(:sockets) { UNIXSocket.pair }
  let(:client_io) { sockets[0] }
  let(:server_io) { Celluloid::IO::UNIXSocket.new(sockets[1]) }

  describe "#on_open" do
    it "is called when a socket is opened" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      session = latch.receive(:on_open).first
      session.should be_an_instance_of(Stompede::Session)
    end
  end

  describe "#on_close" do
    it "is called when a socket is closed" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      client_io.close

      session = latch.receive(:on_close).first
      session.should be_an_instance_of(Stompede::Session)
      connector.should be_alive
    end

    it "is called even when app throws an error" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: :on_open))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      session = latch.receive(:on_close).first
      session.should be_an_instance_of(Stompede::Session)

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end

    it "closes socket even when on_close dies" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: [:on_open, :on_close]))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      session = latch.receive(:on_close).first
      session.should be_an_instance_of(Stompede::Session)

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_connect" do
    it "is called when a client sends a CONNECT frame" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "CONNECT", "foo" => "Bar")

      session, message = latch.receive(:on_connect)
      session.should be_an_instance_of(Stompede::Session)
      message["foo"].should eq("Bar")
    end

    it "replies with a CONNECTED frame when the handler succeeds" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "CONNECT", "foo" => "Bar")
      message = parse_message(client_io)
      message.command.should eq("CONNECTED")
      message["version"].should eq("1.2")
      message["server"].should eq("Stompede/#{Stompede::VERSION}")
      message["session"].should match(/\A[a-f0-9\-]{36}\z/)
    end

    it "replies with an ERROR frame when the handler fails" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: :on_connect))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      send_message(client_io, "CONNECT", "foo" => "Bar")
      message = parse_message(client_io)
      message.command.should eq("ERROR")
      message["version"].should eq("1.2")
      message["content-type"].should eq("text/plain")
      message.body.should match("MooError: MOOOO!")

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_disconnect" do
    it "is called when a client sends a DISCONNECT frame" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "DISCONNECT", "foo" => "Bar")

      session, frame = latch.receive(:on_disconnect)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "is not called when a socket is closed" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      client_io.close

      latch.invocations_until(:on_close).should_not include(:on_disconnect)
      connector.should be_alive
    end

    it "is not called when app throws an error" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: :on_open))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      latch.invocations_until(:on_close).should_not include(:on_disconnect)

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_send" do
    it "is called when a client sends a SEND frame" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")

      session, frame = latch.receive(:on_send)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: :on_send))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_subscribe" do
    it "is called when a client sends a SUBSCRIBE frame" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      session, subscription, frame = latch.receive(:on_subscribe)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: :on_subscribe))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end

    it "replies with an error if subscription does not include a destination" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "SUBSCRIBE", "id" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_close])

      message = parse_message(client_io)
      message.command.should eq("ERROR")
      message["content-type"].should eq("text/plain")
      message.body.should match("Stompede::ClientError: subscription does not include a destination")

      connector.should be_alive
      client_io.should be_eof
    end

    it "replies with an error if subscription does not include an id" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "SUBSCRIBE", "destination" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_close])

      message = parse_message(client_io)
      message.command.should eq("ERROR")
      message["content-type"].should eq("text/plain")
      message.body.should match("Stompede::ClientError: subscription does not include an id")

      connector.should be_alive
      client_io.should be_eof
    end

    it "replies with an error if a subscription with the same id already exists" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "SUBSCRIBE", "destination" => "1", "id" => "1")
      send_message(client_io, "SUBSCRIBE", "destination" => "2", "id" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_subscribe, :on_close])

      message = parse_message(client_io)
      message.command.should eq("ERROR")
      message["content-type"].should eq("text/plain")
      message.body.should match("Stompede::ClientError: subscription with id \"1\" already exists")

      connector.should be_alive
      client_io.should be_eof
    end
  end

  describe "#on_unsubscribe" do
    it "is called when a client sends an unsubscribe frame" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      send_message(client_io, "UNSUBSCRIBE", "Hello", "foo" => "Bar")

      session, subscription, frame = latch.receive(:on_unsubscribe)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error" do
      connector = Stompede::Connector.new(TestApp.new(latch, error: :on_unsubscribe))
      monitor = CrashMonitor.new(connector)
      connector.async.open(server_io)

      send_message(client_io, "UNSUBSCRIBE", "Hello", "foo" => "Bar")

      expect { monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end

    it "replies with an error if subscription does not include an id"
    it "replies with an error if a subscription with the same id does not exist"
    it "is called if the session has a subscription and the socket is closed"
    it "WHAT if the session has a subscription and the app dies"
  end
end
