#------------------------------------------------------------------------------------------------------------
# Generovani bitstreamu pro konfiguraci FPGA Zynq na desce Pynq                 (C) Zdenek VASICEK, 2024, FIT
#------------------------------------------------------------------------------------------------------------

set workDir "$env(WORK_DIR)/vivado"
set partNumber "xc7z020clg400-1"

file mkdir $workDir
set files [glob -nocomplain "$workDir/*"]
if {[llength $files] != 0} {
    # clear folder contents
    puts "deleting contents of $workDir"
    file delete -force {*}[glob -directory $workDir *]; 
} else {
    puts "$workDir is empty"
}

# Nacteni zdrojovych souboru
# -----------------------------------
read_vhdl -library work [ glob -nocomplain ./scripts/src/*.vhd ]
read_vhdl -library work "$env(VHDL_SRC)"
read_edif [ glob -nocomplain ./scripts/src/*.edf ]
#read_verilog [ glob ./src/*.v ]
read_xdc [ glob -nocomplain ./scripts/src/*.xdc ]

# Synteza
# -----------------------------------
synth_design -top top -part "$partNumber"
opt_design

# Place & route
# -----------------------------------
place_design
#get timing violations and run optimizations if needed
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
 puts "Found setup timing violations => running physical optimization"
 phys_opt_design
}
route_design -directive Explore

# Generovani bitstreamu a reportu
# -----------------------------------
report_route_status -file $workDir/post_route_status.rpt
report_timing_summary -file $workDir/post_route_timing_summary.rpt
report_power -file $workDir/post_route_power.rpt
report_drc -file $workDir/post_imp_drc.rpt
#write_checkpoint -force $workDir/post_route.dcp
#write_verilog -force $workDir/cpu_impl_netlist.v -mode timesim -sdf_anno true
#write_mem_info  -file $workDir/top.mmi
write_bitstream -force $workDir/top.bit


# Generovani mem_info souboru
# -------------------------------------
set brams [split [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.bram.* && PARENT =~  "*ram_mem*" }] " "]
set fileout [open "$workDir/top.mmi" "w"]
puts $fileout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
puts $fileout "<MemInfo Version=\"1\" Minor=\"0\">"
puts $fileout "  <Processor Endianness=\"Little\" InstPath=\"dummy\">"

set bram_range 0
for {set i 0} {$i < [llength $brams]} {incr i} {
    set bram_type [get_property REF_NAME [get_cells [lindex $brams $i]]]
    if {$bram_type == "RAMB36E1"} {
        set bram_range [expr {$bram_range + 4096}]	
    }
}
puts $fileout "    <AddressSpace Name=\"blockrams\" Begin=\"0\" End=\"[expr {$bram_range - 1}]\">"
puts $fileout "      <BusBlock>"
for {set i 0} {$i < [llength $brams]} {incr i} {
    set bram_type [get_property REF_NAME [get_cells [lindex $brams $i]]]
    set bram_loc [get_property LOC [get_cells [lindex $brams $i]]]
	set bram_loc [lindex [split $bram_loc "_"] 1]
    set addr_start [get_property ram_addr_begin [get_cells [lindex $brams $i]]]
    set addr_end [get_property ram_addr_end [get_cells [lindex $brams $i]]]
    set bit_lsb [get_property ram_slice_begin [get_cells [lindex $brams $i]]]
    set bit_msb [get_property ram_slice_end [get_cells [lindex $brams $i]]]
    if {$bram_type == "RAMB36E1"} {
        puts $fileout "        <!-- [lindex $brams $i] -->"
        puts $fileout "        <BitLane MemType=\"RAMB32\" Placement=\"$bram_loc\">"
        puts $fileout "          <DataWidth MSB=\"$bit_msb\" LSB=\"$bit_lsb\"/>"
        puts $fileout "          <AddressRange Begin=\"$addr_start\" End=\"$addr_end\"/>"
        puts $fileout "          <Parity ON=\"false\" NumBits=\"0\"/>"
        puts $fileout "        </BitLane>"
    }
}
puts $fileout "      </BusBlock>"
puts $fileout "    </AddressSpace>"
puts $fileout "  </Processor>"
puts $fileout "<Config>"
puts $fileout "  <Option Name=\"Part\" Val=\"$partNumber\"/>"
puts $fileout "</Config>"
puts $fileout "</MemInfo>"
close $fileout