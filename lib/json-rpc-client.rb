require 'em-http-request'
require 'json'
require 'addressable/uri'

# This implements a client for JSON-RPC (version 2) calls.
#
# @example Asynchronous
#   wallet      = JsonRpcClient.new('https://wallet.my:8332/')
#   balance_rpc = wallet.getbalance()
#   balance_rpc.callback do |result|
#     puts result # => 90.12345678
#   end
#
#   balance_rpc.errback do |error|
#     puts error
#     # => "JsonRpcClient.Error: Bad method, code: -32601, data: nil"
#   end
#
# @example Synchronous
#   require 'eventmachine'
#   require 'json-rpc-client'
#   require 'fiber'
#
#   EventMachine.run do
#     # To use the syncing behaviour, use it in a fiber.
#     fiber = Fiber.new do
#       article = JsonRpcClient.new(
#         'https://shop.textalk.se/backend/jsonrpc/Article/14284660',
#         {asynchronous_calls: false}
#       )
#       puts article.get({name: true})
#       # => {:name=>{:sv=>"Presentkort 1000 kr", :en=>"Gift certificate 1000 SEK"}}

#       EventMachine.stop
#     end

#     fiber.resume
#   end
#
# @!attribute asynchronous_calls
#   @return [Boolean] If method_missing calls are made asynchronously. Default: true
# @!attribute symbolize_names
#   @return [Boolean] If the result of sync calls should have the names be symbols. Default: true
# @!attribute logger
#   @return [Logger] The logger instance attached to the instance of JsonRpcClient.
#      Should accept method calls to debug, info, warning & error. Use JsonRpcClient.log for logging
class JsonRpcClient
  attr_accessor :asynchronous_calls, :symbolize_names, :logger

  # Invalid JSON was received by the server.
  # An error occurred on the server while parsing the JSON text.
  INVALID_JSON     = -32700
  # The JSON sent is not a valid Request object.
  INVALID_REQUEST  = -32600
  # The method does not exist / is not available.
  METHOD_NOT_FOUND = -32601
  # Invalid method parameter(s).
  INVALID_PARAMS   = -32602
  # Internal JSON-RPC error.
  INTERNAL_ERROR   = -32603

  # Create an instance to call the RPC methods on.
  #
  # @param [String, Addressable::URI, #to_str] service_uri The URI to connect to.
  # @param [Hash] options Options hash to pass to the instance.
  #   See Instance Attribute Details in the documentation for more details on supported options.
  def initialize(service_uri, options = {})
    @uri = Addressable::URI.parse(service_uri)
    @asynchronous_calls = options.has_key?(:asynchronous_calls) ?
      !!options[:asynchronous_calls] :
      true
    @symbolize_names = options.has_key?(:symbolize_names) ? !!options[:symbolize_names] : true
    @logger = options[:logger]
  end

  # Called whenever the current object receives a method call that it does not respond to.
  # Will make a call asynchronously or synchronously depending on asynchronous_calls.
  #
  # @param [String] method the API method, ie get, set.
  # @param [Array]  params the parameters sent with the method call.
  def method_missing(method, *params)
    @asynchronous_calls ? self._call_async(method, params) : self._call_sync(method, params)
  end

  # Makes the call asynchronously and returns a EM::Deferrable.
  # The underscore is there to avoid conflicts with server methods, not to denote a private method.
  #
  # @param [String] method The API method, ie get, set etc.
  # @param [Array, Hash] params The parameters that should be sent along in the post body.
  # @return [EM::Deferrable] The JsonRpcClient::Request as data.
  def _call_async(method, params)
    return Request.new({
      service_uri:     @uri.to_s,
      method:          method,
      params:          params,
      logger:          @logger,
      symbolize_names: @symbolize_names
    });
  end

  # Make the call synchronously, returns the result directly.
  # The underscore is there to avoid conflicts with server methods, not to denote a private method.
  #
  # @param [String]       method The API method, ie get, set etc.
  # @param [Array, Hash]  params The parameters that should be sent along in the post body.
  # @return [Hash]        The result.
  # @raise JsonRpcClient::Error When the request responds with failed status.
  def _call_sync(method, params)
    f = Fiber.current

    request = _call_async(method, params)

    request.callback do |*args|
      # If we happen to be in the calling fiber, return the data directly.
      return args.size == 1 ? args.first : args if f == Fiber.current
      # else, return it to the yield call below (in the correct fiber).
      f.resume(*args)
    end

    request.errback do |error|
      json_rpc_error = Error.new(error[:message], error[:code], error[:data])
      # If we happen to be in the calling fiber, raise the error directly.
      raise json_rpc_error if f == Fiber.current
      # else, return it to the yield call below (in the correct fiber).
      f.resume(json_rpc_error)
    end

    begin
      response = Fiber.yield # will yield and return the data or raise the error.
    rescue FiberError
      raise "To to use the syncing behaviour in JsonRpcClient, the call must be in a fiber."
    end
    raise response if response.kind_of?(Error)
    return response
  end

  # Makes a notify call by just sending a HTTP request and not caring about the response.
  # The underscore is there to avoid conflicts with server methods, not to denote a private method.
  #
  # @param [String]        method The API method, ie get, set etc.
  # @param [Array, Hash]  params The parameters that should be sent along in the post body.
  def _notify(method, params)
    post_body = {
      method:  method,
      params:  params,
      jsonrpc: '2.0'
    }.to_json


    EM::HttpRequest.new(@uri.to_s).post :body => post_body
    self.class.log(:debug, "NOTIFY: #{@uri.to_s} --> #{post_body}", @logger)
  end

  # The logger to be used for an instances if they don't have a logger set on that instance.
  @@default_logger = nil

  # @return The default logger object.
  def self.default_logger()
    @@default_logger
  end

  # Add a default logging instance, that should accept method calls to debug, info, warning & error.
  # Don't use directly, use self.log.
  def self.default_logger=(logger)
    @@default_logger = logger
  end

  # Logging class that takes severity and message. Only logs if a logger is attached.
  #
  # @param [Symbol, String] level The severity, ie a method of a logger, (info, debug, warn, error).
  # @param [String]         message The log message.
  # @param [Logger]         logger An instance of a logger class.
  def self.log(level, message, logger = nil)
    logger = logger || @@default_logger
    logger.send(level.to_sym, message) if logger.respond_to?(level.to_sym)
  end

  # This class corresponds to the JSON-RPC error object gotten from the server.
  # A "faked" instance of this will be thrown for communication errors as well.
  class Error < RuntimeError
    attr_reader :code, :data
    def initialize(msg, code, data)
      super(msg)
      @code = code
      @data = data
    end


    # Returns the contents of the current error object as a string.
    #
    # @return [String]
    def inspect
      %|#{self.class}: #{self.message}, code: #{@code.inspect}, data: #{@data.inspect}|
    end
  end

  # This class makes a single request to the JSON-RPC service as a EventMachine::Deferrable.
  # The deferrable object will give a successful callback in the result-part of the response.
  # A unsuccessful request will set the deferred status as failed, and will not deliver a result
  # only the JSON-RPC error object as a Hash.
  class Request
    include EM::Deferrable

    def initialize(params)
      service_uri = params[:service_uri]
      post_body = {
        method:  params[:method],
        params:  params[:params],
        id:      'jsonrpc',
        jsonrpc: '2.0',
      }.to_json

      http = EM::HttpRequest.new(service_uri).post :body => post_body
      JsonRpcClient.log(:debug, "NEW REQUEST: #{service_uri} --> #{post_body}", params[:logger])

      http.callback do |response|
        begin
          resp = JSON.parse(response.response, {symbolize_names: params[:symbolize_names]})
          JsonRpcClient.log(
            :debug,
            "REQUEST FINISH: #{service_uri} METHOD: #{params[:method]} RESULT: #{resp}",
            params[:logger]
          )

          if resp.has_key?(:error) || resp.has_key?("error")
            JsonRpcClient.log(
              :error,
              "Error in response from #{service_uri}: #{resp[:error]}",
               params[:logger]
            )
            self.set_deferred_status :failed, resp[:error] || resp["error"]
          end
          self.set_deferred_status :succeeded, resp[:result] || resp["result"]
        rescue JSON::ParserError => e
          JsonRpcClient.log(
            :error,
            "Got exception during parsing of #{response}: #{e}",
            params[:logger]
          )

          # Making an error object in the same style as a JSON RPC error.
          set_deferred_status :failed, {
            code:    JsonRpcClient::INVALID_JSON,
            message: e.message,
            data:    e
          }
        end
      end

      http.errback do |response|
        JsonRpcClient.log(:error, "Error in http request: #{response.error}", params[:logger])
        set_deferred_status :failed, {
          code: JsonRpcClient::INVALID_JSON,
          message: response.error
        }
      end

      self
    end
  end
end
