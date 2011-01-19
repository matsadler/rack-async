require 'thread'
require 'rubygems'
require 'rack/async'

class ThreadedAsyncApp
  def call(env)
    body = env['async.body']
    env['async.callback'].call([200, {}, body])
    
    Thread.new do
      5.times {sleep 1; body << "Hello world!\r\n";}
      body.finish
    end
    
    Rack::Async::RESPONSE
  end
end

use Rack::Async
run ThreadedAsyncApp.new