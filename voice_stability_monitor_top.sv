module voice_stability_monitor_top
  import rnn_pkg::*;
(
  input  logic                clk,
  input  logic                rst_n,
  
  // AXI-Stream Slave Interface
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic                s_axis_tvalid,
  output logic                s_axis_tready,
  input  logic                s_axis_tlast,
  
  // AXI-Lite Register Interface
  input  logic                s_sel,
  input  logic                s_wr,
  input  logic [11:0]         s_addr,
  input  logic [31:0]         s_wdata,
  output logic [31:0]         s_rdata,
  output logic                s_ack,
  
  // Alert Interrupt Output
  output logic                o_alert_interrupt
);

  // Internal Control & Status Signals
  logic        w_enable;
  logic        w_flush_pulse;
  logic [15:0] w_threshold;
  logic [3:0]  w_window_len;
  logic [1:0]  w_status;
  logic        w_overflow_flag; // NEW: Overflow routing wire
  logic [11:0] w_weight_addr;
  logic [7:0]  w_weight_data;
  logic        w_weight_wr_en;

  logic [DATA_WIDTH-1:0] w_feature_data;
  logic                w_feature_valid;
  logic                w_frame_complete;

  logic [DATA_WIDTH-1:0] w_hidden_state;
  logic                w_compute_done;
  logic [DATA_WIDTH-1:0] w_activation_out;
  logic [DATA_WIDTH-1:0] w_state_mem_out;
  logic [3:0]          w_hidden_idx;
  
  logic [7:0]          w_weight_rd_data;
  logic [11:0]         w_compute_weight_addr;
  logic [11:0]         w_effective_weight_addr;

  reg_file u_reg_file (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel(s_sel),
    .s_wr(s_wr),
    .s_addr(s_addr),
    .s_wdata(s_wdata),
    .s_rdata(s_rdata),
    .s_ack(s_ack),
    .o_enable(w_enable),
    .o_flush_pulse(w_flush_pulse),
    .o_threshold(w_threshold),
    .o_window_len(w_window_len),
    .i_status(w_status),
    .i_overflow_flag(w_overflow_flag), // Routed back to register map
    .o_weight_addr(w_weight_addr),
    .o_weight_data(w_weight_data),
    .o_weight_wr_en(w_weight_wr_en)
  );

  logic [7:0] weight_ram [0:2047];

  // synopsys translate_off
  initial begin
    $readmemh("../data/weights.mem", weight_ram);
  end
  // synopsys translate_on

  assign w_effective_weight_addr = w_weight_wr_en ? w_weight_addr : w_compute_weight_addr;

  always_ff @(posedge clk) begin
    if (w_weight_wr_en) begin
      weight_ram[w_weight_addr] <= w_weight_data;
    end
  end
  assign w_weight_rd_data = weight_ram[w_effective_weight_addr];

  axi_stream_receiver u_axi_receiver (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .o_feature_data(w_feature_data),
    .o_feature_valid(w_feature_valid),
    .i_core_ready(w_enable),
    .o_frame_complete(w_frame_complete)
  );

  hidden_state_mem u_hidden_state_mem (
    .clk(clk),
    .rst_n(rst_n),
    .i_flush(w_flush_pulse),
    .i_we(w_compute_done && w_enable),
    .i_addr(w_hidden_idx),
    .i_data_in(w_activation_out),
    .o_data_out(w_state_mem_out)
  );

  rnn_compute_engine u_compute_engine (
    .clk(clk),
    .rst_n(rst_n),
    .i_enable(w_enable),
    .i_frame_start(w_frame_complete),
    .i_feature_data(w_feature_data),
    .i_feature_valid(w_feature_valid),
    .i_weight_data(w_weight_rd_data),        
    .o_weight_addr(w_compute_weight_addr),  
    .o_hidden_state(w_hidden_state),
    .o_compute_done(w_compute_done),
    .o_hidden_idx(w_hidden_idx),
    .o_overflow_flag(w_overflow_flag) // Routed to top level
  );

  activation_lut u_activation_lut (
    .clk(clk),
    .rst_n(rst_n),
    .i_data_in(w_hidden_state),
    .i_sel_tanh(1'b1),
    .o_data_out(w_activation_out)
  );

  post_process_alert u_post_process (
    .clk(clk),
    .rst_n(rst_n),
    .i_stability_score(w_activation_out),
    .i_threshold(w_threshold),
    .i_window_len(w_window_len),
    .o_alert_interrupt(o_alert_interrupt)
  );

  typedef enum logic [1:0] {
    ST_IDLE = 2'b00,
    ST_BUSY = 2'b01,
    ST_DONE = 2'b10
  } status_state_t;

  status_state_t status_current, status_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_current <= ST_IDLE;
    end else if (!w_enable) begin
      status_current <= ST_IDLE;
    end else begin
      status_current <= status_next;
    end
  end

  always_comb begin
    status_next = status_current;
    case (status_current)
      ST_IDLE: if (w_enable && w_frame_complete) status_next = ST_BUSY;
      ST_BUSY: if (w_compute_done) status_next = ST_DONE;
      ST_DONE: if (w_frame_complete) status_next = ST_BUSY;
      default: status_next = ST_IDLE;
    endcase
  end

  always_comb begin
    case (status_current)
      ST_IDLE: w_status = STATUS_IDLE;
      ST_BUSY: w_status = STATUS_BUSY;
      ST_DONE: w_status = STATUS_DONE;
      default: w_status = STATUS_IDLE;
    endcase
  end

endmodule
