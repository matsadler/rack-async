require 'rubygems'
require 'rack'
require 'rack/async'
require 'ebb'

class ThreadedAsyncApp
  def call(env)
    body = env['async.body']
    env['async.callback'].call([200, {}, body])
    
    Thread.new do
      5.times {sleep 1; body << "hi\r\n"}
      body.finish
    end
    
    Rack::Async::RESPONSE
  end
end

app = Rack::Builder.new
app.use Rack::Async
app.run ThreadedAsyncApp.new
Rack::Handler::Ebb.run(app, :Port => 9292)