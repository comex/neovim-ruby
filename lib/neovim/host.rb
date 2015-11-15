module Neovim
  class Host
    def self.load_from_files(rplugin_paths)
      plugins_before = Neovim.__configured_plugins
      captured_plugins = []

      begin
        Neovim.__configured_plugins = captured_plugins

        rplugin_paths.each do |rplugin_path|
          Kernel.load(rplugin_path, true)
        end

        new(captured_plugins)
      ensure
        Neovim.__configured_plugins = plugins_before
      end
    end

    attr_reader :plugins

    def initialize(plugins)
      @plugins = plugins
      @handlers = compile_handlers(plugins)
    end

    def run
      event_loop = EventLoop.stdio
      msgpack_stream = MsgpackStream.new(event_loop)
      async_session = AsyncSession.new(msgpack_stream)
      session = Session.new(async_session)
      client = Client.new(session)

      notification_callback = Proc.new do |notif|
        @handlers[:notification][notif.method_name].call(client, notif)
      end

      request_callback = Proc.new do |request|
        @handlers[:request][request.method_name].call(client, request)
      end

      async_session.run(request_callback, notification_callback)
    end

    private

    def compile_handlers(plugins)
      base = {
        :request => Hash.new(Proc.new {}),
        :notification => Hash.new(Proc.new {})
      }

      plugins.inject(base) do |handlers, plugin|
        plugin.specs.each do |spec|
          if spec[:sync]
            handlers[:request][spec[:name]] = lambda do |client, request|
              request.respond(spec[:proc].call(client, *request.arguments))
            end
          else
            handlers[:notification][spec[:name]] = lambda do |client, notification|
              spec[:proc].call(client, *notification.arguments)
            end
          end
        end

        handlers
      end
    end
  end
end