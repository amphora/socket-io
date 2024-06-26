# frozen_string_literal: true

require "faye/websocket"
require "eventmachine"

require_relative "socket_io/version"
require_relative "socket_io/event_emitter"
require_relative "socket_io/engine_io"
require_relative "socket_io/socket_io"

module SocketIO
  class Error < StandardError; end

  class TimeoutError < Error; end

  # Raised when the emitter can make no more progress and is finished, for example if the websocket is closed
  class UnexpectedEmitterFinishError < Error; end
end
