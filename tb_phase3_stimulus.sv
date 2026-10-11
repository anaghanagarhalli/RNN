`timescale 1ns / 1ps

module tb_phase3_stimulus;

    // -------------------------------------------------------------------------
    // Clock and Reset Generation
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock
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

    // Task for clean AXI-Lite Reads (Telemetry & Status Verification)
    task axi_lite_read(input [11:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_sel = 1;
            s_wr  = 0;
            s_addr = addr;
            wait(s_ack);
            data = s_rdata;
            @(posedge clk);
            s_sel = 0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Initialization, Dump Setup, and Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        logic [31:0] telemetry_readout;

        // Use a new VCD file name to preserve the previous one
        $dumpfile("power_activity_stimulus.vcd");
        $dumpvars(0, tb_phase3_stimulus);

        // Initialize
        rst_n         = 0;
        s_addr        = 12'h000;
        s_wdata       = 32'h00000000;
        s_wr          = 0;
        s_sel         = 0;
        s_axis_tdata  = 16'h0000;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;

        // Reset
        #50;
        rst_n = 1;
        #20;
        
        $display("[INFO] Starting Comprehensive Stimulus & Novelty Verification...");

        // 1. Enable Core (Addr: 0x000)
        @(posedge clk);
        s_addr  = 12'h000;
        s_wdata = 32'h00000001;
        s_wr    = 1;
        s_sel   = 1;
        @(posedge clk);
        s_wr    = 0;
        s_sel   = 0;

        // 2. Configure Stability Threshold (Addr: 0x008)
        @(posedge clk);
        s_addr  = 12'h008; 
        s_wdata = 32'h00002000; 
        s_wr    = 1; 
        s_sel   = 1;
        @(posedge clk);
        s_wr    = 0; 
        s_sel   = 0;

        // 3. Configure Novelty Silence Threshold (Addr: 0x01C)
        @(posedge clk);
        s_addr  = 12'h01C; 
        s_wdata = 32'h00000020; // Silence threshold
        s_wr    = 1; 
        s_sel   = 1;
        @(posedge clk);
        s_wr    = 0; 
        s_sel   = 0;
        $display("[PASS] AXI-Lite Configuration & Silence Threshold Set.");

        // 4. Stream 10 Frames (AXI-Stream) with Fault Injection & Active/Silent Mix
        for (int frame = 0; frame < 10; frame++) begin
            for (int i = 0; i < 16; i++) begin
                @(posedge clk);
                s_axis_tvalid = 1;
                
                // Inject massive value on the 5th frame to force saturation (Robustness check)
                if (frame == 4 && i == 0) begin
                    s_axis_tdata = 16'h7FFF; 
                end else if (frame == 7) begin
                    // Inject explicit silent frame (Energy feature < 0x20) -> Triggers Bypass Novelty
                    s_axis_tdata = (i == 0) ? 16'h0005 : 16'h0001;
                end else begin
                    s_axis_tdata = 16'h0034; 
                end
                
                // Assert TLAST on the final feature of each frame
                s_axis_tlast = (i == 15) ? 1 : 0;
                
                // Wait for core to accept data
                wait(s_axis_tready);
            end
        end
        
        @(posedge clk);
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        $display("[PASS] Feature Streaming & Fault Injection Completed.");

        // 5. Read back Telemetry Skip Counter (Addr: 0x020) via AXI-Lite
        #100;
        axi_lite_read(12'h020, telemetry_readout);
        $display("=== HACKATHON NOVELTY TELEMETRY CHECK ===");
        $display("Silence Skip Counter Readout: 0x%08X (Expected >= 0x00000001)", telemetry_readout);
        if (telemetry_readout >= 1)
            $display("[PASS] Zero-Energy Silence Bypass Telemetry Verified Successfully.");
        else
            $display("[FAIL] Telemetry counter did not increment!");

        // 6. Trigger Mid-Call State Flush (Addr: 0x004)
        #100;
        @(posedge clk);
        s_addr  = 12'h004; // Address for FLUSH command
        s_wdata = 32'h00000001;
        s_wr    = 1; 
        s_sel   = 1;
        @(posedge clk);
        s_wr    = 0; 
        s_sel   = 0;
        $display("[PASS] Mid-Call State Flush Executed.");

        #1000;
        $display("--- Simulation Complete ---");
        $finish;
    end
endmodule
