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
    
    class BlockingBody < Queue
      def each
        until @finished && empty?
          data = pop
          yield data if data
        end
      end
      
      def succeed
        @finished = true
        self << nil
      end
      alias finish succeed
      alias fail succeed
    end
    
    class CallbackBody
      def initialize(*args)
        super
        @buffer = []
        @lock = Mutex.new
      end
      
      def <<(data)
        @lock.synchronize do
          if @each_callback
            @each_callback.call(data)
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
      
      def succeed
        @callback.call if @callback
        @finished = true
      end
      alias finish succeed
      
      def fail
        @errback.call if @errback
        @finished = true
      end
      
      def callback(&block)
        if !@callback && @finished
          block.call
        else
          @callback = block
        end
      end
      
      def errback(&block)
        if !@errback && @finished
          block.call
        else
          @errback = block
        end
      end
      
      def on_eof(&block)
        callback(&block)
        errback(&block)
      end
    end
    
  end
end