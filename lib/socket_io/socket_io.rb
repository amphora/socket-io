# frozen_string_literal: true

module SocketIO
  class SocketIO
    include EventEmitter
    Packet = Struct.new(:type, :namespace, :payload, :ack_id, keyword_init: true) do
      def encode_packet
        encoded_type = PacketTypes::PACKET_MAP[type]
        encoded_namespace = (namespace == "/") ? "" : "#{namespace},"
        encoded_payload = JSON.dump(payload || {})
        "#{encoded_type}#{ack_id}#{encoded_namespace}#{encoded_payload}"
      end

      def self.decode_packet(data)
        type = PacketTypes::INVERTED_PACKET_MAP[data[0].to_i]

        i = 1
        while data[i] =~ /[0-9]/
          i += 1
        end
        ack_id = data[1..i].to_i

        if data[i] == "/"
          j = i + 1
          while data[j] != ","
            j += 1
          end
          namespace = data[i + 1..j - 1]
          i = j
        else
          namespace = "/"
        end

        payload = JSON.parse(data[i..])
        Packet.new(
          type: type,
          namespace: namespace,
          payload: payload,
          ack_id: ack_id
        )
      end
    end

    module PacketTypes
      CONNECT = :connect
      DISCONNECT = :disconnect
      EVENT = :event
      ACK = :ack
      ERROR = :error
      BINARY_EVENT = :binary_event
      BINARY_ACK = :binary_ack

      PACKET_MAP = {
        connect: 0,
        disconnect: 1,
        event: 2,
        ack: 3,
        error: 4,
        binary_event: 5,
        binary_ack: 6
      }

      INVERTED_PACKET_MAP = PACKET_MAP.invert
    end

    attr_reader :engine

    def initialize(url, debug_logging: false)
      super()
      @engine = EngineIO.new(url, debug_logging: debug_logging)
      @sid = {}
      @ack_counter = 1

      @engine.on :open do
        send_packet(Packet.new(type: PacketTypes::CONNECT, namespace: "/"))
      end

      @engine.on :message do |data|
        packet = Packet.decode_packet(data)
        receive_packet(packet)
      end
    end

    def close
      @engine.close
    end

    def send_packet(packet, with_ack: false)
      if with_ack
        packet.ack_id = @ack_counter
        @ack_counter += 1
      end

      @engine.send_message(packet.encode_packet)
      packet.ack_id
    end

    def connected?
      @connected
    end

    def can_make_progress?
      @engine.can_make_progress?
    end

    private

    def receive_packet(packet)
      if packet.ack_id
        send_packet(Packet.new(type: PacketTypes::ACK, namespace: packet.namespace, payload: [], ack_id: packet.ack_id))
      end

      case packet
      in Packet[PacketTypes::CONNECT, namespace, data, _]
        @sid[namespace] = data["sid"]
        emit(:connect)
        @connected = true
      in Packet[PacketTypes::DISCONNECT, namespace, data, _]
        emit(:disconnect)
      in Packet[PacketTypes::EVENT, namespace, data, ack_id]
        emit(:message, namespace, data)
      in Packet[PacketTypes::ACK, namespace, data, ack_id]
        emit(:"ack_#{ack_id}", namespace, data)
        emit(:ack, ack_id, namespace, data)
      else
        nil
      end
    end
  end
end
