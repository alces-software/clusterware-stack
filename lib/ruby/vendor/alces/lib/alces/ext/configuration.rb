module Alces
  module Ext
    module Configuration
      class << self
        def config
          @config ||= load_config
        end

        def method_missing(s,*a,&b)
          if config.has_key?(s.to_s)
            config[s.to_s]
          else
            super
          end
        end

        def development?
          ENV['ALCES_DEV'].nil? && config['development'] == true
        end

        private
        def load_config
          f = config_path
          if File.exists?(f)
            require 'yaml'
            YAML::load_file(f)
          else
            { 
              'development' => false
            }
          end
        end

        def config_path
          p = ENV['ALCES_EXT_CONFIG']
          return p unless p.nil?
          require 'pathname'
          here = Pathname.new(__FILE__).realpath
          File.expand_path(File.join("../" * 4, "config/local_config.yml"), here)
        end
      end
    end
  end
end
