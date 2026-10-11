package rnn_pkg;
  // Neural Network Dimensions
  parameter int NUM_FEATURES   = 16;   // Number of input features per frame (Nin)
  parameter int HIDDEN_UNITS   = 16;   // Hidden state size for GRU (Nhidden)
  
  // Data Precision
  parameter int WEIGHT_WIDTH   = 8;    // INT8 signed weights (-128 to +127)[cite: 2]
  parameter int DATA_WIDTH     = 16;   // INT16 Q8.8 fixed-point activations/states[cite: 2]
  
  // Register Map Offsets (Byte Addresses)
  parameter logic [11:0] ADDR_ENABLE     = 12'h000;
  parameter logic [11:0] ADDR_FLUSH      = 12'h004;
  parameter logic [11:0] ADDR_THRESHOLD  = 12'h008;
  parameter logic [11:0] ADDR_WINDOW_LEN = 12'h00C;
  parameter logic [11:0] ADDR_STATUS     = 12'h010;
  parameter logic [11:0] ADDR_W_ADDR     = 12'h014;
  parameter logic [11:0] ADDR_W_DATA     = 12'h018;
  
  // Status States
  parameter logic [1:0] STATUS_IDLE      = 2'b00;
  parameter logic [1:0] STATUS_BUSY      = 2'b01;
  parameter logic [1:0] STATUS_DONE      = 2'b10;
endpackage
