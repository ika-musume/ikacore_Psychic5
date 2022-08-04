onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Psychic5_emu/ioctl_index
add wave -noupdate /Psychic5_emu/ioctl_download
add wave -noupdate /Psychic5_emu/ioctl_wr
add wave -noupdate /Psychic5_emu/ioctl_wait
add wave -noupdate /Psychic5_emu/ioctl_addr
add wave -noupdate /Psychic5_emu/ioctl_data
add wave -noupdate /Psychic5_emu/rom_download_done
add wave -noupdate /Psychic5_emu/prog_sdram_en
add wave -noupdate /Psychic5_emu/prog_bram_en
add wave -noupdate /Psychic5_emu/prog_dipsw_en
add wave -noupdate /Psychic5_emu/prog_bram_din_buf
add wave -noupdate /Psychic5_emu/prog_bram_addr
add wave -noupdate /Psychic5_emu/prog_bram_wr_n
add wave -noupdate /Psychic5_emu/prog_bram_tmbgrom_cs_n
add wave -noupdate /Psychic5_emu/prog_bram_tmfgrom_cs_n
add wave -noupdate /Psychic5_emu/prog_bram_seqrom_cs_n
add wave -noupdate /Psychic5_emu/prog_bram_graylut_cs_n
add wave -noupdate /Psychic5_emu/sdram_init
add wave -noupdate /Psychic5_emu/prog_sdram_wr_busy
add wave -noupdate /Psychic5_emu/prog_sdram_ack
add wave -noupdate /Psychic5_emu/prog_sdram_bank_sel
add wave -noupdate /Psychic5_emu/prog_sdram_addr
add wave -noupdate /Psychic5_emu/prog_sdram_din_buf
add wave -noupdate /Psychic5_emu/sdram_dq
add wave -noupdate /Psychic5_emu/sdram_a
add wave -noupdate /Psychic5_emu/sdram_dqml
add wave -noupdate /Psychic5_emu/sdram_dqmh
add wave -noupdate /Psychic5_emu/sdram_ba
add wave -noupdate /Psychic5_emu/sdram_nwe
add wave -noupdate /Psychic5_emu/sdram_ncas
add wave -noupdate /Psychic5_emu/sdram_nras
add wave -noupdate /Psychic5_emu/sdram_ncs
add wave -noupdate /Psychic5_emu/sdram_cke
add wave -noupdate /Psychic5_emu/rfsh
add wave -noupdate /Psychic5_emu/gameboard_top/i_EMU_MCLK
add wave -noupdate /Psychic5_emu/gameboard_top/i_EMU_CLK12MPCEN_n
add wave -noupdate /Psychic5_emu/gameboard_top/i_EMU_MRST_n
add wave -noupdate /Psychic5_emu/gameboard_top/__REF_CLK6MPCEN
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/maincpu/MREQ_n
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/maincpu/RD_n
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/maincpu/A
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/maincpu/DI
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/maincpu/DO
add wave -noupdate /Psychic5_emu/gameboard_top/o_EMU_MAINCPU_ADDR
add wave -noupdate /Psychic5_emu/gameboard_top/i_EMU_MAINCPU_DATA
add wave -noupdate /Psychic5_emu/gameboard_top/o_EMU_MAINCPU_RQ_n
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/mainprog_dout
add wave -noupdate /Psychic5_emu/gameboard_top/cpu_main/bankedrom0_dout
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {28857308198 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {230858465584 ps}
