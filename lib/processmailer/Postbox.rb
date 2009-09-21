require 'actionpool'
require 'processmailer/Exceptions'
require 'processmailer/LogHelper'

module ProcessMailer
    class Postbox
        # Initialize the Postbox. Subclasses should
        # super(), preferably first thing
        def initialize(args)
            default_args(args)
            @pipes = {:read => args[:read_pipe], :write => args[:write_pipe]}
            @proc = args[:proc] ? arg[:proc] : lambda{nil}
            @pool = ActionPool::Pool.new(args[:min_threads], args[:max_threads], args[:thread_to], args[:action_to], args[:logger])
            @logger = LogHelper.new(args[:logger])
            @stop = false
        end
        # Close the postbox for delivery
        def close
            @stop = true
        end
        # read:: read IO.pipe
        # write:: write IO.pipe
        # Install pipes for Postbox (Generally
        # used by the PostOffice)
        def install_pipe(read, write)
            @pipes[:read] = read
            @pipes[:write] = write
        end
        # obj:: object to be processed
        # Process an object. This method should
        # be overridden in subclasses.
        def process(obj)
            return @proc.call(obj)
        end
        # Listen for incoming messages from PostOffice
        def listen
            until(@stop) do
                begin
                    Kernel.select([@pipes[:read]], nil, nil, nil)
                    receive
                rescue Exceptions::Resync
                    # resync sockets #
                rescue Object => boom
                    @logger.error("Postbox encountered error on listen: #{boom}")
                end
            end
        end
        private
        def receive
            @logger.info("Postbox (#{self}) has message waiting")
            begin
                s = @pipes[:read].gets
                @logger.info("Postbox (#{self}) received an empty message") if s.nil? || s.empty?
                return if s.nil? || s.empty?
                if(s.strip == 'stop')
                    @logger.info("Postbox (#{self}) received a stop instruction")
                    return
                end
                @logger.info("Postbox (#{self}) message: #{s}")
                obj = s.size > 0 ? Marshal.load(s.unpack('m')[0]) : nil
                @logger.info("Postbox (#{self}) message reconstructed: #{obj}")
                run_process(obj)
            rescue Object => boom
                @logger.error("Postbox encountered error on receive: #{boom}")
            end
            
        end
        def send(obj)
            return if obj.nil?
            @pipes[:write].puts [Marshal.dump(obj)].pack('m')
        end
        def run_process(obj)
            @pool.process do
                result = nil
                begin
                    result = process(obj)
                rescue Object => boom
                    @logger.warn("Postbox contents generated exception on call: #{boom}")
                    result = boom
                end
                send(result)
            end
        end
        def default_args(args)
            {:read_pipe => nil, :write_pipe => nil, :proc => nil, :max_threads => 5,
             :min_threads => 1, :thread_to => nil, :action_to => nil, :logger => nil}.each_pair{|k,v|
                args[k] = v unless args.has_key?(k)
            }
        end
    end
end