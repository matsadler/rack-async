require 'thread'

module Rack
  class Async
    RESPONSE = [-1, {}, []].freeze
    CALLBACK = "async.callback".freeze
    BODY = "async.body".freeze
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      original_callback = env[Async::CALLBACK]
      if original_callback.respond_to?(:arity)
        original_callback_arity = original_callback.arity
      elsif original_callback
        original_callback_arity = original_callback.method(:call).arity
      end
      
      if original_callback # we've got a thin-like async api!
        if original_callback_arity > 1 # wrap ebb's callback to expand the args
          env[Async::CALLBACK] = Proc.new do |response|
            original_callback.call(*response)
          end
        end
        env[Async::BODY] = Async::CallbackBody.new
      else # no async api, but blocking in the right places we can fake it
        blocking_callback = Async::BlockingCallback.new
        env[Async::CALLBACK] = blocking_callback
        env[Async::BODY] = Async::BlockingBody.new
      end
      
      response = @app.call(env)
      
      if response.first != Async::RESPONSE.first # non-async response
        response
      elsif original_callback && original_callback_arity > 1 # ebb-like
        [0, {}, []]
      elsif original_callback # thin-like
        Async::RESPONSE
      else # mongrel, etc
        blocking_callback.wait
      end
    end
    
    class BlockingCallback < Queue
      alias call push
      alias wait pop
    end
    
    module Deferrable
      def set_deferred_status(status, *args)
        @deferred_status = status
        @deferred_args = args
        iterator = Proc.new {|block| block.call(*@deferred_args)}
        case status
        when :succeeded
          @callbacks.each(&iterator)
        when :failed
          @errbacks.each(&iterator)
        end
        @callbacks.clear
        @errbacks.clear
      end
      
      def succeed(*args)
        set_deferred_status(:succeeded)
      end
      alias finish succeed
      alias set_deferred_success succeed
      
      def fail(*args)
        set_deferred_status(:failed)
      end
      alias set_deferred_failure fail
      
      def callback(&block)
        if @deferred_status == :succeeded
          block.call(*@deferred_args)
        elsif @deferred_status != :failed
          @callbacks.unshift(block)
        end
      end
      
      def errback(&block)
        if @deferred_status == :failed
          block.call(*@deferred_args)
        elsif @deferred_status != :succeeded
          @errbacks.unshift(block)
        end
      end
    end
    
    class BlockingBody < Queue
      include Deferrable
      
      def initialize(*args)
        super
        @callbacks = []
        @errbacks = []
      end
      
      def each
        until @deferred_status && empty?
          data = pop
          yield data if data
        end
      rescue
        fail
        raise
      end
      
      def set_deferred_status(*args)
        super
        self << nil
      end
    end
    
    class CallbackBody
      include Deferrable
      
      def initialize(*args)
        super
        @buffer = []
        @lock = Mutex.new
        @callbacks = []
        @errbacks = []
      end
      
      def <<(data)
        @lock.synchronize do
          if @each_callback
            begin
              @each_callback.call(data)
            rescue
              fail
              raise
            end
          else
            @buffer << data
          end
        end
        self
      end
      
      def each(&block)
        @lock.synchronize do
          @buffer.each(&block)
          @buffer.clear
          @each_callback = block
        end
      end
      
      alias on_eof callback # :nodoc: ebb compatibility
    end
    
  end
end