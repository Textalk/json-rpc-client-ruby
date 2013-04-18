# -*- coding: utf-8 -*-
require 'em-spec/bacon'
require 'vcr'
require 'json'
require File.expand_path(File.dirname(__FILE__) + '/test-helper.rb')
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib/json-rpc-client'))

# Sets up a eventmachine channel to be able to notify subscribers when a http request has been done
# With the async nature and with _notify not returning a Deferrable we can't know if it sent
# Or when it finished it's request, hence why we hook onto after_http_request and use that.
vcr_channel = EventMachine::Channel.new

VCR.configure do |c|
  c.cassette_library_dir = File.expand_path(File.dirname(__FILE__)) + '/vcr_cassettes'
  c.hook_into :webmock
  # After a http request, push a notification in the EM channel with the request and response.
  c.after_http_request do |request, response|
    vcr_channel.push({request: request, response: response})
  end
end

EM.spec_backend = EventMachine::Spec::Bacon
EM.describe 'json-rpc-test' do

  should 'Test default logging' do
    VCR.use_cassette('logger-test') do
      custom_logger = CustomLogger.new()
      JsonRpcClient.default_logger = custom_logger
      client = JsonRpcClient.new('https://shop.textalk.se/backend/jsonrpc/Article/12565607')
      (JsonRpcClient.default_logger == custom_logger).should.equal true
      JsonRpcClient.default_logger = nil #cleanup
    end

    done
  end

  should 'Make a sucessful sync json-rpc call and recieve symbolized values' do
    VCR.use_cassette('sync-symbolized') do
      client = JsonRpcClient.new(
        'https://shop.textalk.se/backend/jsonrpc/Article/12565484',
        {asynchronous_calls: false}
      )
      client.logger = CustomLogger.new()
      uid = client.get(uid: true) # Calling method get on RPC backend, only asking for uid
      client.logger.logs[0] == "NEW REQUEST: https://shop.textalk.se/backend/jsonrpc/Article/12565484 --> {\"method\":\"get\",\"params\":[{\"uid\":true}],\"id\":\"jsonrpc\",\"jsonrpc\":\"2.0\"}"
      client.logger.logs[1] == "REQUEST FINISH: https://shop.textalk.se/backend/jsonrpc/Article/12565484 METHOD: get RESULT: {:jsonrpc=>\"2.0\", :id=>\"jsonrpc\", :result=>{:uid=>\"12565484\"}}"
      (uid == {uid: "12565484"}).should.equal true
    end

    done
  end

  should 'Make a sucessful sync json-rpc call and recieve non-symbolized values' do
    VCR.use_cassette('sync-nonsymbolized') do
      client = JsonRpcClient.new('https://shop.textalk.se/backend/jsonrpc/Article/14284660', {
        asynchronous_calls: false,
        symbolize_names: false
      })
      name = client.get(name: true) # Calling same method, asking for name. Should not symobolize result
      (name == {"name"=>{"sv"=>"Presentkort 1000 kr", "en"=>"Gift certificate 1000 SEK"}}).should.equal true
    end

    done
  end

  should 'Make a sucessful async json-rpc call and recieve a JsonRpcClient::Request' do
      VCR.insert_cassette("async")
      client = JsonRpcClient.new('https://shop.textalk.se/backend/jsonrpc/Article/12565605')
      request = client.uid() # Calling a valid uri, should get a request back
      request.is_a?(JsonRpcClient::Request).should.equal true
      request.is_a?(EM::Deferrable).should.equal true
      request.callback do |result|
        result.should.equal "12565605"
        VCR.eject_cassette
        done
      end
  end

  should 'Make a notify call' do
    VCR.insert_cassette("notify")
    # Subscribe to the EM channel, so that we only after the request do the matching and
    # eject the VCR cassette and end the request.
    subscription = vcr_channel.subscribe do |request_response_hash|
      request = request_response_hash[:request]
      (JSON.parse(request[:body]) == {"method"=>"uid", "params"=>{}, "jsonrpc"=>"2.0"}).should.equal true
      vcr_channel.unsubscribe(subscription) # Unsub from the channel
      VCR.eject_cassette
      done # Exit out of the request
    end
    client = JsonRpcClient.new('https://shop.textalk.se/backend/jsonrpc/Article/12565604')
    client._notify(:uid, {}) # Just shouldn't raise an error, and should hit backend.
  end

  should 'raise jsonrpcerror on bad response' do
    should.raise(JsonRpcClient::Error) do
      VCR.use_cassette('bad-response') do
        client = JsonRpcClient.new('http://www.google.com/', {asynchronous_calls: false})
        client.dummy() # Calling non-existing method on non-rpc backend.
      end
    end

    done
  end

  should 'get an http error and raise jsonrpcerror on bad backend url' do
    should.raise(JsonRpcClient::Error) do
      VCR.use_cassette('weird-url') do
        client = JsonRpcClient.new('http://@ł€®þ.com/', {asynchronous_calls: false})
        client.dummy() # Calling non-existing method on non-rpc backend.
      end
    end

    done
  end

  should 'get a jsonrpcerror from the backend' do
    should.raise(JsonRpcClient::Error) do
      VCR.use_cassette('jsonrpcerror-method-missing') do
        client = JsonRpcClient.new(
          'http://shop.textalk.se/backend/jsonrpc/Foo',
          {asynchronous_calls: false}
        )
        error = client.dummy() # Calling non-existing method on rpc backend.
      end
    end

    done
  end

  should 'test the error inspect method' do
    VCR.use_cassette('inspect') do
      begin
        client = JsonRpcClient.new(
          'http://shop.textalk.se/backend/jsonrpc/Article/12565604',
          {asynchronous_calls: false}
        )
        client.dummy()
      rescue JsonRpcClient::Error => e
        e.inspect.should.equal "JsonRpcClient::Error: Method not found: dummy, code: -32601, data: nil"
      end
    end

    done
  end
end

describe 'Non-fiber' do

  should 'raise an error about no fibers being used' do
    VCR.use_cassette('non-fiber') do
      should.raise(RuntimeError) do
        EM.run do
          client = JsonRpcClient.new(
            'http://shop.textalk.se/backend/jsonrpc/Article/12565604',
            {asynchronous_calls: false}
          )
          client.get()
        end
      end
    end
  end
end
