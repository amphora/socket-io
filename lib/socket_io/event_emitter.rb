# frozen_string_literal: true
require 'faye/websocket'

module SocketIO
  module EventEmitter
    include WebSocket::Driver::EventEmitter

    def once(event, callable = nil, &block)
      listener = callable || block

      our_listener = add_listener event do |*args|
        listener.call(args)
        remove_listener(event, our_listener)
      end
    end

    def wait_for(method)
      returned = nil
      once(method) do |*data|
        returned = data
      end

      yield if block_given?

      block_until { !returned.nil? }
      returned
    end

    protected

    # Blocks until the given block returns true, or until the timeout is reached
    # @param [Float] timeout The maximum number of seconds to wait before raising an error
    def block_until(timeout: 5, &block)
      init_time = Time.now
      until yield
        sleep 0.1
        raise(TimeoutError, "Timed out waiting for block to return true") if Time.now - init_time > timeout
      end
    end
  end
end