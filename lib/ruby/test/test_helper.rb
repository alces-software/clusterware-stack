require 'pathname'
here = Pathname.new(__FILE__).realpath
ENV['BUNDLE_GEMFILE'] ||= File.expand_path("../../Gemfile", here)
$: << File.expand_path("../../lib", here)

require 'rubygems'
require 'bundler/setup'
require 'alces/stack/overlay'
require 'stringio'
require 'test/unit'
