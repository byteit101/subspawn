require 'engine-hacks/version'
if defined? JRUBY_VERSION # or: RUBY_PLATFORM =~ /java/
	# JRuby
	require 'engine-hacks/jruby'
else
	# MRI or TruffleRuby
	require 'engine-hacks/cruby'
end
