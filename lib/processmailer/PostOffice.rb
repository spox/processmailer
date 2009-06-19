require 'actionpool'
require 'processmailer/Postbox'
require 'processmailer/Exceptions'

module ProcessMailer
    # The PostOffice is the driver of the
    # process mailer. Its job is to accept
    # objects which are then passed off to
    # each Postbox, which may or may not process
    # the object. Messages returned to the 
    # PostOffice by a Postbox will then be
    # sent to any proc that has hooked into
    # the type.
    class PostOffice
        # args:: setup hash
        # Setup the PostOffice
        # default_workers: default number of threads per Postbox
        def initialize(args={})
            @default_workers = args[:default_workers] ? args[:default_workers] : 5
            @postboxes = [] # [{:read => rd, :write => wr}}]
            @hooks = {} # {Some::Class => []}
            @readers = []
            @close_postoffice = false
            @processor = Thread.new{listen}
            @pool = args[:pool] ? args[:pool] : nil # for hooks
        end
        # obj:: Serializable object for delivery
        # Delivers object to Postboxes for processing
        def deliver(obj)
            s = [Marshal.dump(obj)].pack('m')
            @postboxes.each_pair{|pb, pipes| pipes[:write].write s}
            call_hooks(obj)
        end
        # pb:: Class name of custom Postbox
        # Registers a new Postbox with the PostOffice. Returns Postbox process ID
        # TODO: fix the fork in here
        def register(pb=nil, &block)
            raise Exceptions::InvalidType.new(Postbox, pb.class) unless pb.nil? || pb.is_a?(Postbox)
            raise Exceptions::EmptyParameters.new if pb.nil? && block.nil?
            r,w = IO.pipe
            pid = nil
            if(block_given?)
                pid = Kernel.fork do
                    
                end
            else
            end
            @postboxes << {:read => r, :write => w, :pid => pid}
            @readers << r
            @processor.raise Exceptions::Resync.new
        end
            if(pb.is_a?(Proc) || pb.nil?)
                pb = block if pb.nil?
                rd, wr = IO.pipe
                box = Postbox.new(:proc => pb, :read_pipe => rd, :write_pipe => wr, :max_theads => @default_workers)
                @postboxes[box] = {:read => rd, :write => wr}
                @readers << rd
            else
                rd, wr = IO.pipe
                pb.install_pipe(rd, wr)
                @postboxes[pb] = {:read => rd, :write => wr}
                @readers << rd
            end
            @processor.raise Exceptions::Resync.new
        end
        # pbid:: Postbox
        # Removes a Postbox from the PostOffice
        def unregister(pb)
            raise Exceptions::InvalidType.new(Class, pb.class) unless pb.is_a?(Postbox)
            pipes = @postboxes.delete(pb)
            @readers.delete(pipes[:read])
            @processor.raise Exceptions::Resync.new
        end
        # c:: Class
        # action:: callable block (Proc/lambda)
        # block:: code block
        # Add a hook to a given object type. When
        # the PostOffice receives the object, the
        # block will be called. Return an ID to be
        # used when unhooking
        # 
        # Example:
        #   po.hook(Array){|obj| puts obj.join(', ')}
        def hook(c, action=nil, &block)
            b = action.nil? ? block : action
            raise Exceptions::EmptyParameters.new if b.nil?
            raise Exceptions::InvalidType.new(Class, c.class) unless c.is_a?(Class)
            @hooks[c] = Array.new unless @hooks[c]
            @hooks[c] << b
            @pool = ActionPool::Pool.new if @pool.nil?
            return @hooks[c].index(b)
        end
        # c:: Class
        # hid:: ID from hook()
        # Unhook a block from object delivery
        def unhook(c, hid)
            raise Exceptions::EmptyParameters.new unless c.is_a?(Class)
            raise Exceptions::EmptyParameters.new unless hid.is_a?(Integer)
            @hooks[c].delete_at(hid)
            @hooks.delete(c) if @hooks[c].empty?
        end

        # Returns hash of hooks currently in the PostOffice
        def hooks
            @hooks
        end

        # Returns hash of PostBoxes currently in the PostOffice
        def postboxes
            @postboxes
        end
        private
        def listen
            until(@close_postoffice) do
                begin
                    s = Kernel.select(@readers, nil, nil, nil)
                    deliver(Marshal.load(s.unpack('m'))[0])
                rescue Exceptions::Resync
                    # resync sockets #
                rescue Object => boom
                end
            end
        end
        def call_hooks(obj)
            if(@hooks[obj.class])
                @hooks[obj.class].each do |hook|
                    begin
                        @pool.process{hook.call(obj)}
                    rescue Object => boom
                        #do something
                    end
                end
            end
        end
    end
end
