defmodule ExRTCP.Packet.TransportFeedback.CCTest do
  use ExUnit.Case, async: true

  alias ExRTCP.Packet.TransportFeedback.CC
  alias ExRTCP.Packet.TransportFeedback.CC.{RunLength, StatusVector}

  @sender_ssrc 123_321
  @media_ssrc 112_231
  @base_sequence_number 50_001
  @reference_time -54_000
  @fb_pkt_count 36

  describe "decode/2" do
    test "valid packet with mixed chunk types" do
      # run length chunk (34 packets with small delta)
      chunk_1_count = 32
      raw_chunk_1 = <<0::1, 1::2, chunk_1_count::13>>
      raw_deltas_1 = for i <- 1..chunk_1_count, do: <<i>>, into: <<>>

      chunk_1 = %RunLength{status_symbol: :small_delta, run_length: chunk_1_count}
      deltas_1 = for <<i <- raw_deltas_1>>, do: i

      # status vector chunk (mixed packets, two-bit symbols)
      raw_chunk_2 = <<1::1, 1::1, 2::2, 1::2, 2::2, 0::8>>
      raw_deltas_2 = <<1234::16, 109, 5501::16>>

      symbols = [:large_delta, :small_delta, :large_delta] ++ List.duplicate(:not_received, 4)
      chunk_2 = %StatusVector{symbols: symbols}
      deltas_2 = [1234, 109, 5501]

      total_packet_count = chunk_1_count + 7
      # need 1 byte of padding
      raw_packet = <<
        @sender_ssrc::32,
        @media_ssrc::32,
        @base_sequence_number::16,
        total_packet_count::16,
        @reference_time::signed-24,
        @fb_pkt_count::8,
        raw_chunk_1::binary,
        raw_deltas_1::binary,
        raw_chunk_2::binary,
        raw_deltas_2::binary,
        0
      >>

      assert {:ok, packet} = CC.decode(raw_packet, 15)

      assert %CC{
               sender_ssrc: @sender_ssrc,
               media_ssrc: @media_ssrc,
               base_sequence_number: @base_sequence_number,
               packet_status_count: ^total_packet_count,
               reference_time: @reference_time,
               fb_pkt_count: @fb_pkt_count,
               packet_chunks: [^chunk_1, ^chunk_2],
               recv_deltas: deltas
             } = packet

      assert deltas == deltas_1 ++ deltas_2
    end
  end
end