require File.expand_path(File.dirname(__FILE__) + '/../lib/rack/async')
require 'thread'
require 'test/unit'

class AsyncBodyTest < Test::Unit::TestCase
  
  def setup
    app = Proc.new do |env|
      body = env["async.body"]
      
      Thread.new do
        body << "foo"
        sleep 0.1 # simulate doing something
        body << "bar"
        sleep 0.1
        body << "baz"
        body.succeed
      end
      
      [200, {"Content-Type" => "text/plain"}, body]
    end
    
    @async_app = Rack::Async.new(app)
    @env = {}
  end
  
  def test_thin
    @env["async.callback"] = Proc.new {|arg| flunk "should not be called"}
    status, headers, body = @async_app.call(@env)
    
    assert_equal(200, status)
    assert_equal({"Content-Type" => "text/plain"}, headers)
    assert_instance_of(Rack::Async::CallbackBody, body)
    
    calls_to_each = 0
    body.each do |chunk|
      assert_equal(%W{foo bar baz}[calls_to_each], chunk)
      calls_to_each += 1
    end
    
    finished = false
    body.callback do
      assert_equal(3, calls_to_each)
      finished = true
    end
    
    until finished
      sleep 0.01 # if we get stuck here body.callback was never called
    end
  end
  
  def test_ebb
    @env["async.callback"] = Proc.new {|a,b,c| flunk "should not be called"}
    status, headers, body = @async_app.call(@env)
    
    assert_equal(200, status)
    assert_equal({"Content-Type" => "text/plain"}, headers)
    assert_instance_of(Rack::Async::CallbackBody, body)
    
    calls_to_each = 0
    body.each do |chunk|
      assert_equal(%W{foo bar baz}[calls_to_each], chunk)
      calls_to_each += 1
    end
    
    finished = false
    body.on_eof do
      assert_equal(3, calls_to_each)
      finished = true
    end
    
    until finished
      sleep 0.01 # if we get stuck here body.on_eof was never called
    end
  end
  
  def test_mongrel
    status, headers, body = @async_app.call(@env)
    
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