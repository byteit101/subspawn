# frozen_string_literal: true
G = SubSpawn::FdSource

class Dummy
  def to a
  end
end
class SubSpawn::Platform
  def self.new(*args)
    $rs_stub.new_init(*args)
  end
end
RSpec.describe SubSpawn do
  it "has a version number" do
    expect(SubSpawn::VERSION).not_to be nil
    expect(SubSpawn::Platform::VERSION).not_to be nil
  end
  def nexpect thing
    Dummy.new
  end
   #TODO: more tests, particulary for the graph

  it "finds cycles" do
    expect(SubSpawn.graph_order([
      G::Basic.new([0],1),
      G::Basic.new([1],0),
    ]).map(&:to_dbg)).to eq [
      [[3], 0],
      [[0], 1],
      [[1], 3],
      [:close, [3]]
    ]
  end
  it "finds multi cycles" do
    expect(SubSpawn.graph_order([
      G::Basic.new([0],1),
      G::Basic.new([1],2),
      G::Basic.new([2],0),
    ]).map(&:to_dbg)).to eq [
      [[3], 0],
      [[0], 1],
      [[1], 2],
      [[2], 3],
      [:close, [3]]
    ]
  end
  it "finds no cycles" do
    expect(SubSpawn.graph_order([
      G::Basic.new([1],0),
      G::Basic.new([2],1)
    ]).map(&:to_dbg)).to eq [
      [[2], 1],
      [[1], 0]
    ]
  end
  it "finds no cycles rev" do
    expect(SubSpawn.graph_order([
      G::Basic.new([2],1),
      G::Basic.new([1],0),
    ]).map(&:to_dbg)).to eq [
      [[2], 1],
      [[1], 0],
    ]
  end
  it "finds nothing" do
    expect(SubSpawn.graph_order([
      G::Basic.new([1],0),
      G::Basic.new([2],3)
    ]).map(&:to_dbg)).to eq [
      [[2], 3],
      [[1], 0],
    ]
  end
   #TODO: add double and triple circle, plus zig-zag and corona-loop
  LSBIN=  "ls"
  context "spawn call" do
    let(:o) { instance_double(SubSpawn::POSIX)}
    let(:d) { $rs_stub = double() }

    it "basic" do
      expect(d).to receive(:new_init).with(LSBIN, "b", "c", arg0: "ls").and_return(o)
      expect(o).to receive(:spawn!)
      SubSpawn.spawn("ls", "b", "c")
    end
    it "basic2" do
      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect(o).to receive(:spawn!)
      SubSpawn.spawn("ls")
    end
    it "basic2" do
      expect(d).to receive(:new_init).with(LSBIN, arg0: "lsa").and_return(o)
      expect(o).to receive(:spawn!)
      SubSpawn.spawn(["ls", "lsa"])

      expect(d).to receive(:new_init).with(LSBIN, "yes", arg0: "lsa").and_return(o)
      expect(o).to receive(:spawn!)
      SubSpawn.spawn(["ls", "lsa"], "yes")
    end

    it "env" do
      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect(o).to receive(:spawn!)
      expect(o).to receive(:env=).with({"yes" => "foo1"})
      SubSpawn.spawn({"yes" => "foo1"}, "ls", {unsetenv_others: true})

      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect(o).to receive(:spawn!)
      expect(o).to receive(:env=).with({"yes" => "foo2"})
      SubSpawn.spawn({"yes" => "foo2"}, "ls", unsetenv_others: true)

      expect(d).to receive(:new_init).with(LSBIN, "yes", arg0: "ls").and_return(o)
      expect(o).to receive(:spawn!)
      expect(o).to receive(:env=).with({"yes" => "foo"})
      SubSpawn.spawn({"yes" => "foo"}, "ls", "yes", unsetenv_others: true)
    end
    it "wrong" do
      expect { SubSpawn.spawn({"yes" => "foo"}, ["ls"])}.to raise_error(ArgumentError)
      expect { SubSpawn.spawn({"yes" => "foo"}, ["ls", "x", "y"])}.to raise_error(ArgumentError)
    end

    it "wrongmuti" do
      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect { SubSpawn.spawn("ls", in: 9, 0 => 12)}.to raise_error(ArgumentError)

      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect { SubSpawn.spawn("ls", in: 9, [3,0]=> 12)}.to raise_error(ArgumentError)


      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect { SubSpawn.spawn("ls", [1,:in]=> 9, [3,0]=> 12)}.to raise_error(ArgumentError)

      expect(d).to receive(:new_init).with(LSBIN, arg0: "ls").and_return(o)
      expect { SubSpawn.spawn("ls", [1,:in]=> 9, [3,0]=> [:child, 1])}.to raise_error(ArgumentError)
    end
  end
  # TODO: tset child redirects
end
