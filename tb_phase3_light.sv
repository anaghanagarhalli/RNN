`timescale 1ns / 1ps

module tb_phase3_light;

    // -------------------------------------------------------------------------
    // Clock and Reset Generation
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock for low-power edge target
    end

    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    logic [11:0] s_addr;
    logic [31:0] s_wdata;
    logic        s_wr;
    logic        s_sel;
    logic [31:0] s_rdata;
    logic        s_ack;

    logic [15:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tlast;
    logic        s_axis_tready;
    logic        o_alert_interrupt;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    voice_stability_monitor_top u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_addr(s_addr),
        .s_wdata(s_wdata),
        .s_wr(s_wr),
        .s_sel(s_sel),
        .s_rdata(s_rdata),
        .s_ack(s_ack),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        .o_alert_interrupt(o_alert_interrupt)
    );

    // -------------------------------------------------------------------------
    // Initialization, Reset, Novelty Config, and VCD Dump
    // -------------------------------------------------------------------------
    initial begin
        // Setup Switching Activity Dump for Cadence Genus Power Estimation
        $dumpfile("power_activity.vcd");
        $dumpvars(0, tb_phase3_light);

        // Initialize signals
        rst_n         = 0;
        s_addr        = 12'h000;
        s_wdata       = 32'h00000000;
        s_wr          = 0;
        s_sel         = 0;
        s_axis_tdata  = 16'h0000;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;

        // Apply Asynchronous Reset
        #50;
        rst_n = 1;
        #20;
        
        // --- 1. Enable Core via AXI-Lite (Addr: 0x000) ---
        @(posedge clk);
        s_addr  = 12'h000;
        s_wdata = 32'h00000001;
        s_wr    = 1;
        s_sel   = 1;
        @(posedge clk);
        s_wr    = 0;
        s_sel   = 0;

        // --- 2. Configure Novelty Silence Threshold (Addr: 0x01C) ---
        @(posedge clk);
        s_addr  = 12'h01C; 
        s_wdata = 32'h00000020; // Silence cutoff threshold
        s_wr    = 1;
        s_sel   = 1;
        @(posedge clk);
        s_wr    = 0;
        s_sel   = 0;

        // --- 3. Stream Mixed Active and Silent Frames for Power Profiling ---
        #30;
        for (int frame = 0; frame < 5; frame++) begin
            for (int i = 0; i < 16; i++) begin
                @(posedge clk);
                s_axis_tvalid = 1;
                // Alternate between active voice frames and zero-energy silent frames
                if (frame % 2 == 0)
                    s_axis_tdata = (i == 0) ? 16'h0A00 : 16'h0012; // Active energy (> 0x20)
                else
                    s_axis_tdata = (i == 0) ? 16'h0005 : 16'h0001; // Silent energy (< 0x20)
                
                s_axis_tlast  = (i == 15) ? 1 : 0;
                
                // Wait for core handshake ready
                wait(s_axis_tready);
            end
        end

        @(posedge clk);
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;

        #10000;
        $finish;
    end

endmodule
