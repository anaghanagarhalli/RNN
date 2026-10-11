module tb_top;
  import rnn_pkg::*;

  // Clock and Reset Signals
  logic clk;
  logic rst_n;

  // Interface Signals
  logic        s_sel, s_wr;
  logic [11:0] s_addr;
  logic [31:0] s_wdata, s_rdata;
  logic        s_ack;

  logic        o_enable, o_flush_pulse, o_weight_wr_en;
  logic [15:0] o_threshold;
  logic [3:0]  o_window_len;
  logic [1:0]  i_status;
  logic [11:0] o_weight_addr;
  logic [7:0]  o_weight_data;

  logic [DATA_WIDTH-1:0] s_axis_tdata;
  logic                  s_axis_tvalid, s_axis_tready, s_axis_tlast;
  logic [DATA_WIDTH-1:0] o_feature_data;
  logic                  o_feature_valid, i_core_ready, o_frame_complete;

  // Clock Generation (100 MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // Reset and Stimulus Sequence
  initial begin
    rst_n = 0;
    i_status = STATUS_IDLE;
    i_core_ready = 1'b1;
    s_sel = 0; s_wr = 0; s_addr = 0; s_wdata = 0;
    s_axis_tdata = 0; s_axis_tvalid = 0; s_axis_tlast = 0;
    #25 rst_n = 1;
    
    // 1. Simple Stimulus Example: Write Threshold
    #20;
    @(posedge clk);
    s_sel = 1; s_wr = 1; s_addr = ADDR_THRESHOLD; s_wdata = 32'h0123;
    @(posedge clk);
    s_sel = 0; s_wr = 0;

    // 2. Test Flush Pulse
    #20;
    @(posedge clk);
    s_sel = 1; s_wr = 1; s_addr = ADDR_FLUSH; s_wdata = 32'h1;
    @(posedge clk);
    s_sel = 0; s_wr = 0;

    // 3. Stream a full frame of features via AXI-Stream (16 features with proper TLAST)
    #30;
    @(posedge clk);
    for (int i = 0; i < NUM_FEATURES; i++) begin
      s_axis_tvalid = 1'b1;
      s_axis_tdata  = 16'h0A00 + i; // Dummy feature data values
      
      // Explicitly assert TLAST on the 16th (final) feature of the frame
      s_axis_tlast  = (i == NUM_FEATURES - 1) ? 1'b1 : 1'b0; 
      
      // Wait for handshake (TVALID & TREADY)
      do begin
        @(posedge clk);
      end while (!(s_axis_tvalid && s_axis_tready));
    end
    
    // Clear AXI-Stream signals cleanly after frame transfer
    @(posedge clk);
    s_axis_tvalid = 1'b0;
    s_axis_tlast  = 1'b0;
    s_axis_tdata  = 16'h0000;

    #100;
    $finish;
  end

  // DUT 1: Register File
  reg_file u_reg_file (
    .clk(clk), .rst_n(rst_n),
    .s_sel(s_sel), .s_wr(s_wr), .s_addr(s_addr),
    .s_wdata(s_wdata), .s_rdata(s_rdata), .s_ack(s_ack),
    .o_enable(o_enable), .o_flush_pulse(o_flush_pulse),
    .o_threshold(o_threshold), .o_window_len(o_window_len),
    .i_status(i_status), .o_weight_addr(o_weight_addr),
    .o_weight_data(o_weight_data), .o_weight_wr_en(o_weight_wr_en)
  );

  // DUT 2: AXI-Stream Receiver
  axi_stream_receiver u_axi_receiver (
    .clk(clk), .rst_n(rst_n),
    .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast),
    .o_feature_data(o_feature_data), .o_feature_valid(o_feature_valid),
    .i_core_ready(i_core_ready), .o_frame_complete(o_frame_complete)
  );

  // Bind Assertion Checkers
  bind axi_stream_receiver axi_stream_sva u_axi_sva (
    .clk(clk), .rst_n(rst_n),
    .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast),
    .o_frame_complete(o_frame_complete)
  );

  bind reg_file reg_file_sva u_reg_sva (
    .clk(clk), .rst_n(rst_n),
    .s_sel(s_sel), .s_wr(s_wr), .s_addr(s_addr),
    .s_wdata(s_wdata), .o_flush_pulse(o_flush_pulse)
  );

endmodule
