onerror {quit -f}
vlib work
vlog +define+SIM+SIM_MODE+EFX_SIM -sv ./ddr_reset_sequencer_tb.v
vlog +define+SIM+SIM_MODE+EFX_SIM -sv ./etx_ddr3_reset_controller.v
vsim -t ns work.sim
run -all
