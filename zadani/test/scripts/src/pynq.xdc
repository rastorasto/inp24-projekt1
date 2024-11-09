## This file is a general .xdc for the PYNQ-Z2 board 

# Clock signal 20 MHz
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { SYSCLK }]; #IO_L12P_T1_MRCC_34 Sch=RPIO_06_R
create_clock -add -name sys_clk_pin -period 50.00 -waveform {0 25} [get_ports { SYSCLK }];

##Raspberry Digital I/O 

set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 DRIVE 12 } [get_ports { ROW[5] }]; #IO_L22P_T3_34 Sch=rpio_02_r
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 DRIVE 12 } [get_ports { ROW[2] }]; #IO_L22N_T3_34 Sch=rpio_03_r
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 DRIVE 12 } [get_ports { ROW[1] }]; #IO_L17P_T2_34 Sch=rpio_04_r
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 DRIVE 12 } [get_ports { ROW[7] }]; #IO_L17N_T2_34 Sch=rpio_05_r
set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { ROW[0] }]; #IO_L22P_T3_13 Sch=rpio_14_r
set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { ROW[3] }]; #IO_L13N_T2_MRCC_13 Sch=rpio_15_r
set_property -dict { PACKAGE_PIN B19   IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[7] }]; #IO_L2P_T0_AD8P_35 Sch=rpio_16_r
set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[4] }]; #IO_L11P_T1_SRCC_13 Sch=rpio_17_r
set_property -dict { PACKAGE_PIN C20   IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[2] }]; #IO_L1P_T0_AD0P_35 Sch=rpio_18_r
set_property -dict { PACKAGE_PIN Y8    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[6] }]; #IO_L14N_T2_SRCC_13 Sch=rpio_19_r
set_property -dict { PACKAGE_PIN A20   IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[0] }]; #IO_L2N_T0_AD8N_35 Sch=rpio_20_r
set_property -dict { PACKAGE_PIN Y9    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[3] }]; #IO_L14P_T2_SRCC_13 Sch=rpio_21_r
set_property -dict { PACKAGE_PIN W9    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[5] }]; #IO_L16N_T2_13 Sch=rpio_26_r
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { COL[1] }]; #IO_L11N_T1_SRCC_13 Sch=rpio_27_r
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { ROW[6] }]; #IO_L7P_T1_34 Sch=rpio_sd_r
set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 DRIVE 12} [get_ports { ROW[4] }]; #IO_L7N_T1_34 Sch=rpio_sc_r

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]