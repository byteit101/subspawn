require 'cast'
#require 'struct'
require 'colorize'

require 'pry'


ENUM_CONST_CODE = <<EOENUM
def self.const_missing( sym )
		value = enum_value( sym )
		return super unless value
		value
	end
EOENUM

IntSizes = {-1 => :short, 0 => :int, 1 => :long}
UIntSizes = {-1 => :ushort, 0 => :uint, 1 => :ulong}

def lookup(name, ast, arg=true)
	
	ast.entities.each do |ent|
		ent.declarators.each do |decl|
			next unless decl.name == name
			if decl.type.Pointer? and decl.type.type.Function?
				return pack({funcptr: name})
			elsif decl.name == "sigset_t"
				return pack({sigset: true})
			elsif ent.type.name == "ffi_t" # raw ffi type
				return pack({ffi_t: decl.name})
			else
				binding.pry
				return :YES
			end
		end
	end
			
end

class PackedInfo
	def initialize(data, string)
		@data, @to_s = data, string
	end
	attr_reader :data, :to_s
end

def error(txt, big=false)
	PackedInfo.new({error: txt}, big ? txt.colorize(background: :red) : txt.colorize(:light_red))
end
def pack(obj)
	PackedInfo.new(obj, obj.inspect)
end

# TODO: make types for  timespec dirent and maybe more?
def type_decode(type, ast, arg=false)
	case type
		when C::Int 
			if type.signed?
				IntSizes[type.longness]
			else # unsigned
				UIntSizes[type.longness]
			end
		when C::Bool then :bool
		when C::Char then type.signed ? :char : :byte
		when C::Float then type.double? ? :double : :float
		when C::Void then :void
		when C::Array
			if type.type.Pointer? and type.type.type.Char?
				:string_array
			elsif type.type.Char?
				pack({type: :fixed_string, length: expr_eval(type.length)})
			elsif type.type.Int?
				:int_array
			else
				"<[]#{type.type.class} []= #{type.to_s}>".colorize(:light_red)
			end
		when C::CustomType
			if type.name == "va_list"
				:va_pointer
			else
				lookup(type.name, ast, arg)
			end
		when C::Enum
			if type.name.start_with? "lfp_"
				pack({enum: type.name})
			else
				"<ENUM: #{type.name}>".colorize(background: :red)
			end
		when C::Struct
			if type.name == "sigset_t"
				pack({sigset: true})
			else
				error("<struct: #{type.name}>")
			end
		when C::Pointer
			tt = type.type
			case tt
			when C::Char
				if tt.const? || !arg
					:string
				else
					:string_buffer
				end
			when C::Bool, C::Float, C::Int
				:out_num # no expand as all pointers in the end
			when C::Pointer
				if tt.type.Char?
					:string_out
				elsif tt.type.Struct?
					if %w{opaque_ptr stat sockaddr msghdr cmsghdr rlimit timespec dirent sigset_t}.include? tt.type.name
						:opaque_ptr_array
					else
						"<*#{tt.type.class} **= #{type.to_s} (#{tt.name})>".colorize(:light_red)
					end
				else
					"<*#{type.type.class} []= #{type.to_s}>".colorize(:light_red)
				end
			when C::Struct
				if %w{opaque_ptr stat sockaddr msghdr cmsghdr rlimit timespec dirent sigset_t}.include? tt.name
					:opaque_ptr
				elsif tt.name.start_with? "lfp_"
					pack({:struct_out=> tt.name})
				else
					error("<*#{type.type.class} S= #{type.to_s}>")
				end
				
			when C::Void
				:void_ptr
			when C::CustomType
				if tt.name.start_with? "lfp_"
					:opaque_ptr
				else
					if lookup(tt.name, ast, arg).is_a? PackedInfo
						:out_num
					else
						error("customct?")
					end
				end
			else
			error("<*#{type.type.class} *= #{type.to_s}>")
			end
		else
			error("<#{type.class} => #{type.to_s}>")
	end
end

class FFIBuilder
	def initialize
		@struct = {}
		@enum = {}
		@func = {}
		@fptrs = {}
	end
	def add_func(func)
		@func[func.name] =func
	end
	def has_func? name
		@func.key? name
	end
	def add_struct(func)
		@struct[func.name] =func
	end
	def has_struct? name
		@struct.key? name
	end
	def add_enum(func)
		@enum[func.name] =func
	end
	def has_enum? name
		@enum.key? name
	end
	def add_fnptr(func)
		@fptrs[func.name] =func
	end
	Func = Struct.new(:name, :ret, :args, :sig)
	class Func
		def to_s
			"[#{ret.to_s} => [#{args.map(&:to_s).join(", ")}]]"
		end
	end
	Cstruct = Struct.new(:name, :members)
	CstructMember = Struct.new(:name, :type, :sig)
	class Cstruct
		def to_s
			"[#{members.map(&:to_s).join(", ")}]"
		end
	end
	class CstructMember
		def to_s
			"#{name} => #{type}"
		end
	end
	Cenum = Struct.new(:name, :members)
	class Cenum
		def to_s
			"[#{members.map(&:to_s).join(", ")}]"
		end
	end
	def to_s
		@func.values.sort_by(&:name).each do |fn|
			puts "#{fn.name} =  #{fn.to_s}"
		end
		nil
	end
	def export(basename, classes, enums, mod, which, scanned_version)
		truebase = "#{basename}_"
		original_classes = classes
		classes = classes.map{|x|"#{x}_"}.sort_by{|x|-x.length}
		enums = enums.map{|k, x|["#{k}_", "#{x}_"]}.sort_by{|x|-x.last.length}.to_h
		holders = {}
		@func.values.sort_by(&:name).each do |fn|
			next unless fn.name.start_with? truebase
			cleanname = fn.name[truebase.length..-1]
			ocleanname = cleanname
			target = classes.find{|x|cleanname.start_with? x}
			if target
				cleanname = cleanname[target.length..-1]
			end
			#puts fn.name + fn.to_s.colorize(:light_green) + fn.sig
			line = ":#{ocleanname}, :#{fn.name}, [#{fn.args.map{|x|to_ffi_types(x, truebase, FFI_ARG)}.join(", ")}], #{to_ffi_types(fn.ret, truebase, FFI_RET)}"
			(holders[target] ||= []) << [cleanname, ocleanname, fn.sig, "\n# #{fn.sig}\nattach_function #{line}"]
		end
		eaches = []
		@enum.values.sort_by(&:name).each do |enum|
			en = enum.name
			next unless en.start_with? truebase
			cleanname = en[truebase.length..-1]
			target = classes.find{|x|cleanname.start_with? x}
			tb = truebase
			if target
				tb += enums[target]
				cleanname = cleanname[target.length..-1]
			end
			enumdecl = "enum :#{cleanname}, [#{enum.members.flat_map{|it|
				if it.is_a? String
					[":" + name2enum(it.downcase, tb)]
				elsif it.is_a? Array and it.last.is_a? Integer
					[":" + name2enum(it.first.downcase, tb), it.last]
				else
					raise "unknown enum entry #{it}"
				end
			 }.join(", ")}]"
			 eaches << enumdecl
		end
		structs, clazzes = @struct.values.map{|s| try_struct(s, truebase, original_classes) }.partition{|x|x[0] == :struct}
		structs.each do |_, name, layout|
		
		# enums copied for ease of access
		# #{eaches.join("\n\t\t")}
			 holders[nil] << <<EOS
class #{name.capitalize} < FFI::Struct
		
		# main data
		#{layout.gsub("\n", "\n\t\t")}
		
		#{ENUM_CONST_CODE.gsub("\n", "\n\t")}
	end
EOS
		end
		
		clazzes.each do |_, name, rname, size|
			holders[nil] << <<EOS
class #{rname}
		SIZEOF = #{size}
		def initialize
			if block_given? 
				ret = nil # ffi doesn't return the result, must save it manually
				FFI::MemoryPointer.new(:uint8, SIZEOF) do |ptr|
					@this = ptr
					ret = yield self
				end
				ret
			else
				@this = FFI::MemoryPointer.new(:uint8, SIZEOF)
			end
		end
		attr_reader :this
		alias :to_ptr :this #ffi casting
		
		# forwarding proxies
		
		#{holders[name + "_"].map {|name, tname, sig, line| base = "# #{sig}\n\t\tdef #{name}(*args); #{mod}.#{tname}(@this, *args); end\n"
			# TODO: check for argsize
			if name.match(/^get(.*)/)
			base << "\t\tdef #{$1}(); #{mod}.#{tname}(@this); end\n"
			elsif name.match(/^set(.*)/)
			base << "\t\tdef #{$1}=(value); #{mod}.#{tname}(@this, value); end\n"
			end
			base
		 }.join("\n\t\t")}
	end
EOS
		end
		callbacks = @fptrs.values.sort(&:name).map do |fn|
			ocleanname = name2enum(fn.name, truebase)
			line = ":#{ocleanname}, [#{fn.args.map{|x|to_ffi_types(x, truebase, FFI_ARG)}.join(", ")}], #{to_ffi_types(fn.ret, truebase, FFI_RET)}"
			"# #{fn.sig}\n\tcallback #{line}"
		end.reject(&:nil?).join("\n\t")
		return <<EOS
require 'ffi'
		
module #{mod}
	extend FFI::Library
	ffi_lib #{which}
	INTERFACE_VERSION = #{scanned_version.inspect}
	
	# enums
	#{eaches.join("\n\t")}
	
	# callbacks
	#{callbacks}
	
	#{ENUM_CONST_CODE}
	
	# structs and classes
	#{holders[nil].filter{|v|v.is_a? String }.join("\n\t")}
	
	# methods
	#{holders.flat_map{|k, vs| vs.filter{|v|v.is_a? Array }.map(&:last)}.join("\n").gsub("\n", "\n\t")}
	
end
EOS
	end
	def try_struct(s, base, map)
		name = s.name
		raise "not our type #{name}" unless name.start_with? base
		name = name[0...-2] if name.end_with? "_t"
		name = name[base.length..-1]
		if map.include? name # class!
			# just make sizeof
			[:class, name, name.split("_").map(&:capitalize).join(), s.members.map{|m| csizeof(m.type)}.sum]
		else # struct only
			sname = name2type(s.name, base)
			layout = s.members.map do |mem|
				[":#{mem.name}, #{to_ffi_types(mem.type, base, {})},", " # #{mem.sig}"]
			end
			layout.last.first.sub!(/,$/, "")
			layout = "layout #{layout.map{|x|x.join("")}.join("\n\t")}"
			[:struct, name, layout]
		end
	end
	def csizeof(type)
		ptrsize = 8  #NOTE: assumes 64 bit, as there are no 128 bit machines 
		case type
		when :int, :uint,:bool then 4
		when :out_num, :string then ptrsize
		when PackedInfo
			if type.data[:struct_out]
				ptrsize
			elsif type.data[:sigset]
				128
			elsif type.data[:ffi_t]
				8 # no not really, but it cover it
			else
				raise "unknown  of type #{type}"
			end
		else
			raise "unknown size of type #{type}"
		end
	end
	
	def to_ffi_types(type, truebase, extra)
		return ":#{FFI_CLEAN[type]}" if FFI_CLEAN[type]
		return ":#{extra[type]}" if extra[type]
		case type
		when PackedInfo
			if type.data[:struct_out]
				name2type(type.data[:struct_out], truebase) + ".by_ref"
			elsif type.data[:enum]
				":" + name2enum(type.data[:enum], truebase)
			elsif type.data[:funcptr]
				":" + name2enum(type.data[:funcptr], truebase)
			elsif type.data[:ffi_t]
				":" + type.data[:ffi_t]
			elsif type.data[:length] &&  type.data[:type] == :fixed_string
				"[:uint8, #{type.data[:length]}]"
			else
				raise "missing hash: #{type}"
			end
		else
		raise "missing type: #{type}"
		end
	end
	
	def name2type(name, base)
		raise "not our type #{name}" unless name.start_with? base
		name = name[0...-2] if name.end_with? "_t"
		name = name[base.length..-1]
		name.capitalize
	end
	def name2enum(name, base)
		raise "not our type #{name} #{base}" unless name.start_with? base
		name = name[0...-2] if name.end_with? "_t"
		name = name[base.length..-1]
		name
	end
end

FFI_CLEAN = {
	bool: :bool,
	int: :int32,
	uint: :uint32,
	short: :int16,
	ushort: :uint16,
	char: :int8,
	byte: :uint8,
	long: :int64,
	ulong: :uint64,
	opaque_ptr: :pointer,
	opaque_ptr_array: :pointer,
	void: :void,
	string: :string,
	
	# sad ones that could benefit from helpers
}
FFI_ARG = {
	out_num: :buffer_inout,
	void_ptr: :buffer_inout,
	string_out: :buffer_inout,
	string_buffer: :buffer_inout,
	int_array: :buffer_in,
	
	# maybe to make nice
	va_pointer: :pointer,
	string_array: :pointer,
}
FFI_RET = {
	out_num: :pointer,
	void_ptr: :pointer,
	string_out: :pointer,
	string_array: :pointer,
}


def extract_function(func, name,  help, ast)
	ret = type_decode(func.type, ast, false)
	params = func.params.map{|x|type_decode(x.type, ast, true)}
	FFIBuilder::Func.new(name, ret, params, help.gsub(/\r|\n/," "))
end


def extract_struct(obj, ast)
#	p obj
	members = obj.members.flat_map{|x| x.declarators.map{|y| FFIBuilder::CstructMember.new(y.name, type_decode(y.type, ast, false), x.to_s) }}
	FFIBuilder::Cstruct.new(obj.name, members)
end


def extract_enum(obj)
	#p obj
	FFIBuilder::Cenum.new(obj.name, obj.members.map do |member|
		name = member.name
		if member.val
			[name, expr_eval(member.val)]
		else
			name
		end
	end)
end

def expr_eval(type)
	case type
	when C::IntLiteral then type.val
	when C::ShiftLeft
		expr_eval(type.expr1) << expr_eval(type.expr2)
	when C::Add
		expr_eval(type.expr1) + expr_eval(type.expr2)
	else raise "mising eval class #{type.class}"
	end
end


def process(file, builder, live: false)

	pp = C::Preprocessor.new
	pp.include_path = ['fake/', '../libfixposix/src/include', '.']

	ast = C::Parser.new.parse(pp.preprocess("#include <fake/fake.h>\n#{File.read file}").gsub(/#[^\n]+$/,"").tap{|x|File.write("/tmp/out", x)})

	ast.entities.each do |ent|
		ent.declarators.each do |decl|
			if decl.type.Function?
				next if builder.has_func? decl.name
				next unless decl.name.start_with? "lfp_"
				if decl.type.var_args? # TODO: doable
					puts "#{ent.to_s} !!".colorize(:light_blue) if live
					next
				end
				print "#{ent.to_s} ".colorize(:light_green) if live
				ret = extract_function(decl.type, decl.name,  decl.type.to_s, ast)
				builder.add_func(ret)
				puts ret.to_s if live
			else
				next if decl.name == "va_list" || decl.name == "sigset_t"
				if decl.type.Enum?
					print "#{ent.to_s} ".colorize(:light_green) if live
					ret = extract_enum(decl.type)
					ret.name = decl.name
					builder.add_enum(ret)
					puts ret.to_s if live
				elsif decl.type.Struct?
					next if decl.type.name == "opaque_ptr"
					print "#{ent.to_s} ".colorize(:light_green) if live
					ret = extract_struct(decl.type, ast)
					ret.name = decl.name 
					builder.add_struct(ret)
					puts ret.to_s if live
				elsif decl.type.Pointer? and decl.type.type.Function?
					print "#{ent.to_s} ".colorize(:light_green) if live
					ret = extract_function(decl.type.type, decl.name, ent.to_s, ast)
					builder.add_fnptr(ret)
					puts ret.to_s if live
				elsif decl.type.name == "ffi_t" || decl.name == "ffi_t"
					# ignore
				else
					puts "? #{decl.type.class} from #{decl.name}"
				end
			end
		end
		if ent.declarators.length == 0
			if ent.type.Enum?
				print "#{ent.to_s} ".colorize(:light_green) if live
				ret = extract_enum(ent.type)
				builder.add_enum(ret)
				puts ret.to_s if live
			elsif ent.type.Struct?
				next if ent.type.name == "opaque_ptr" || ent.type.name == "sigset_t"
				print "#{ent.to_s} ".colorize(:light_green) if live
				ret = extract_struct(ent.type, ast)
				builder.add_struct(ret)
				puts ret.to_s if live
			else
				puts "?BASE = #{ent.type.class}".colorize(:red)
			end
		end
	end
end

common = FFIBuilder.new
process("fake/time.h", common, live: false)

live =false # TODO: start debugging here

builder = FFIBuilder.new
ARGV.each do |a|
	puts "------------------------------------------ #{a} ----------------------------------" if live
	process(a, builder, live: live)
end

#puts builder.to_s

puts builder.export("lfp", ["spawnattr", "spawn_file_actions"], {"spawnattr" => "spawn"}, "LFP", "LFPFile.local_so", "0.4.3") unless live


