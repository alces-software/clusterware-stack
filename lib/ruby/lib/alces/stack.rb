require 'alces/tools/config'
require 'yaml'

module Alces
  module Stack
    class Configuration < Struct.new(:log_root, :ssl_root, :etc_root)
      def initialize(h)
        h.each {|k,v| self[k] = v}
      end
    end

    class << self
      def config
        @config ||= Configuration.new(default_config.merge(load_config))
      end

      def default_config
        {
          'log_root' => '/var/log/alces/tools',
          'ssl_root' => '/var/lib/alces/nodeware/etc/ssl',
          'etc_root' => '/var/lib/alces/nodeware/etc'
        }
      end

      def load_config
        YAML.load_file(Alces::Tools::Config.find('stack.yml'))
      rescue
        {}
      end
    end
  end
end
