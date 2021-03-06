require File.expand_path(File.dirname(__FILE__) + '/../lib/rack/async')
require 'thread'
require 'test/unit'

class AsyncTest < Test::Unit::TestCase
  
  def setup
    app = Proc.new do |env|
      body = env["async.body"]
      env["async.callback"].call([200, {"Content-Type" => "text/plain"}, body])
      
      Thread.new do
        body << "foo"
        sleep 0.1 # simulate doing something
        body << "bar"
        sleep 0.1
        body << "baz"
        body.succeed
      end
      
      [-1, {}, []]
    end
    
    @async_app = Rack::Async.new(app)
    @env = {}
  end
  
  def test_thin
    finished = false
    @env["async.callback"] = Proc.new do |response|
      status, headers, body = response
      assert_equal(200, status)
      assert_equal({"Content-Type" => "text/plain"}, headers)
      assert_instance_of(Rack::Async::CallbackBody, body)
      
      calls_to_each = 0
      body.each do |chunk|
        assert_equal(%W{foo bar baz}[calls_to_each], chunk)
        calls_to_each += 1
      end
      
      body.callback do
        assert_equal(3, calls_to_each)
        finished = true
      end
    end
    
    async_response = @async_app.call(@env)
    assert_equal([-1, {}, []], async_response)
    
    until finished
      sleep 0.01 # if we get stuck here body.callback was never called
    end
  end
  
  def test_ebb
    finished = false
    @env["async.callback"] = Proc.new do |status, headers, body|
      assert_equal(200, status)
      assert_equal({"Content-Type" => "text/plain"}, headers)
      assert_instance_of(Rack::Async::CallbackBody, body)
      
      calls_to_each = 0
      body.each do |chunk|
        assert_equal(%W{foo bar baz}[calls_to_each], chunk)
        calls_to_each += 1
      end
      
      body.on_eof do
        assert_equal(3, calls_to_each)
        finished = true
      end
    end
    
    async_response = @async_app.call(@env)
    assert_equal([0, {}, []], async_response)
    
    until finished
      sleep 0.01 # if we get stuck here body.on_eof was never called
    end
  end
  
  def test_mongrel
    response = @async_app.call(@env)
    status, headers, body = response
    
    assert_equal(200, status)
    assert_equal({"Content-Type" => "text/plain"}, headers)
    assert_instance_of(Rack::Async::BlockingBody, body)
    
    calls_to_each = 0
    body.each do |chunk|
      assert_equal(%W{foo bar baz}[calls_to_each], chunk)
      calls_to_each += 1
    end
    assert_equal(3, calls_to_each)
  end
  
end