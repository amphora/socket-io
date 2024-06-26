# frozen_string_literal: true

require "faye/websocket"
require "eventmachine"

module SocketIO
  class EngineIO
    include EventEmitter
    module PacketTypes
      OPEN = :open
      CLOSE = :close
      PING = :ping
      PONG = :pong
      MESSAGE = :message
      UPGRADE = :upgrade
      NOOP = :noop

      PACKET_MAP = {
        open: 0,
        close: 1,
        ping: 2,
        pong: 3,
        message: 4,
        upgrade: 5,
        noop: 6
      }

      INVERTED_PACKET_MAP = PACKET_MAP.invert
    end

    Packet = Struct.new(:type, :data) do
      def encode_packet
        "#{PacketTypes::PACKET_MAP[type]}#{data}"
      end

      def self.decode_packet(data)
        type = data[0].to_i
        Packet.new(PacketTypes::INVERTED_PACKET_MAP[type], data[1..])
      end
    end
    attr_reader :thread, :ws

    def initialize(hostname, debug_logging: false)
      super()

      @debug_logging = debug_logging
      @thread = Thread.new do
        EM.run do
          @ws = Faye::WebSocket::Client.new("ws://#{hostname}/socket.io/?EIO=4&transport=websocket")

          @ws.on :open do
            puts "Raw WS is open"
          end

          @ws.on :close do
            puts "Raw WS closed"
            emit(:close)
            EM.stop_event_loop
          end

          @ws.on :message do |event|
            packet = Packet.decode_packet(event.data)
            receive_packet(packet)
          end
        end
      end
    end

    def close
      send_packet(Packet[PacketTypes::CLOSE])
      @ws.close
      @thread.join
    end

    def receive_packet(packet)
      p [:engine, :recv, packet] if @debug_logging
      case packet.type
      when PacketTypes::OPEN
        emit(:open)
      when PacketTypes::CLOSE
        emit(:close)
        @ws.close
      when PacketTypes::PING
        send_packet(Packet[PacketTypes::PONG])
      when PacketTypes::MESSAGE
        emit(:message, packet.data)
      end
    end

    def send_message(data)
      send_packet(Packet[PacketTypes::MESSAGE, data])
    end

    def send_packet(packet)
      p [:engine, :send, packet] if @debug_logging
      @ws.send(packet.encode_packet)
    end

    def can_make_progress?
      @ws.ready_state != Faye::WebSocket::API::CLOSED
    end
  end
end
