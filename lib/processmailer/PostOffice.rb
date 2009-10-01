require 'actionpool'
require 'spockets'
require 'processmailer/Postbox'
require 'processmailer/Exceptions'
require 'processmailer/LogHelper'

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
        # :max_threads:: default number of threads per Postbox
        # :min_threads:: minimum number of threads per Postbox
        # :thread_to:: maximum time thread is allowed to idle
        # :action_to:: maximum time a thread may work on an action
        # :logger:: Logger to use
        # :pool:: ActionPool for PostOffice to utilize (not used by Postboxes)
        # Sets up a PostOffice to handle message delivery.
        def initialize(args={})
            default_args(args)
            @max_workers = args[:max_threads]
            @min_workers = args[:min_threads]
            @logger = LogHelper.new(args[:logger])
            @thread_to = args[:thread_to]
            @action_to = args[:action_to]
            @postboxes = {} # {PID => {:read => rd, :write => wr}}
            @hooks = {} # {Some::Class => []}
            @readers = []
            @close_postoffice = false
            @pool = args[:pool] ? args[:pool] : nil
            @spockets = Spockets::Spockets.new(:pool => @pool)
            Signal.trap(0, proc{clean}) # make sure everything is cleaned up
        end
        # obj:: Serializable object for delivery
        # Delivers object to Postboxes for processing
        def deliver(obj)
            call_hooks(obj)
            s = [Marshal.dump(obj)].pack('m')
            @postboxes.each_value do |pipes|
                pipes[:write].puts s
                pipes[:write].flush
            end
        end
        # pb:: Class name of custom Postbox
        # Registers a new Postbox with the PostOffice. Returns Postbox process ID
        def register(pb=nil, &block)
            raise Exceptions::InvalidType.new(Class, pb.class) unless pb.nil? || pb.is_a?(Class)
            raise Exceptions::EmptyParameters.new if pb.nil? && !block_given?
            r,w = IO.pipe
            pid = nil
            if(block_given?)
                pid = Kernel.fork do
                    box = Postbox.new(:proc => block, :read_pipe => r, :write_pipe => w, :max_threads => @max_workers,
                                      :min_threads => @min_workers, :thread_to => @thread_to, :action_to => @action_to,
                                      :logger => @logger.raw)
                    Signal.trap('HUP'){ box.close }
                    box.listen
                end
            else
                pid = Kernel.fork do
                    box = pb.new(:read_pipe => r, :write_pipe => w, :max_threads => @max_workers,
                                 :min_threads => @min_workers, :thread_to => @thread_to,
                                 :action_to => @action_to, :logger => @logger.raw)
                    Signal.trap('HUP'){ box.close }
                    box.listen
                end
            end
            if(pid)
                @postboxes[pid] = {:read => r, :write => w}
                @readers << r
                @spockets.add(r) do |string|
                    deliver(Marshal.load(string.unpack('m')[0])) unless string.nil?
                end
                return pid
            end
        end
        # pid:: Postbox delivery address (Process ID)
        # Removes a Postbox from the PostOffice
        def unregister(pid)
            pid = pid.to_i
            raise Exception.new('Failed to locate process') unless @postboxes.has_key?(pid)
            pipes = @postboxes.delete(pid)
            Process.kill('HUP', pid)
            @spockets.remove(pipes[:read])
            pipes[:write].puts "stop"
            Process.waitpid(pid)
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
            @pool = ActionPool::Pool.new(1, 5, nil, nil, @logger.raw) if @pool.nil?
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
        # Stop all processes
        def clean
            @postboxes.each_key{|k| unregister(k)}
        end
        private

        def call_hooks(obj)
            obj.class.ancestors.each do |klass|
                if(@hooks[klass])
                    @hooks[klass].each do |hook|
                        @pool.process do
                            result = nil
                            begin
                                result = hook.call(obj)
                            rescue Object => boom
                                @logger.warn("Hook generated an error: #{boom}")
                                result = boom
                            ensure
                                deliver(result) unless result.nil?
                            end
                        end
                    end
                end
            end
        end
        def default_args(args)
            {:max_threads => 5, :min_threads => 1, :thread_to => nil, :action_to => nil, :logger => nil}.each_pair{|k,v|
                args[k] = v unless args.has_key?(k)
            }
        end
    end
end
