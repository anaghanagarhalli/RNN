module hidden_state_mem
  import rnn_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  i_flush,
  input  logic                  i_we,
  input  logic [3:0]            i_addr,
  input  logic [DATA_WIDTH-1:0] i_data_in,
  output logic [DATA_WIDTH-1:0] o_data_out
);

  // Hidden state storage registers (16 units)
  logic [DATA_WIDTH-1:0] state_mem [0:HIDDEN_UNITS-1];

 always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Asynchronous System Reset
        for (int i = 0; i < HIDDEN_UNITS; i++) begin
            state_mem[i] <= '0;
        end
    end else if (i_flush) begin
        // Synchronous Flush
        for (int i = 0; i < HIDDEN_UNITS; i++) begin
            state_mem[i] <= '0;
        end
    end else if (i_we) begin
        // Normal Register Update mapping correctly to the port list
        state_mem[i_addr] <= i_data_in;
    end
  end

  assign o_data_out = state_mem[i_addr];

endmodule
