module reg_file
  import rnn_pkg::*;
(
  input  logic                 clk,
  input  logic                 rst_n,
  
  // AXI-Lite / Simple Bus Interface for Register Access
  input  logic                 s_sel,
  input  logic                 s_wr,
  input  logic [11:0]          s_addr,
  input  logic [31:0]          s_wdata,
  output logic [31:0]          s_rdata,
  output logic                 s_ack,
  
  // Internal Control & Status Outputs
  output logic                 o_enable,
  output logic                 o_flush_pulse,
  output logic [15:0]          o_threshold,
  output logic [3:0]           o_window_len,
  input  logic [1:0]           i_status,
  input  logic                 i_overflow_flag, // NEW: Fault handling flag
  output logic [11:0]          o_weight_addr,
  output logic [7:0]           o_weight_data,
  output logic                 o_weight_wr_en
);

  // Internal Register Storage
  logic        r_enable;
  logic        r_flush;
  logic [15:0] r_threshold;
  logic [3:0]  r_window_len;
  logic [11:0] r_weight_addr;
  logic [7:0]  r_weight_data;
  logic        weight_wr_trigger;

  // Self-clearing flush pulse logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_enable      <= 1'b0;
      r_flush       <= 1'b0;
      r_threshold   <= 16'h0000;
      r_window_len  <= 4'h3;
      r_weight_addr <= 12'h000;
      r_weight_data <= 8'h00;
      weight_wr_trigger <= 1'b0;
    end else begin
      r_flush <= 1'b0;
      weight_wr_trigger <= 1'b0;

      if (s_sel && s_wr) begin
        case (s_addr)
          ADDR_ENABLE:     r_enable      <= s_wdata[0];
          ADDR_FLUSH:      r_flush       <= s_wdata[0]; 
          ADDR_THRESHOLD:  r_threshold   <= s_wdata[15:0];
          ADDR_WINDOW_LEN: r_window_len  <= s_wdata[3:0];
          ADDR_W_ADDR:     r_weight_addr <= s_wdata[11:0];
          ADDR_W_DATA:     begin
                             r_weight_data     <= s_wdata[7:0];
                             weight_wr_trigger <= 1'b1; 
                           end
          default: ;
        endcase
      end
    end
  end

  // Read Multiplexer
  always_comb begin
    s_rdata = 32'h0;
    s_ack   = s_sel;
    if (s_sel && !s_wr) begin
      case (s_addr)
        ADDR_ENABLE:     s_rdata = {31'h0, r_enable};
        ADDR_FLUSH:      s_rdata = {31'h0, r_flush};
        ADDR_THRESHOLD:  s_rdata = {16'h0, r_threshold};
        ADDR_WINDOW_LEN: s_rdata = {28'h0, r_window_len};
        // NEW: Map overflow flag to bit 2 of the Status Register
        ADDR_STATUS:     s_rdata = {29'h0, i_overflow_flag, i_status}; 
        ADDR_W_ADDR:     s_rdata = {20'h0, r_weight_addr};
        ADDR_W_DATA:     s_rdata = {24'h0, r_weight_data};
        default:         s_rdata = 32'h0;
      endcase
    end
  end

  assign o_enable       = r_enable;
  assign o_flush_pulse  = r_flush;
  assign o_threshold    = r_threshold;
  assign o_window_len   = r_window_len;
  assign o_weight_addr  = r_weight_addr;
  assign o_weight_data  = r_weight_data;
  assign o_weight_wr_en = weight_wr_trigger;

endmodule
