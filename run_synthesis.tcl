# =====================================================================
# Cadence Genus Synthesis & Timing Closure Script
# Design: Voice Stability Monitor (PS-01)
# Target: 50 MHz (20.0 ns Period) | Low-Power Edge Implementation
# =====================================================================

# ---------------------------------------------------------------------
# 1. Global Variables & Directory Setup
# ---------------------------------------------------------------------
set TOP_MODULE "voice_stability_monitor_top"

# Automatically create output directories to prevent file write errors
file mkdir output/netlist
file mkdir output/constraints
file mkdir output/reports

# ---------------------------------------------------------------------
# 2. Search Paths & Target Technology Libraries
# ---------------------------------------------------------------------
set_db init_lib_search_path {/home/install/FOUNDRY/digital/90nm/dig/lib}
set_db init_hdl_search_path {.}

# Load standard delay library (slow corner for worst-case setup analysis)
read_libs slow.lib

# ---------------------------------------------------------------------
# 3. Read SystemVerilog RTL & Elaborate
# ---------------------------------------------------------------------
read_hdl -sv {
    rnn_pkg.sv
    reg_file.sv
    axi_stream_receiver.sv
    hidden_state_mem.sv
    rnn_compute_engine.sv
    activation_lut.sv
    post_process_alert.sv
    voice_stability_monitor_top.sv
}

elaborate $TOP_MODULE

# ---------------------------------------------------------------------
# 4. Read SDC Constraints
# ---------------------------------------------------------------------
read_sdc constraints.sdc

# ---------------------------------------------------------------------
# 5. Low-Power Configuration & Synthesis Effort
# ---------------------------------------------------------------------
# Enable Integrated Clock Gating (ICG) insertion
set_db lp_insert_clock_gating true
set_db lp_clock_gating_prefix "icg_cell"

# Set synthesis optimization effort levels
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort high

# ---------------------------------------------------------------------
# 6. Three-Stage Synthesis Flow
# ---------------------------------------------------------------------
# Stage 1: Generic Synthesis (RTL to Generic Gates)
syn_generic
write_hdl > output/netlist/${TOP_MODULE}_generic.v

# Stage 2: Logic Mapping (Generic Gates to Technology Cell Library)
syn_map
write_hdl > output/netlist/${TOP_MODULE}_mapped.v

# Stage 3: Gate-Level Incremental Timing & Area Optimization
syn_opt
write_hdl > output/netlist/${TOP_MODULE}_opt.v

# ---------------------------------------------------------------------
# 7. VCD Activity Annotation for Dynamic Power Sign-off
# ---------------------------------------------------------------------
if {[file exists "../tb/power_activity_stimulus.vcd"]} {
    puts "INFO: Annotating switching activity from power_activity_stimulus.vcd..."
    read_vcd -static -vcd_module tb_phase3_stimulus/u_dut ../tb/power_activity_stimulus.vcd
} elseif {[file exists "power_activity_stimulus.vcd"]} {
    puts "INFO: Annotating switching activity from local VCD file..."
    read_vcd -static -vcd_module tb_phase3_stimulus/u_dut power_activity_stimulus.vcd
}

# ---------------------------------------------------------------------
# 8. Export Netlist & SDC Deliverables for Physical Design
# ---------------------------------------------------------------------
write_hdl > output/netlist/${TOP_MODULE}_final.v
write_sdc > output/constraints/${TOP_MODULE}_synth.sdc

# ---------------------------------------------------------------------
# 9. Sign-off Quality of Results (QoR) & Final Reports
# ---------------------------------------------------------------------
report_timing > output/reports/${TOP_MODULE}_timing.rpt
report_power  > output/reports/${TOP_MODULE}_power.rpt
report_area   > output/reports/${TOP_MODULE}_area.rpt
report_gates  > output/reports/${TOP_MODULE}_gates.rpt
report_qor    > output/reports/${TOP_MODULE}_qor.rpt

puts "SUCCESS: Synthesis and sign-off report generation complete!"
gui_show
