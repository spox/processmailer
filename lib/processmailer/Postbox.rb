require 'ActionPool'

module ProcessMailer
    class Postbox
        # Initialize the Postbox. Subclasses should
        # super() before doing their setup
        def initialize(args)
            default_args(args)
            @pipes = {:read => args[:read_pipe], :write => args[:write_pipe]}
            @proc = args[:proc]
            @pool = ActionPool::Pool.new(1, args[:max_threads])
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