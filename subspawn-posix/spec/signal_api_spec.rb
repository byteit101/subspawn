# frozen_string_literal: true

RSpec.describe SubSpawn::POSIX::SigSet do
	let(:set) {SubSpawn::POSIX::Internal::SignalFn}
	let(:ss) {SubSpawn::POSIX::SigSet}

	SIG_SETMASK = 2 # usually

	def extract_array(ptr)
		16.times.map do |i| # maybe more, we don't care
			SubSpawn::POSIX::Internal::SignalFn.ismember(ptr, i+1)
		end
	end

	it "supports empty" do
		expect(ss.empty).not_to be nil
		expect(extract_array(ss.empty)).to eq([0]*16)
	end

	it "supports full" do
		expect(ss.full).not_to be nil
		expect(extract_array(ss.full)).to eq([1]*16)
	end

	it "support current" do
		expect(ss.current).not_to be nil
		expect(extract_array(ss.current)).to eq([0]*16)
		expect((ss.current + 10).to_ptr {|p| set.mask(SIG_SETMASK, p, nil)}).to eq 0
		expect(extract_array(ss.current)).to eq([0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0])
		expect((ss.current - 10).to_ptr {|p| set.mask(SIG_SETMASK, p, nil)}).to eq 0
		expect(extract_array(ss.current)).to eq([0]*16)
	end
	USR1 = 10

	it "supports addition and removal" do
		expect(extract_array(ss.empty.include(10))).to eq([0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0])
		expect(extract_array(ss.full.exclude(10))).to  eq([1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1])
		expect(extract_array(ss.empty.include(10).exclude(10))).to eq([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
		expect(extract_array(ss.full.exclude(10).include(10))).to  eq([1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1])
		expect(extract_array(ss.empty.include(8,9,10,11,12,13).exclude(10))).to eq([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0])
		expect(extract_array(ss.full.exclude([13,12,11,10,9,8]).include(10))).to  eq([1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1])
	end

end
