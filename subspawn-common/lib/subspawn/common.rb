require 'subspawn/common/version'
require 'subspawn/common/deferred-pipes'
require 'subspawn/common/bidi-io'
# do NOT include raw_status automatically. Doing so will probably break your engine. It must only be included for subspawn platforms that replace waitpid2.
