module Support
  class << self
    attr_accessor :nvim_version
  end

  def self.workspace
    File.expand_path("workspace", __dir__)
  end

  def self.socket_path
    file_path("nvim.sock")
  end

  def self.tcp_port
    server = TCPServer.new("127.0.0.1", 0)

    begin
      server.addr[1]
    ensure
      server.close
    end
  end

  def self.file_path(name)
    File.join(workspace, name)
  end

  def self.setup_workspace
    FileUtils.mkdir_p(workspace)
  end

  def self.teardown_workspace
    FileUtils.rm_rf(workspace)
  end

  def self.child_argv
    [Neovim.executable.path, "--headless", "-i", "NONE", "-u", "NONE", "-n"]
  end

  def self.windows?
    Gem.win_platform?
  end

  def self.kill(pid)
    windows? ? Process.kill(:KILL, pid) : Process.kill(:TERM, pid)
  end

  module Matchers
    extend RSpec::Matchers::DSL

    matcher :make_readable do |rd_io|
      rd_io = rd_io.to_io

      match do |block|
        block = block.to_proc

        begin
          expect(IO.select([rd_io], nil, nil, 0.01)).to eq(nil),
            "#{rd_io.inspect} was already readable before calling the block."

          block.call

          expect(IO.select([rd_io], nil, nil, 0.01)).to eq([[rd_io], [], []]),
            "Expected #{rd_io.inspect} to become readable but it didn't."
        rescue RSpec::Expectations::ExpectationNotMetError => e
          @failure_message = e.message
          false
        end
      end

      match_when_negated do
        raise NotImplementedError,
          "Negated matcher not implemented for :make_readable"
      end

      failure_message { @failure_message }

      supports_block_expectations
    end

    matcher :have_packed_messages do |*messages|
      match do |rd_io|
        rd_io = rd_io.to_io

        begin
          IO.select([rd_io], nil, nil, 0.01) ||
            raise("#{rd_io.inspect} is not readable.")

          expect do |block|
            MessagePack::Unpacker.new
              .feed_each(rd_io.read_nonblock(1024 * 16), &block)
          end.to yield_successive_args(*messages)
        rescue RuntimeError, RSpec::Expectations::ExpectationNotMetError => e
          @failure_message = e.message
          false
        end
      end

      match_when_negated do
        raise NotImplementedError,
          "Negated matcher not implemented for :have_packed_messages"
      end

      failure_message { @failure_message }
    end
  end

  begin
    self.nvim_version = Neovim.executable.version
  rescue => e
    abort("Failed to load nvim: #{e}")
  end
end
