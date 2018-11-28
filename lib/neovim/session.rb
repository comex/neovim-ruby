require "neovim/logging"
require "fiber"
require "thread"

module Neovim
  # Wraps an event loop in a synchronous API using +Fiber+s.
  #
  # @api private
  class Session
    include Logging

    attr_writer :request_id

    # @api private
    class Exited < RuntimeError
      def initialize
        super("nvim process exited")
      end
    end

    def initialize(event_loop)
      @event_loop = event_loop
      @main_thread = Thread.current
      @main_fiber = Fiber.current
      @response_handlers = Hash.new(-> {})
      @pending_messages = []
      @request_id = 0
      @flush = true
    end

    def run(&block)
      @running = true

      while (pending = @pending_messages.shift)
        Fiber.new { pending.received(@response_handlers, &block) }.resume
      end

      return unless @running

      @event_loop.run do |message|
        Fiber.new { message.received(@response_handlers, &block) }.resume
      end
    end

    # Make an RPC request and return its response.
    #
    # If this method is called inside a callback, we are already inside a
    # +Fiber+ handler. In that case, we write to the stream and yield the
    # +Fiber+. Once the response is received, resume the +Fiber+ and
    # return the result.
    #
    # If this method is called outside a callback, write to the stream and
    # run the event loop until a response is received. Messages received
    # in the meantime are enqueued to be handled later.
    def request(method, *args)
      main_thread_only do
        @request_id += 1
        blocking = Fiber.current == @main_fiber

        log(:debug) do
          {
            method_name: method,
            request_id: @request_id,
            blocking: blocking,
            arguments: args
          }
        end

        @event_loop.request(@request_id, method, *args)
        response = blocking ? blocking_response : yielding_response

        raise(Exited) if response.nil?
        raise(response.error) if response.error
        response.value
      end
    end

    def respond(request_id, value, error=nil)
      @event_loop.respond(request_id, value, error, flush: @flush)
    end

    def notify(method, *args)
      @event_loop.notify(method, *args, flush: @flush)
    end

    def shutdown
      @running = false
      @event_loop.shutdown
    end

    def stop
      @running = false
      @event_loop.stop
    end

    def batch(&block)
      @flush = false
      block.call
    ensure
      @flush = true
      @event_loop.flush
    end

    private

    def blocking_response
      response = nil

      @response_handlers[@request_id] = lambda do |res|
        response = res
        stop
      end

      run { |message| @pending_messages << message }
      response
    end

    def yielding_response
      fiber = Fiber.current
      @response_handlers[@request_id] = ->(response) { fiber.resume(response) }
      Fiber.yield
    end

    def main_thread_only
      if Thread.current == @main_thread
        yield if block_given?
      else
        raise(
          "A Ruby plugin attempted to call neovim outside of the main thread, " \
          "which is not yet supported by the neovim gem."
        )
      end
    end
  end
end
