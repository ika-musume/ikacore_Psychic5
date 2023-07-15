/*
    Copyright (C) 2022 Sehyeon Kim(Raki)
    
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

`timescale 10ns/10ns
`include "rtl/Psychic5_emu_header.v"

module Psychic5_emu
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_INITRST,
    input   wire            i_EMU_SOFTRST,

    output  wire            o_HSYNC_n,
    output  wire            o_VSYNC_n,

    output  wire            o_HBLANK_n,
    output  wire            o_VBLANK_n,

    output  wire    [3:0]   o_VIDEO_R,
    output  wire    [3:0]   o_VIDEO_G,
    output  wire    [3:0]   o_VIDEO_B,

    output  wire    [15:0]  o_SOUND,

    output  wire            o_PXCEN,

    input   wire    [15:0]  i_JOYSTICK0,
    input   wire    [15:0]  i_JOYSTICK1,

    //refresh rate adjust settings
    input   wire            i_EMU_FLIP,
    input   wire    [3:0]   i_EMU_VPOS_ADJ,
    input   wire    [1:0]   i_EMU_PXCNTR_ADJ_MODE,
    input   wire    [1:0]   i_EMU_PXCNTR_ADJ_H,
    input   wire    [2:0]   i_EMU_PXCNTR_ADJ_V,

    //mister ioctl
    input   wire    [15:0]  ioctl_index,
    input   wire            ioctl_download,
    input   wire    [26:0]  ioctl_addr,
    input   wire    [7:0]   ioctl_data,
    input   wire            ioctl_wr, 
    output  wire            ioctl_wait,

    //mister sdram
    inout   wire    [15:0]  sdram_dq,
    output  wire    [12:0]  sdram_a,
    output  wire            sdram_dqml,
    output  wire            sdram_dqmh,
    output  wire    [1:0]   sdram_ba,
    output  wire            sdram_nwe,
    output  wire            sdram_ncas,
    output  wire            sdram_nras,
    output  wire            sdram_ncs,
    output  wire            sdram_cke,

    output  wire            debug
);

//`define FASTBOOT




///////////////////////////////////////////////////////////
//////  CLOCK DIVIDER
////

wire            CLK12MPCEN_n;
wire            CLK5MPCEN_n, CLK5MNCEN_n;

//12MHz cen generator
reg     [4:0]   div5_cntr = 5'b11110;
assign          CLK12MPCEN_n = div5_cntr[4];
always @(posedge i_EMU_MCLK) begin
    if(i_EMU_INITRST) begin
        div5_cntr <= 5'b11110;
    end
    else begin
        div5_cntr[0] <= div5_cntr[4];
        div5_cntr[4:1] <= div5_cntr[3:0];
    end
end

//5MHz cen generator
reg     [11:0]  div12_cntr = 12'b111111_111110;
assign          CLK5MPCEN_n = div12_cntr[11];
assign          CLK5MNCEN_n = div12_cntr[5];
always @(posedge i_EMU_MCLK) begin
    if(i_EMU_INITRST) begin
        div12_cntr <= 12'b111110_111111;
    end
    else begin
        div12_cntr[0] <= div12_cntr[11];
        div12_cntr[11:1] <= div12_cntr[10:0];
    end
end






///////////////////////////////////////////////////////////
//////  INPUT MAPPER
////

/*
    MiSTer joystick(SNES)
    bit   
    0   right
    1   left
    2   down
    3   up
    4   attack(A)
    5   jump(B)
    6   test(START)
    7   service(SELECT)
    8   coin(R)
    9   start(L)
*/

/*
    SYS_BTN
        76543210
        ||||  ||
        ||||  |^-- start 1
        ||||  ^--- start 2
        |||^------ test
        ||^------- service
        |^-------- coin 1
        ^--------- coin 2

    P1_BTN
        76543210
          ||||||
          |||||^-- right
          ||||^--- left
          |||^---- down
          ||^----- up
          |^------ jump
          ^------- attack
    
    P2_BTN(only for cocktail mode)
        76543210
          ||||||
          |||||^-- right
          ||||^--- left
          |||^---- down
          ||^----- up
          |^------ attack
          ^------- jump
*/

wire    [7:0]   SYS_BTN, P1_BTN, P2_BTN;

//System control
assign          SYS_BTN[0]  = ~i_JOYSTICK0[9];
assign          SYS_BTN[1]  = ~i_JOYSTICK1[9];
assign          SYS_BTN[2]  = 1'b1;
assign          SYS_BTN[3]  = 1'b1;
assign          SYS_BTN[4]  = ~i_JOYSTICK0[6];
assign          SYS_BTN[5]  = ~i_JOYSTICK0[7];
assign          SYS_BTN[6]  = ~i_JOYSTICK0[8];
assign          SYS_BTN[7]  = ~i_JOYSTICK1[8];

//Player 1 control
assign          P1_BTN[0]   = ~i_JOYSTICK0[0];
assign          P1_BTN[1]   = ~i_JOYSTICK0[1];
assign          P1_BTN[2]   = ~i_JOYSTICK0[2];
assign          P1_BTN[3]   = ~i_JOYSTICK0[3];
assign          P1_BTN[4]   = ~i_JOYSTICK0[5]; //jump
assign          P1_BTN[5]   = ~i_JOYSTICK0[4]; //attack
assign          P1_BTN[6]   = 1'b1;
assign          P1_BTN[7]   = 1'b1;

//Player 2 control
assign          P2_BTN[0]   = ~i_JOYSTICK1[0];
assign          P2_BTN[1]   = ~i_JOYSTICK1[1];
assign          P2_BTN[2]   = ~i_JOYSTICK1[2];
assign          P2_BTN[3]   = ~i_JOYSTICK1[3];
assign          P2_BTN[4]   = ~i_JOYSTICK1[4]; //attack
assign          P2_BTN[5]   = ~i_JOYSTICK1[5]; //jump
assign          P2_BTN[6]   = 1'b1;
assign          P2_BTN[7]   = 1'b1;






///////////////////////////////////////////////////////////
//////  ROM DISTRUBUTOR
////

//start addr    length        comp num     mame rom     parts num     location     description
//0x0000_0000   0x0001_0000   7c           p5e          27C512        BANK0        banked game data
//0x0001_0000   0x0000_8000   7a           p5d          27C256        BANK0        main program
//0x0001_8000   0x0000_8000                          DUMMY DATA
//0x0002_0000   0x0001_0000   4p           p5b          27C512        BANK1        objrom 0
//0x0003_0000   0x0001_0000   4s           p5c          27C512        BANK1        objrom 1

//0x0004_0000   0x0001_0000   2k           p5g          27C512        BRAM         bgrom 0 
//0x0005_0000   0x0001_0000   2m           p5h          27C512        BRAM         bgrom 1
//0x0006_0000   0x0000_8000   5f           p5f          27C256        BRAM         fgrom
//0x0006_8000   0x0000_8000   2c           p5a          27C512/256    BRAM         sound program(Note 1)
//0x0007_0000   0x0000_0400   3t           my09.3t      82S137        BRAM         sprite engine sequencer(MB7122)
//0x0007_0400   0x0000_0200   7l           my10.7l      82S131        BRAM         grayscale LUT
//0x0007_0600          <-----------------ROM END----------------->

//Note 1: MAME states JP uses a 256k ROM, but I verified that an original PCB that holds JP release 
//        also used a 512k ROM instead of the 256k one. Bottom half is empty.


//
//  DIPSW BANK
//

reg     [7:0]   DIPSW1 = 8'hEF;
reg     [7:0]   DIPSW2 = 8'hFF;

/*
    DIPSW1
        76543210
        |||||  |
        |||||  ^-- flip             / 1=off 0=on
        ||||^----- difficultiy      / 1=normal 0=hard
        |||^------ cabinet type     / 1=cocktail 0=upright
        ||^------- demo sound       / 1=on 0=off
        ^^-------- lives            / 10=2 11=3 01=4 00=5
          
    DIPSW2
        76543210
        |||||| |
        |||||| ^-- invincibility    / 1=off 0=on
        |||^^^---- coin B           / 000=5C1P 001=4C1P 010=3C1P 011=2C1P
        |||                         / 100=1C4P 101=1C3P 110=1C2P 111=1C1P
        ^^^------- coin A           / 000=5C1P 001=4C1P 010=3C1P 011=2C1P
                                    / 100=1C4P 101=1C3P 110=1C2P 111=1C1P
*/



//
//  SDRAM/BRAM DOWNLOADER INTERFACE
//

//download complete
reg             rom_download_done = 1'b0;

//enables
reg             prog_sdram_en = 1'b0;
reg             prog_bram_en = 1'b0;
reg             prog_dipsw_en = 1'b0;

//sdram control
wire            sdram_init;
reg             prog_sdram_wr_busy = 1'b0;
wire            prog_sdram_ack;
assign          ioctl_wait = sdram_init | prog_sdram_wr_busy;
//assign          ioctl_wait = 1'b0;

reg     [1:0]   prog_sdram_bank_sel;
reg     [21:0]  prog_sdram_addr;
reg     [15:0]  prog_sdram_din_buf;

//bram control
reg     [7:0]   prog_bram_din_buf;
reg     [16:0]  prog_bram_addr;
reg             prog_bram_wr_n;
reg     [4:0]   prog_bram_csreg_n;

wire            prog_bram_soundrom_cs_n = prog_bram_csreg_n[4];
wire            prog_bram_tmbgrom_cs_n = prog_bram_csreg_n[3];
wire            prog_bram_tmfgrom_cs_n = prog_bram_csreg_n[2];
wire            prog_bram_seqrom_cs_n = prog_bram_csreg_n[1];
wire            prog_bram_graylut_cs_n = prog_bram_csreg_n[0];
assign          debug = rom_download_done;



always @(posedge i_EMU_MCLK) begin
    if((i_EMU_INITRST | rom_download_done) == 1'b1) begin
        //enables
        prog_sdram_en <= 1'b0;
        prog_bram_en <= 1'b0;
        prog_dipsw_en <= 1'b0;
        
        //sdram
        prog_sdram_addr <= 22'h3F_FFFF;
        prog_sdram_wr_busy <= 1'b0;
        prog_sdram_bank_sel <= 2'd0;
        prog_sdram_din_buf <= 16'hFFFF;

        //bram
        prog_bram_din_buf <= 8'hFF;
        prog_bram_addr <= 17'h1FFFF;
        prog_bram_wr_n <= 1'b1;
        prog_bram_csreg_n <= 5'b11111;
    end
    else begin
        //  ROM DATA UPLOAD
        if(ioctl_index == 16'd0) begin //ROM DATA
            //  BLOCK RAM REGION
            if(ioctl_addr[18] == 1'b1) begin
                prog_sdram_en <= 1'b0;
                prog_bram_en <= 1'b1;
                prog_dipsw_en <= 1'b0;

                if(ioctl_wr == 1'b1) begin
                    prog_bram_din_buf <= ioctl_data;
                    prog_bram_addr <= ioctl_addr[16:0];
                    prog_bram_wr_n <= 1'b0;

                    if(ioctl_addr[17] == 1'b0) begin //tilemap background
                        prog_bram_csreg_n <= 5'b10111;
                    end
                    else begin
                        if(ioctl_addr[16:15] == 2'b00) begin //tilemap foreground
                            prog_bram_csreg_n <= 5'b11011;
                        end
                        else if(ioctl_addr[16:15] == 2'b01) begin //sound rom
                            prog_bram_csreg_n <= 5'b01111;
                        end
                        else if(ioctl_addr[16:15] == 2'b10) begin
                            if(ioctl_addr[10] == 1'b0) begin //sprite engine sequencer bipolar PROM
                                prog_bram_csreg_n <= 5'b11101;
                            end
                            else if(ioctl_addr[10:9] == 2'b10) begin //grayscale LUT
                                prog_bram_csreg_n <= 5'b11110;
                            end
                            else begin
                                prog_bram_csreg_n <= 5'b11111;
                            end
                        end
                        else begin
                            prog_bram_csreg_n <= 5'b11111;
                        end
                    end
                end
                else begin
                    prog_bram_wr_n <= 1'b1;
                end
            end

            //  SDRAM REGION
            else begin
                prog_sdram_en <= 1'b1;
                prog_bram_en <= 1'b0;
                prog_dipsw_en <= 1'b0;
                
                if(prog_sdram_wr_busy == 1'b0) begin
                    if(ioctl_wr == 1'b1) begin
                        if(ioctl_addr[0] == 1'b0) begin //upper data
                            prog_sdram_din_buf[15:8] <= ioctl_data;
                        end
                        else begin //lower data, write
                            prog_sdram_din_buf[7:0] <= ioctl_data;
                            prog_sdram_wr_busy <= 1'b1;

                            if(ioctl_addr[17] == 1'b0) begin //BANK 0 or 2
                                prog_sdram_addr <= {6'b00_0000, ioctl_addr[16:1]};
                                prog_sdram_bank_sel <= 2'd0;
                            end
                            else begin //BANK 1
                                prog_sdram_addr <= {6'b00_0000, ioctl_addr[16:1]};
                                prog_sdram_bank_sel <= 2'd1;
                            end
                        end
                    end
                end
                else begin
                    if(prog_sdram_ack == 1'b1) begin  
                        prog_sdram_wr_busy <= 1'b0;
                    end
                end
            end
        end

        else if(ioctl_index == 16'd254) begin //DIP SWITCH
            if(ioctl_addr[24:1] == 24'h00_0000) begin
                prog_sdram_en <= 1'b0;
                prog_bram_en <= 1'b0;
                prog_dipsw_en <= 1'b1;

                if(ioctl_wr == 1'b1) begin
                    if(ioctl_addr[0] == 1'b0) begin
                        DIPSW1 <= ioctl_data;
                    end
                    else if(ioctl_addr[0] == 1'b1) begin
                        DIPSW2 <= ioctl_data;
                    end
                end
            end
            else begin
                prog_sdram_en <= 1'b0;
                prog_bram_en <= 1'b0;
                prog_dipsw_en <= 1'b0;
            end
        end
    end
end



//
//  SDRAM CONTROLLER
//

wire    [21:0]  ba0_addr;
wire    [21:0]  ba1_addr;
wire    [21:0]  ba2_addr;
wire    [3:0]   rd;           
wire    [3:0]   ack;
wire    [3:0]   dst;
wire    [3:0]   rdy;
wire    [15:0]  data_read;

reg     [8:0]   rfsh_cntr;
wire            rfsh = rfsh_cntr == 9'd384;
always @(posedge i_EMU_MCLK) begin
    if(o_PXCEN) begin
        if(i_EMU_INITRST) begin
            rfsh_cntr <= 9'd0;
        end
        else begin
            if(rfsh_cntr < 9'd384) rfsh_cntr <= rfsh_cntr + 9'd1;
            else rfsh_cntr <= 9'd0;
        end
    end
end


jtframe_sdram64 #(.HF(0)) sdram_controller (
    .rst                        (i_EMU_INITRST              ),
    .clk                        (i_EMU_MCLK                 ),
    .init                       (sdram_init                 ),

    .ba0_addr                   (ba0_addr                   ),
    .ba1_addr                   (ba1_addr                   ),
    .ba2_addr                   (ba2_addr                   ),
    .ba3_addr                   (22'h00_0000                ),
    .rd                         ({2'b00, rd[1:0]}           ),
    .wr                         (4'b0000                    ),
    .din                        (prog_sdram_din_buf         ),
    .din_m                      (2'b00                      ),

    .prog_en                    (prog_sdram_en              ),
    .prog_addr                  (prog_sdram_addr            ),
    .prog_rd                    (1'b0                       ),
    .prog_wr                    (prog_sdram_wr_busy         ),
    .prog_din                   (prog_sdram_din_buf         ),
    .prog_din_m                 (2'b00                      ),
    .prog_ba                    (prog_sdram_bank_sel        ),
    .prog_dst                   (                           ),
    .prog_dok                   (                           ),
    .prog_rdy                   (                           ),
    .prog_ack                   (prog_sdram_ack             ),

    .rfsh                       (rfsh                       ),

    .ack                        (ack                        ),
    .dst                        (dst                        ),
    .dok                        (                           ),
    .rdy                        (rdy                        ),
    .dout                       (data_read                  ),

    .sdram_dq                   (sdram_dq                   ),
    .sdram_a                    (sdram_a                    ),
    .sdram_dqml                 (sdram_dqml                 ),
    .sdram_dqmh                 (sdram_dqmh                 ),
    .sdram_ba                   (sdram_ba                   ),
    .sdram_nwe                  (sdram_nwe                  ),
    .sdram_ncas                 (sdram_ncas                 ),
    .sdram_nras                 (sdram_nras                 ),
    .sdram_ncs                  (sdram_ncs                  ),
    .sdram_cke                  (sdram_cke                  )
);



//
//  DOWNLOAD COMPLETE
//

reg     [2:0]   dwnld_done_negdet;
reg     [2:0]   dwnld_done_flags;

wire            sdram_done_set = dwnld_done_negdet[2] & ~prog_sdram_en;
wire            bram_done_set = dwnld_done_negdet[1] & ~prog_bram_en;
wire            dipsw_done_set = dwnld_done_negdet[0] & ~prog_dipsw_en;


always @(posedge i_EMU_MCLK) begin
    if(i_EMU_INITRST == 1'b1) begin
        dwnld_done_negdet <= 3'b000;
        dwnld_done_flags <= 3'b000;
        rom_download_done <= 1'b0;
    end
    else begin
        dwnld_done_negdet[2] <= prog_sdram_en;
        dwnld_done_negdet[1] <= prog_bram_en;
        dwnld_done_negdet[0] <= prog_dipsw_en;

        if(sdram_done_set) dwnld_done_flags[2] <= 1'b1;
        if(bram_done_set) dwnld_done_flags[1] <= 1'b1;
        if(dipsw_done_set) dwnld_done_flags[0] <= 1'b1;

        rom_download_done <= &{dwnld_done_flags};
    end
end






///////////////////////////////////////////////////////////
//////  ROM SLOTS
////

wire            maincpu_rq_n;
wire    [16:0]  maincpu_addr;
wire    [15:0]  maincpu_wide_data;
wire    [7:0]   maincpu_muxed_data = (maincpu_addr[0] == 1'b0) ? maincpu_wide_data[15:8] : maincpu_wide_data[7:0];

jtframe_rom_2slots #(
    // Slot 0: Sound program
    .SLOT0_AW                   (15                         ),
    .SLOT0_DW                   (16                         ),
    .SLOT0_OFFSET               (18'h0_C000                 ),

    // Slot 1: Main program
    .SLOT1_AW                   (16                         ),
    .SLOT1_DW                   (16                         ),
    .SLOT1_OFFSET               (18'h0_0000                 )
) bank0 (
    .rst                        (~rom_download_done         ),
    .clk                        (i_EMU_MCLK                 ),

    .slot0_cs                   (1'b0                       ),
    .slot1_cs                   (~maincpu_rq_n              ),

    .slot0_ok                   (                           ),
    .slot1_ok                   (                           ),

    .slot0_addr                 (                           ),
    .slot1_addr                 (maincpu_addr[16:1]         ),

    .slot0_dout                 (                           ),
    .slot1_dout                 (maincpu_wide_data          ),

    .sdram_addr                 (ba0_addr                   ),
    .sdram_req                  (rd[0]                      ),
    .sdram_ack                  (ack[0]                     ),
    .data_dst                   (dst[0]                     ),
    .data_rdy                   (rdy[0]                     ),
    .data_read                  (data_read                  )
);


wire            objrom_rq_n;
wire    [16:0]  objrom_addr;
wire    [15:0]  objrom_wide_data;
wire    [7:0]   objrom_muxed_data = (objrom_addr[0] == 1'b0) ? objrom_wide_data[15:8] : objrom_wide_data[7:0];

jtframe_rom_2slots #(
    // Slot 0: Sound program
    .SLOT0_AW                   (16                         ),
    .SLOT0_DW                   (16                         ),
    .SLOT0_OFFSET               (18'h0_0000                 ),

    .SLOT1_AW                   (                           ),
    .SLOT1_DW                   (                           ),
    .SLOT1_OFFSET               (                           )
) bank1 (
    .rst                        (~rom_download_done         ),
    .clk                        (i_EMU_MCLK                 ),

    .slot0_cs                   (~objrom_rq_n               ),
    .slot1_cs                   (1'b0                       ),

    .slot0_ok                   (                           ),
    .slot1_ok                   (                           ),

    .slot0_addr                 (objrom_addr[16:1]          ),
    .slot1_addr                 (                           ),

    .slot0_dout                 (objrom_wide_data           ),
    .slot1_dout                 (                           ),

    .sdram_addr                 (ba1_addr                   ),
    .sdram_req                  (rd[1]                      ),
    .sdram_ack                  (ack[1]                     ),
    .data_dst                   (dst[1]                     ),
    .data_rdy                   (rdy[1]                     ),
    .data_read                  (data_read                  )
);





///////////////////////////////////////////////////////////
//////  GAME BOARD
////

//define reset
`ifdef FASTBOOT
wire            core_reset = i_EMU_INITRST;

`else
wire            core_reset = i_EMU_INITRST | ~rom_download_done;

`endif

wire            cpu_soft_reset = i_EMU_INITRST | i_EMU_SOFTRST;


//screen simulation
`ifdef SIMULATION
wire    [8:0]   HCOUNTER, VCOUNTER;

Psychic5_screensim screensim_main (
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (~o_PXCEN                   ),
    .i_EMU_MRST_n               (~core_reset                ),

    .i_HCOUNTER                 (HCOUNTER                   ),
    .i_VCOUNTER                 (VCOUNTER                   ),
    .i_VIDEODATA                ({o_VIDEO_R, o_VIDEO_G, o_VIDEO_B})
);
`endif

//sync and blanking
wire            hsync_n, hblank_n;
wire            vsync_n;

Psychic5_top gameboard_top (
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK12MPCEN_n         (CLK12MPCEN_n               ),
    .i_EMU_CLK5MPCEN_n          (CLK5MPCEN_n                ),
    .i_EMU_CLK5MNCEN_n          (CLK5MNCEN_n                ),

    .i_EMU_INITRST_n            (~core_reset                ), //active low
    .i_EMU_SOFTRST_n            (~cpu_soft_reset            ),

    .i_EMU_PXCNTR_ADJ_MODE      (i_EMU_PXCNTR_ADJ_MODE      ),
    .i_EMU_PXCNTR_ADJ_H         (i_EMU_PXCNTR_ADJ_H         ),
    .i_EMU_PXCNTR_ADJ_V         (i_EMU_PXCNTR_ADJ_V         ),

    .o_CSYNC_n                  (                           ),
    .o_HSYNC_n                  (hsync_n                    ),
    .o_VSYNC_n                  (vsync_n                    ),
    
    .o_HBLANK_n                 (hblank_n                   ),
    .o_VBLANK_n                 (o_VBLANK_n                 ),

    .o_VIDEO_R                  (o_VIDEO_R                  ),
    .o_VIDEO_G                  (o_VIDEO_G                  ),
    .o_VIDEO_B                  (o_VIDEO_B                  ),

    .o_SOUND                    (o_SOUND                    ),

    .__REF_PXCEN                (o_PXCEN                    ),
    .__REF_HCOUNTER             (HCOUNTER                   ),
    .__REF_VCOUNTER             (VCOUNTER                   ),

    .i_P1_BTN                   (P1_BTN                     ),
    .i_P2_BTN                   (P2_BTN                     ),
    .i_SYS_BTN                  (SYS_BTN                    ),
    .i_DIPSW1                   ({DIPSW1[7:1], ~i_EMU_FLIP} ),
    .i_DIPSW2                   (DIPSW2                     ),

    //SDRAM requests
    .o_EMU_MAINCPU_ADDR         (maincpu_addr               ),
    .i_EMU_MAINCPU_DATA         (maincpu_muxed_data         ),
    .o_EMU_MAINCPU_RQ_n         (maincpu_rq_n               ),

    .o_EMU_OBJROM_ADDR          (objrom_addr                ),
    .i_EMU_OBJROM_DATA          (objrom_muxed_data          ),
    .o_EMU_OBJROM_RQ_n          (objrom_rq_n                ),

    //BRAM programming
    .i_EMU_BRAM_ADDR            (prog_bram_addr             ),
    .i_EMU_BRAM_DATA            (prog_bram_din_buf          ),
    .i_EMU_BRAM_WR_n            (prog_bram_wr_n             ),

    .i_EMU_BRAM_SOUNDROM_CS_n   (prog_bram_soundrom_cs_n    ),
    .i_EMU_BRAM_TMBGROM_CS_n    (prog_bram_tmbgrom_cs_n     ),
    .i_EMU_BRAM_TMFGROM_CS_n    (prog_bram_tmfgrom_cs_n     ),
    .i_EMU_BRAM_GRAYLUT_CS_n    (prog_bram_graylut_cs_n     ),
    .i_EMU_BRAM_SEQROM_CS_n     (prog_bram_seqrom_cs_n      )
);



///////////////////////////////////////////////////////////
//////  SYNC DELAY
////

reg     [9:0]   hsync_dlyline, hblank_dlyline;
assign          o_HSYNC_n = hsync_dlyline[4];
assign          o_HBLANK_n = hblank_dlyline[4];

reg     [18:0]  vsync_dlyline;
assign  o_VSYNC_n = (i_EMU_VPOS_ADJ == 4'd0) ? vsync_n : vsync_dlyline[3 + i_EMU_VPOS_ADJ];

always @(posedge i_EMU_MCLK) begin
    if(o_PXCEN) begin
        hsync_dlyline[0] <= hsync_n;
        hsync_dlyline[9:1] <= hsync_dlyline[8:0];

        hblank_dlyline[0] <= hblank_n;
        hblank_dlyline[9:1] <= hblank_dlyline[8:0];

        if(hblank_dlyline[9:8] == 2'b10) begin
            vsync_dlyline[0] <= vsync_n;
            vsync_dlyline[18:1] <= vsync_dlyline[17:0];
        end
    end
end

endmodule