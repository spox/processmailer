require 'logger'

module ProcessMailer

    class LogHelper
    
        def initialize(logger=nil)
            @logger = logger
        end

        def info(m)
            @logger.info(m) unless @logger.nil?
        end

        def warn(m)
            @logger.warn(m) unless @logger.nil?
        end

        def fatal(m)
            @logger.fatal(m) unless @logger.nil?
        end

        def error(m)
            @logger.error(m) unless @logger.nil?
        end

        def raw
            return @logger
        end
    end

end