require "helper"

module Neovim
  describe Buffer, :remote => true do
    let(:client) { Client.new("/tmp/neovim.sock") }
    let(:buffer) { Buffer.new(2, client) } # I don't know why it has to be 2

    describe "#length" do
      it "returns the length of the buffer" do
        expect(buffer.length).to eq(1)
      end
    end

    describe "#lines" do
      it "returns an enumerable of strings" do
        expect(buffer.lines.to_a).to eq([""])
      end

      it "allows access to individual lines" do
        buffer.lines[0] = "first line"
        expect(buffer.lines[0]).to eq("first line")
      end

      it "allows access to a range of lines" do
        buffer.lines[0..1] = ["first line", "second line"]
        expect(buffer.lines[0..1]).to eq(["first line", "second line"])
      end

      it "can be mutated" do
        buffer.lines = ["first line", "second line"]
        expect(buffer.lines.to_a).to eq(["first line", "second line"])
      end

      it "can be mutated at an index" do
        buffer.lines[0] = "first line"
        expect(buffer.lines.to_a).to eq(["first line"])
      end

      it "can be deleted at an index" do
        buffer.lines = ["first line", "second line"]
        expect(buffer.lines.delete_at(0)).to eq("first line")
        expect(buffer.lines.to_a).to eq(["second line"])
      end

      it "can be mutated using a slice" do
        buffer.lines = ["first", "second", "third"]
        buffer.lines[0..1] = ["new first", "new second"]
        expect(buffer.lines.to_a).to eq(["new first", "new second", "third"])
      end
    end

    describe "#variable" do
      it "returns a buffer local variable" do
        variable = buffer.variable("test_var")
        expect(variable.name).to eq("test_var")
        expect(variable.value).to be_nil
      end
    end
  end
end
