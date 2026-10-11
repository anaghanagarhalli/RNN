module axi_stream_receiver
  import rnn_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  
  // AXI-Stream Slave Interface
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic                  s_axis_tvalid,
  output logic                  s_axis_tready,
  input  logic                  s_axis_tlast,
  
  // Accelerator Core Interface
  output logic [DATA_WIDTH-1:0] o_feature_data,
  output logic                  o_feature_valid,
  input  logic                  i_core_ready,
  output logic                  o_frame_complete
);

  // Counter to track features per frame (up to 16 features)
  logic [3:0] feature_count;
  logic       accept_handshake;

  assign accept_handshake = s_axis_tvalid && s_axis_tready;
  
  // Ready is asserted when the core is ready to ingest features
  assign s_axis_tready = i_core_ready;

  // Pass-through datapath to core
  assign o_feature_data  = s_axis_tdata;
  assign o_feature_valid = accept_handshake;

  // Frame tracking logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      feature_count    <= 4'd0;
      o_frame_complete <= 1'b0;
    end else begin
      o_frame_complete <= 1'b0;
      
      if (accept_handshake) begin
        if (s_axis_tlast || (feature_count == NUM_FEATURES - 1)) begin
          feature_count    <= 4'd0;
          o_frame_complete <= 1'b1;
        end else begin
          feature_count <= feature_count + 1'b1;
        end
      end
    end
  end

endmodule
