require 'alces/ext/configuration'

module Alces
  module Ext
    module Bundler
      module DslExtensions
        def gem(*args)
          h = args.last
          if h.is_a?(Hash) && h.has_key?(:local)
            h.delete(:local)
            DslExtensions.gem_local(self, *args)
          else
            super
          end
        end

        class << self
          def gem_local(ctx, *args)
            if Alces::Ext::Configuration.development?
              h = args.pop
              require 'pathname'
              dir = File.expand_path(("../" * 8), Pathname.new(__FILE__).realpath)
              if File.directory?("#{dir}/#{args.first}")
                ctx.gem(*args, h.merge({:path => "#{dir}/#{args.first}"}))
                return
              end
            end
            ctx.gem *args
          end
        end
      end
    end
  end
end
