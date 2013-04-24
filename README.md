Asynchronous (EventMachine) JSON-RPC 2.0 client
===============================================

[![Gem Version](https://badge.fury.io/rb/json-rpc-client.png)]
(http://badge.fury.io/rb/json-rpc-client)
[![Build Status](https://travis-ci.org/Textalk/json-rpc-client-ruby.png?branch=master)]
(https://travis-ci.org/Textalk/json-rpc-client-ruby)
[![Code Climate](https://codeclimate.com/github/Textalk/json-rpc-client-ruby.png)]
(https://codeclimate.com/github/Textalk/json-rpc-client-ruby)

This gem is a client implementation for JSON-RPC 2.0. It uses EventMachine to
enable asynchronous communication with a JSON-RPC server. It can be used synchronously if
called within a (non-root) fiber.

Usage example for asynchronous behaviour:
```Ruby
wallet      = JsonRpcClient.new('https://localhost:8332/') # Local bitcoin wallet
balance_rpc = wallet.getbalance()
balance_rpc.callback do |result|
  puts result # => 90.12345678
end

balance_rpc.errback do |error|
  puts error
  # => "JsonRpcClient.Error: Bad method, code: -32601, data: nil"
end
```

Usage example for synchronous behaviour:
```Ruby
require 'eventmachine'
require 'json-rpc-client'
require 'fiber'

EventMachine.run do
  # To use the syncing behaviour, use it in a fiber.
  fiber = Fiber.new do
    article = JsonRpcClient.new(
      'https://shop.textalk.se/backend/jsonrpc/Article/14284660',
      {asynchronous_calls: false}
    )
    puts article.get({name: true})
    # => {:name=>{:sv=>"Presentkort 1000 kr", :en=>"Gift certificate 1000 SEK"}}

    EventMachine.stop
  end

  fiber.resume
end
```

Logging
-------

The client supports both a default logger (for all instances) and a per instance logger.
Simply attach a logger of your choice(that responds to info, warning, error and debug) and
any interaction will be output as debug, and any errors as errors. Any per instance logger will
override the default logger for that instance.

```Ruby
require 'logger'
JsonRpcClient.default_logger = Logger.new($STDOUT)
wallet = JsonRpcClient.new('https://localhost:8332/') # Local bitcoin wallet
wallet.logger = MyCustomLogger.new()
```

Development
-----------

To set up a development environment, simply do:

```bash
bundle install
bundle exec rake  # run the test suite
```

There are autotests located in the test folder and the framework used is
[Bacon](https://github.com/chneukirchen/bacon). They're all mocked with
[VCR](https://github.com/vcr/vcr)/[Webmock](https://github.com/bblimke/webmock)
so no internet connection is required to run them.

JSON-RPC 2.0
------------

JSON-RPC 2.0 is a very simple protocol for remote procedure calls,
agnostic of carrier (http, websocket, tcp, whatever…).

[JSON-RPC 2.0 Specification](http://www.jsonrpc.org/specification)

Copyright
---------
Copyright (C) 2012-2013, Textalk AB <http://textalk.se/>

JSON-RPC client is freely distributable under the terms of an MIT license. See [LICENCE](LICENSE).
