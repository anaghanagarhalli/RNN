module rnn_compute_engine
  import rnn_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  i_enable,
  input  logic                  i_frame_start,
  
  input  logic [DATA_WIDTH-1:0] i_feature_data,
  input  logic                  i_feature_valid,
  
  input  logic [7:0]            i_weight_data,
  output logic [11:0]           o_weight_addr,
  
  output logic [DATA_WIDTH-1:0] o_hidden_state,
  output logic                  o_compute_done,
  output logic [3:0]            o_hidden_idx,
  output logic                  o_overflow_flag // NEW: Fault flag output
);

  typedef enum logic [2:0] {
    IDLE               = 3'b000,
    LOAD_VECTORS       = 3'b001,
    MAC_COMPUTE_UPDATE = 3'b010,
    MAC_COMPUTE_RESET  = 3'b011,
    STATE_UPDATE       = 3'b100,
    DONE               = 3'b101
  } state_t;

  state_t current_state, next_state;

  logic [3:0]         feature_idx;
  logic [3:0]         hidden_idx;
  logic signed [31:0] mac_accumulator;
  logic signed [15:0] pre_activation_reg;
  
  // NEW: Combinational MAC product and sum for saturation checking
  logic signed [31:0] mac_product;
  logic signed [31:0] next_mac_val;
  
  assign mac_product  = $signed(i_feature_data) * $signed(i_weight_data);
  assign next_mac_val = mac_accumulator + mac_product;

  assign o_hidden_idx  = hidden_idx;
  assign o_weight_addr = {4'b0000, hidden_idx} * NUM_FEATURES + {8'b0000_0000, feature_idx};

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else if (!i_enable) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE:               if (i_frame_start) next_state = LOAD_VECTORS;
      LOAD_VECTORS:       if (i_feature_valid) next_state = MAC_COMPUTE_UPDATE;
      MAC_COMPUTE_UPDATE: if (feature_idx == NUM_FEATURES - 1) next_state = MAC_COMPUTE_RESET;
      MAC_COMPUTE_RESET:  if (hidden_idx == HIDDEN_UNITS - 1) next_state = STATE_UPDATE; else next_state = MAC_COMPUTE_UPDATE;
      STATE_UPDATE:       next_state = DONE;
      DONE:               next_state = IDLE;
      default:            next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      feature_idx        <= 4'd0;
      hidden_idx         <= 4'd0;
      mac_accumulator    <= 32'sd0;
      pre_activation_reg <= 16'sd0;
      o_compute_done     <= 1'b0;
      o_overflow_flag    <= 1'b0; // Reset flag
    end else begin
      o_compute_done <= 1'b0;
      
      case (current_state)
        IDLE: begin
          feature_idx     <= 4'd0;
          hidden_idx      <= 4'd0;
          mac_accumulator <= 32'sd0;
        end

        LOAD_VECTORS: begin
          feature_idx <= 4'd0;
        end

        MAC_COMPUTE_UPDATE: begin
          if (i_feature_valid) begin
            feature_idx <= feature_idx + 1'b1;
            // NEW: Saturation Arithmetic clamping to 16-bit boundaries
            if (next_mac_val > 32'sd32767) begin
              mac_accumulator <= 32'sd32767;
              o_overflow_flag <= 1'b1;
            end else if (next_mac_val < -32'sd32768) begin
              mac_accumulator <= -32'sd32768;
              o_overflow_flag <= 1'b1;
            end else begin
              mac_accumulator <= next_mac_val;
            end
          end
        end

        MAC_COMPUTE_RESET: begin
          feature_idx <= 4'd0;
          if (hidden_idx < HIDDEN_UNITS - 1) begin
            hidden_idx      <= hidden_idx + 1'b1;
            mac_accumulator <= 32'sd0;
          end
        end

        STATE_UPDATE: begin
          // Direct extraction since we are saturating to 16-bit during accumulation
          pre_activation_reg <= mac_accumulator[15:0]; 
          hidden_idx         <= 4'd0;
        end

        DONE: begin
          o_compute_done  <= 1'b1;
          mac_accumulator <= 32'sd0;
        end
      endcase
    end
  end

  assign o_hidden_state = pre_activation_reg;

endmodule
