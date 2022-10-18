# frozen_string_literal: true
G = SubSpawn::Internal::FdSource

RSpec.describe SubSpawn::Internal do
	#TODO: more tests, particulary for the graph

	#TODO: add double and triple circle, plus zig-zag and corona-loop
	 #TODO: more tests, particulary for the graph
	context "graph solver" do

	it "finds cycles" do
		expect(SubSpawn::Internal.graph_order([
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
		expect(SubSpawn::Internal.graph_order([
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
		expect(SubSpawn::Internal.graph_order([
			G::Basic.new([1],0),
			G::Basic.new([2],1)
		]).map(&:to_dbg)).to eq [
			[[2], 1],
			[[1], 0]
		]
	end
	it "finds no cycles rev" do
		expect(SubSpawn::Internal.graph_order([
			G::Basic.new([2],1),
			G::Basic.new([1],0),
		]).map(&:to_dbg)).to eq [
			[[2], 1],
			[[1], 0],
		]
	end
	it "finds nothing" do
		expect(SubSpawn::Internal.graph_order([
			G::Basic.new([1],0),
			G::Basic.new([2],3)
		]).map(&:to_dbg)).to eq [
			[[2], 3],
			[[1], 0],
		]
	end
	# yes, this is kinda dumb, but for now it's a lazy way to clear the close-on-exec flag
	# we could filter this out
	it "self-loops are copied" do
		expect(SubSpawn::Internal.graph_order([
			G::Basic.new([1],1)
		]).map(&:to_dbg)).to eq [
			[[3], 1],
			[[1], 3],
			[:close, [3]],
		]
	end
end
context "usage fds" do
	let(:o) { instance_double(SubSpawn::POSIX)}
	let(:d) { class_double("SubSpawn::Platform").as_stubbed_const() }

end
	 #TODO: add double and triple circle, plus zig-zag and corona-loop
	# TODO: tset child redirects

	# TODO: test self loops (in => in)
end
