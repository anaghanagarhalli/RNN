module activation_lut
  import rnn_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [DATA_WIDTH-1:0] i_data_in,
  input  logic                  i_sel_tanh, // 0 = Sigmoid, 1 = Tanh
  output logic [DATA_WIDTH-1:0] o_data_out
);

  // 256-entry ROM arrays for Sigmoid and Tanh (INT16 Q8.8)
  logic [DATA_WIDTH-1:0] sigmoid_rom [0:255];
  logic [DATA_WIDTH-1:0] tanh_rom    [0:255];

  // Index mapping (extracting top bits of input to map to 256 entries)
  logic [7:0] lut_index;
  assign lut_index = i_data_in[11:4] + 8'd128; // Center signed range around index 128

  // Initialize ROM arrays from memory files in the data/ directory
  // synopsys translate_off
  initial begin
    $readmemh("../data/sigmoid_lut.mem", sigmoid_rom);
    $readmemh("../data/tanh_lut.mem", tanh_rom);
  end
  // synopsys translate_on

  // Synchronous LUT Lookup
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_data_out <= 16'sd0;
    end else begin
      if (i_sel_tanh) begin
        o_data_out <= tanh_rom[lut_index];
      end else begin
        o_data_out <= sigmoid_rom[lut_index];
      end
    end
  end

endmodule
