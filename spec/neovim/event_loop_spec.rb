require "helper"

module Neovim
  RSpec.describe EventLoop do
    let!(:push_pipe) { IO.pipe }
    let!(:pull_pipe) { IO.pipe }

    let(:client_rd) { push_pipe[0] }
    let(:client_wr) { pull_pipe[1] }
    let(:server_rd) { pull_pipe[0] }
    let(:server_wr) { push_pipe[1] }

    let(:connection) { Connection.new(client_rd, client_wr) }
    let(:event_loop) { EventLoop.new(connection) }

    describe "#request" do
      it "writes a msgpack request" do
        event_loop.request(1, :method, 1, 2)
        message = server_rd.readpartial(1024)
        expect(message).to eq(MessagePack.pack([0, 1, "method", [1, 2]]))
      end

      it "buffers a request" do
        event_loop.request(1, :method, 1, 2, flush: false)

        expect do
          event_loop.request(2, :method, 3, 4)
        end.to make_readable(server_rd)

        expect(server_rd).to have_packed_messages(
          [0, 1, "method", [1, 2]],
          [0, 2, "method", [3, 4]],
        )
      end
    end

    describe "#respond" do
      it "writes a msgpack response" do
        event_loop.respond(2, "value", "error")
        message = server_rd.readpartial(1024)
        expect(message).to eq(MessagePack.pack([1, 2, "error", "value"]))
      end

      it "buffers a response" do
        event_loop.respond(2, "value", "error", flush: false)

        expect do
          event_loop.respond(3, "another value", "another error")
        end.to make_readable(server_rd)

        expect(server_rd).to have_packed_messages(
          [1, 2, "error", "value"],
          [1, 3, "another error", "another value"],
        )
      end
    end

    describe "#notify" do
      it "writes a msgpack notification" do
        event_loop.notify(:method, 1, 2)
        message = server_rd.readpartial(1024)
        expect(message).to eq(MessagePack.pack([2, "method", [1, 2]]))
      end

      it "buffers a notification" do
        event_loop.notify(:method, 1, 2, flush: false)

        expect do
          event_loop.notify(:method, 3, 4)
        end.to make_readable(server_rd)

        expect(server_rd).to have_packed_messages(
          [2, "method", [1, 2]],
          [2, "method", [3, 4]],
        )
      end
    end

    describe "#run" do
      it "yields received messages to the block" do
        server_wr.write(MessagePack.pack([0, 1, :foo_method, []]))
        server_wr.flush

        message = nil
        event_loop.run do |req|
          message = req
          event_loop.stop
        end

        expect(message.sync?).to eq(true)
        expect(message.method_name).to eq("foo_method")
      end

      it "shuts down after receiving EOFError" do
        run_thread = Thread.new do
          event_loop.run
        end

        server_wr.close
        run_thread.join
        expect(client_rd).to be_closed
        expect(client_wr).to be_closed
      end
    end
  end
end
