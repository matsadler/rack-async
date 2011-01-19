require 'rubygems'
require 'rack/async'
require 'eventmachine'

class EMAsyncApp
  def call(env)
    body = env['async.body']
    env['async.callback'].call([200, {}, body])
    
    event_machine do
      i = 0
      timer = EM.add_periodic_timer(1) do
        body << "Hello world!\r\n"
        i += 1
        if i >= 5
          body.finish
          timer.cancel
        end
      end
    end
    
    Rack::Async::RESPONSE
  end
  
  private
  def event_machine(&block)
    if EM.reactor_running?
      block.call
    else
      Thread.new {EM.run}
      EM.next_tick(block)
    end
  end
end

use Rack::Async
run EMAsyncApp.new