# =====================================================================
# SDC Constraints for Voice Stability Monitor (PS-01)
# Target Clock: 50 MHz (Period: 20.0 ns) for Low-Power Edge
# =====================================================================

current_design voice_stability_monitor_top

# ---------------------------------------------------------------------
# 1. Primary Clock Definition
# ---------------------------------------------------------------------
create_clock -name clk -period 20.0 -waveform {0.0 10.0} [get_ports clk]

# Clock uncertainty (jitter + margin) and transition
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

# ---------------------------------------------------------------------
# 2. Input and Output Delays
# ---------------------------------------------------------------------
# Setup Delays (-max): 20% of clock cycle = 4.0 ns
# Hold Delays  (-min): 5% of clock cycle = 1.0 ns (Input), -0.5 ns (Output)
set input_delay_max   4.0
set input_delay_min   1.0

set output_delay_max  4.0
set output_delay_min -0.5

# --- AXI-Stream Slave Interface ---
set_input_delay  -clock clk -max $input_delay_max [get_ports {s_axis_tdata[*] s_axis_tvalid s_axis_tlast}]
set_input_delay  -clock clk -min $input_delay_min [get_ports {s_axis_tdata[*] s_axis_tvalid s_axis_tlast}]

set_output_delay -clock clk -max $output_delay_max [get_ports s_axis_tready]
set_output_delay -clock clk -min $output_delay_min [get_ports s_axis_tready]

# --- AXI-Lite Register Interface ---
set_input_delay  -clock clk -max $input_delay_max [get_ports {s_sel s_wr s_addr[*] s_wdata[*]}]
set_input_delay  -clock clk -min $input_delay_min [get_ports {s_sel s_wr s_addr[*] s_wdata[*]}]

set_output_delay -clock clk -max $output_delay_max [get_ports {s_rdata[*] s_ack}]
set_output_delay -clock clk -min $output_delay_min [get_ports {s_rdata[*] s_ack}]

# --- Alert Interrupt Output ---
set_output_delay -clock clk -max $output_delay_max [get_ports o_alert_interrupt]
set_output_delay -clock clk -min $output_delay_min [get_ports o_alert_interrupt]

# Asynchronous Reset (treated as false path for timing analysis)
set_false_path -from [get_ports rst_n]

# ---------------------------------------------------------------------
# 3. Environmental and Load Constraints
# ---------------------------------------------------------------------
# Define output capacitive load (5 pF) and input driving cells
set_load 5.0 [get_ports {s_axis_tready s_rdata[*] s_ack o_alert_interrupt}]
set_driving_cell -lib_cell BUFX2 [get_ports {s_axis_tdata[*] s_axis_tvalid s_axis_tlast s_sel s_wr s_addr[*] s_wdata[*] rst_n}]
