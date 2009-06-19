require 'actionpool'
require 'processmailer/Exceptions'

module ProcessMailer
    class Postbox
        # Initialize the Postbox. Subclasses should
        # super() after doing their setup
        def initialize(args)
            default_args(args)
            @pipes = {:read => args[:read_pipe], :write => args[:write_pipe]}
            @proc = args[:proc]
            @pool = ActionPool::Pool.new(1, args[:max_threads])
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
                    s = Kernel.select(@pipe[:read], nil, nil, nil)
                    receive
                rescue Exceptions::Resync
                    # resync sockets #
                rescue Object => boom
                end
            end
        end
        private
        def receive
            s = @pipes[:read].read
            obj = s.size > 0 ? Marshal.load(s.unpack('m')[0]) : nil
            run_process(obj)
        end
        def send(obj)
            return if obj.nil?
            @pipes[:send].write [Marshal.dump(obj)].pack('m')
        end
        def run_process(obj)
            @pool.process do
                begin
                    send(process(obj))
                rescue Object => boom
                    send(boom)
                end
            end
        end
        def default_args(args)
            {:read_pipe => nil, :write_pipe => nil, :proc => nil, :max_threads => 5}.each_pair{|k,v|
                args[k] = v unless args.has_key?(k)
            }
        end
    end
end