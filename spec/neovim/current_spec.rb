require "helper"

module Neovim
  RSpec.describe Current do
    let(:client) { Neovim.attach_child(Support.child_argv) }
    let(:current) { client.current }
    after { client.shutdown }

    describe "#line" do
      it "returns an empty string if the current line is empty" do
        expect(current.line).to eq("")
      end

      it "returns the contents of the line" do
        current.line = "New content"
        expect(current.line).to eq("New content")
      end
    end

    describe "#line=" do
      it "sets the content of the current line" do
        current.line = "New content"
        expect(current.line).to eq("New content")
      end
    end

    describe "#buffer" do
      it "returns the current buffer" do
        expect(current.buffer).to be_a(Buffer)
      end
    end

    describe "#buffer=" do
      it "sets the current buffer from an integer" do
        initial_index = current.buffer.index
        client.command("vnew")

        expect {
          current.buffer = initial_index
        }.to change { current.buffer.index }.to(initial_index)
      end

      it "sets the current buffer from a Buffer" do
        b0 = current.buffer
        client.command("vnew")
        b1 = current.buffer

        expect {
          current.buffer = b0
        }.to change { current.buffer }.from(b1).to(b0)
      end

      it "returns an integer" do
        index = current.buffer.index
        expect(current.buffer = index).to eq(index)
      end

      it "returns a Buffer" do
        buffer = current.buffer
        expect(current.buffer = buffer).to eq(buffer)
      end
    end

    describe "#window" do
      it "returns the current window" do
        expect(current.window).to be_a(Window)
      end
    end

    describe "#window=" do
      it "sets the current window from an integer" do
        client.command("vsp")
        expect(current.window.index).not_to eq(1)

        expect {
          current.window = 1
        }.to change { current.window.index }.to(1)
      end

      it "sets the current window from a Window" do
        w0 = current.window
        client.command("vsp")
        w1 = current.window

        expect {
          current.window = w0
        }.to change { current.window }.from(w1).to(w0)
      end

      it "returns an integer" do
        index = current.window.index
        expect(current.window = index).to eq(index)
      end

      it "returns a Window" do
        w0 = current.window
        expect(current.window = w0).to eq(w0)
      end
    end

    describe "#tabpage" do
      it "returns the current tabpage" do
        expect(current.tabpage).to be_a(Tabpage)
      end
    end

    describe "#tabpage=" do
      it "sets the current tabpage from an integer" do
        initial_index = current.tabpage.index
        client.command("tabnew")
        expect(current.tabpage.index).not_to eq(initial_index)

        expect {
          current.tabpage = initial_index
        }.to change { current.tabpage.index }.to(initial_index)
      end

      it "sets the current tabpage from a Tabpage" do
        tp0 = current.tabpage
        client.command("tabnew")
        tp1 = current.tabpage

        expect {
          current.tabpage = tp0
        }.to change { current.tabpage }.from(tp1).to(tp0)
      end

      it "returns an integer" do
        index = current.tabpage.index
        expect(current.tabpage = index).to eq(index)
      end

      it "returns a Tabpage" do
        tp0 = current.tabpage
        expect(current.tabpage = tp0).to eq(tp0)
      end
    end

    describe "#range=" do
      it "sets the line range of the current buffer" do
        current.buffer.lines = ["one", "two", "three", "four"]
        current.range = (1..2)
        expect(current.buffer.range.to_a).to eq(["two", "three"])
      end
    end
  end
end
