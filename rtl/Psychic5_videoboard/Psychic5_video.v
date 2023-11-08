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

module Psychic5_video
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK12MPCEN_n,

    output  wire            o_EMU_CLK6MPCEN_n,
    output  wire            o_EMU_CLK6MNCEN_n,

    input   wire            i_EMU_INITRST_n,

    //refresh rate adjust settings
    input   wire    [1:0]   i_EMU_PXCNTR_ADJ_MODE,
    input   wire    [1:0]   i_EMU_PXCNTR_ADJ_H,
    input   wire    [2:0]   i_EMU_PXCNTR_ADJ_V,

    //CPU RW
    input   wire    [12:0]  i_ADDR_BUS,
    output  reg     [7:0]   o_DATA_READ_BUS,
    input   wire    [7:0]   i_DATA_WRITE_BUS,
    input   wire            i_CTRL_RD_n,
    input   wire            i_CTRL_WR_n,

    //RAM CS
    input   wire            i_TM_BG_ATTR_CS_n,
    input   wire            i_TM_FG_ATTR_CS_n,
    input   wire            i_TM_BG_SCR_CS_n,
    input   wire            i_TM_PALETTE_CS_n,
    input   wire            i_OBJ_PALETTE_CS_n,

    //Flip bit
    input   wire            i_FLIP,

    //Video timings
    output  wire    [7:0]   o_FLIP_HV_BUS,
    output  wire            o_ABS_4H, o_ABS_2H, o_ABS_1H, //hcounter bits

    output  wire            o_DFFD_7E_A_Q, //IDC PIN D6
    output  wire            o_DFFD_7E_A_Q_PCEN_n, //positive edge enable signal of the signal above,
    output  wire            o_DFFD_8E_A_Q,
    output  wire            o_DFFD_8E_B_Q, //IDC PIN D7
    output  wire            o_DFFQ_8F_Q3, //IDC PIN D11
    output  wire            o_DFFQ_8F_Q2, //IDC PIN C11
    output  reg             o_DFFQ_8F_Q2_NCEN_n, //negative edge enable signal of the signal above, used by CPU sprite engine
    output  wire            o_DFFQ_8F_Q1, //IDC PIN D8

    //sprite pixel input
    input   wire    [7:0]   i_OBJ_PIXELIN,

    //Video output
    output  wire            o_CSYNC_n,
    output  wire            o_HSYNC_n,
    output  wire            o_VSYNC_n,

    output  wire            o_HBLANK_n,
    output  wire            o_VBLANK_n,

    output  reg     [3:0]   o_VIDEO_R = 4'hF,
    output  reg     [3:0]   o_VIDEO_G = 4'hF,
    output  reg     [3:0]   o_VIDEO_B = 4'hF,

    //for screen recording
    output  wire    [8:0]   __REF_HCOUNTER,
    output  wire    [8:0]   __REF_VCOUNTER,
    output  wire            __REF_PXCEN,

    //BRAM programming
    input   wire    [16:0]  i_EMU_BRAM_ADDR,
    input   wire    [7:0]   i_EMU_BRAM_DATA,
    input   wire            i_EMU_BRAM_WR_n,

    input   wire            i_EMU_BRAM_TMBGROM_CS_n,
    input   wire            i_EMU_BRAM_TMFGROM_CS_n,
    input   wire            i_EMU_BRAM_GRAYLUT_CS_n
);

localparam  [39:0]   initializer_buffer = 40'h4012680001;



///////////////////////////////////////////////////////////
//////  CLOCKS
////

/*
    MCLK48  ################################################ or
    MCLK24  |||||||||||||||||||||||||||||||||||||||||||||||| or
    MCLK12  ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    12MPCEN ¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||¯¯||

    CLK6M   ¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|
    6MPCEN  ¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||
    6MNCEN  ¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯¯¯||¯¯¯¯
*/

reg     [1:0]   cen_register = 2'b01;
always @(posedge i_EMU_MCLK) begin
    if(!i_EMU_INITRST_n) cen_register <= 2'b01;
    else begin
        if(!i_EMU_CLK12MPCEN_n) cen_register <= ~cen_register;
    end
end

//ORed with 12M negative cen
assign  o_EMU_CLK6MPCEN_n = (cen_register[1] | i_EMU_CLK12MPCEN_n) | ~i_EMU_INITRST_n;
assign  o_EMU_CLK6MNCEN_n = (cen_register[0] | i_EMU_CLK12MPCEN_n) | ~i_EMU_INITRST_n;
assign  __REF_PXCEN = ~o_EMU_CLK6MPCEN_n;



///////////////////////////////////////////////////////////
//////  TOYOCOM N-8633-S
////

//
//  hybrid IC section
//

wire    [8:0]   ABS_H_CNTR, ABS_V_CNTR;

assign  __REF_HCOUNTER = ABS_H_CNTR;
assign  __REF_VCOUNTER = ABS_V_CNTR;

wire            ABS_256H_n;
wire            FLIP_64HA;

wire    [7:0]   FLIP_HV_BUS;

assign  o_FLIP_HV_BUS = FLIP_HV_BUS;
assign  {o_ABS_4H, o_ABS_2H, o_ABS_1H} = ABS_H_CNTR[2:0];

wire            CNTRSEL;


N8633S N8633S_Main (
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (o_EMU_CLK6MPCEN_n          ),

    .i_EMU_PXCNTR_ADJ_MODE      (i_EMU_PXCNTR_ADJ_MODE      ),
    .i_EMU_PXCNTR_ADJ_H         (i_EMU_PXCNTR_ADJ_H         ),
    .i_EMU_PXCNTR_ADJ_V         (i_EMU_PXCNTR_ADJ_V         ),

    .i_FLIP                     (i_FLIP                     ),
    .i_CNTRSEL                  (CNTRSEL                    ),

    .o_ABS_256H_n               (ABS_256H_n                 ),
    .o_FLIP_64HA                (FLIP_64HA                  ),

    .o_ABS_H_CNTR               (ABS_H_CNTR                 ),
    .o_ABS_V_CNTR               (ABS_V_CNTR                 ),

    .o_FLIP_HV_BUS              (FLIP_HV_BUS                )
);


//
//  timing generator
//

//asynchronous test code
/*
    reg         DFFD_7H_A_Q;
    always @(posedge ABS_V_CNTR[4])
    begin
        DFFD_7H_A_Q <= ~&{ABS_V_CNTR[8], ABS_V_CNTR[7], ABS_V_CNTR[6], ABS_V_CNTR[5]};
    end

    reg         DFFD_7H_B_Q;
    wire        DFFD_7H_B_Q_n = ~DFFD_7H_B_Q;
    always @(posedge ABS_V_CNTR[4] or negedge DFFD_7H_A_Q)
    begin
        if(!DFFD_7H_A_Q)
        begin
            DFFD_7H_B_Q <= 1'b0;
        end
        else
        begin
            DFFD_7H_B_Q <= ABS_V_CNTR[8];
        end
    end

    reg         DFFD_8E_A_Q;
    wire        DFFD_8E_A_Q_n = ~DFFD_8E_A_Q;
    always @(posedge ABS_V_CNTR[4] or posedge ABS_V_CNTR[7])
    begin
        if(ABS_V_CNTR[7])
        begin
            DFFD_8E_A_Q <= 1'b0;
        end
        else
        begin
            DFFD_8E_A_Q <= ABS_V_CNTR[5] & ABS_V_CNTR[6];
        end
    end

    reg         DFFD_8E_B_Q;
    always @(posedge ABS_V_CNTR[2] or negedge DFFD_7H_B_Q_n)
    begin
        if(!DFFD_7H_B_Q_n)
        begin
            DFFD_8E_B_Q <= 1'b0;
        end
        else
        begin
            DFFD_8E_B_Q <= 1'b1;
        end
    end

    reg     [3:0]   DFFD_8F_Q;
    wire    [3:0]   DFFD_8F_Q_n = ~DFFD_8F_Q;
    always @(posedge ABS_H_CNTR[3])
    begin
        DFFD_8F_Q[3] <= ABS_H_CNTR[8];
        DFFD_8F_Q[2] <= DFFD_7H_B_Q;
        DFFD_8F_Q[1] <= DFFD_8E_B_Q;
        DFFD_8F_Q[0] <= 1'b0;
    end

    reg             LS138_Y4_n;
    always @(*)
    begin
        if((ABS_V_CNTR[8] | DFFD_7H_B_Q) == 1'b0) //enable
        begin
            if({ABS_V_CNTR[5], ABS_V_CNTR[4], ABS_V_CNTR[3]} == 3'd4)
            begin
                LS138_Y4_n <= 1'b0;
            end
            else
            begin
                LS138_Y4_n <= 1'b1;
            end
        end
        else
        begin
            LS138 <= 1'b1;
        end
    end

    reg         DFFD_7E_B_Q;
    wire        DFFD_7E_B_Q_n = ~DFFD_7E_B_Q;
    always @(posedge ABS_H_CNTR[4] or negedge DFFD_8F_Q_n[3])
    begin
        if(!DFFD_8F_Q_n[3])
        begin
            DFFD_7E_B_Q <= 1'b0;
        end
        else
        begin
            DFFD_7E_B_Q <= (~ABS_H_CNTR[7]) & ABS_H_CNTR[5];
        end
    end

    reg         DFFD_7E_A_Q;
    always @(posedge ABS_H_CNTR[7] or negedge DFFD_7E_B_Q)
    begin
        if(!DFFD_7E_B_Q)
        begin
            DFFD_7E_A_Q <= 1'b0;
        end
        else
        begin
            DFFD_7E_A_Q <= 1'b1;
        end
    end

    wire        CSYNC = LS138_Y4_n & DFFD_7E_B_Q_n;
*/

//hcounter 511
wire            emu_vcnt_en = &{ABS_H_CNTR};

//LS74 7H
reg             DFFD_7H_A_Q = 1'b1; //goes low when V496-511, 220-239; async reset of 7H_B - not used
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(emu_vcnt_en == 1'b1)
        begin
            if(ABS_V_CNTR > 9'd494 || ABS_V_CNTR < 9'd239)
            begin
                DFFD_7H_A_Q <= 1'b0;
            end
            else
            begin
                DFFD_7H_A_Q <= 1'b1;
            end
        end
    end
end

//LS74 7H
reg             DFFD_7H_B_Q = 1'b1; //goes low when V496-511, 220-271
wire            DFFD_7H_B_Q_n = ~DFFD_7H_B_Q; //async reset of 8E_B - not used
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(emu_vcnt_en == 1'b1)
        begin
            if(ABS_V_CNTR > 9'd494 || ABS_V_CNTR < 9'd271)
            begin
                DFFD_7H_B_Q <= 1'b0;
            end
            else
            begin
                DFFD_7H_B_Q <= 1'b1;
            end
        end
    end
end

//LS74 8E
reg             DFFD_8E_A_Q = 1'b0; //goes high when V368-383
assign  o_DFFD_8E_A_Q = DFFD_8E_A_Q;
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(emu_vcnt_en == 1'b1)
        begin
            if(ABS_V_CNTR > 9'd366 && ABS_V_CNTR < 9'd383)
            begin
                DFFD_8E_A_Q <= 1'b1;
            end
            else
            begin
                DFFD_8E_A_Q <= 1'b0;
            end
        end
    end
end

//LS74 8E
reg             DFFD_8E_B_Q = 1'b0; //goes high when V500-511, 220-271
assign  o_DFFD_8E_B_Q = DFFD_8E_B_Q;
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(emu_vcnt_en == 1'b1)
        begin
            if(ABS_V_CNTR > 9'd498 || ABS_V_CNTR < 9'd271)
            begin
                DFFD_8E_B_Q <= 1'b1;
            end
            else
            begin
                DFFD_8E_B_Q <= 1'b0;
            end
        end
    end
end

//LS74 7E
reg             DFFD_7E_B_Q = 1'b0; //goes high when H176-207; async reset of 7E_A - not used
wire            DFFD_7E_B_Q_n = ~DFFD_7E_B_Q;
assign  CNTRSEL = DFFD_7E_B_Q_n;

always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_H_CNTR > 9'd174 && ABS_H_CNTR < 9'd207)
        begin
            DFFD_7E_B_Q <= 1'b1;
        end
        else
        begin
            DFFD_7E_B_Q <= 1'b0;
        end
    end
end

//LS74 7E
reg             DFFD_7E_A_Q = 1'b0; //goes high when H192-207 
reg             DFFD_7E_A_Q_PCEN_n;
assign  o_DFFD_7E_A_Q = DFFD_7E_A_Q;
assign  o_DFFD_7E_A_Q_PCEN_n = DFFD_7E_A_Q_PCEN_n;

always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_H_CNTR > 9'd190 && ABS_H_CNTR < 9'd207)
        begin
            DFFD_7E_A_Q <= 1'b1;
        end
        else
        begin
            DFFD_7E_A_Q <= 1'b0;
        end

        if(ABS_H_CNTR == 9'd190) //positive edge clock enable of DFFD_7E_A_Q, goes low when H191
        begin
            DFFD_7E_A_Q_PCEN_n <= 1'b0;
        end
        else
        begin
            DFFD_7E_A_Q_PCEN_n <= 1'b1;
        end
    end
end

//LS175 8F
reg     [3:0]   DFFQ_8F_Q = 4'h8;
assign  o_DFFQ_8F_Q3 = DFFQ_8F_Q[3];
assign  o_DFFQ_8F_Q2 = DFFQ_8F_Q[2];
assign  o_DFFQ_8F_Q1 = DFFQ_8F_Q[1];
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_H_CNTR[3:0] == 4'd7)
        begin
            DFFQ_8F_Q[3] <= ABS_H_CNTR[8]; //goes low when H136-263
            DFFQ_8F_Q[2] <= DFFD_7H_B_Q;
            DFFQ_8F_Q[1] <= DFFD_8E_B_Q;
            DFFQ_8F_Q[0] <= 1'b1; //not used 
        end
    end
end

//CPU board uses inverted DFFD_8F_Q[2] as an async clock. A messy solution for this.
reg             DFFQ_8F_Q2_NCEN_n;

always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_V_CNTR == 9'd496 && ABS_H_CNTR == 9'd134)
        begin
            o_DFFQ_8F_Q2_NCEN_n <= 1'b0;
        end
        else
        begin
            o_DFFQ_8F_Q2_NCEN_n <= 1'b1;
        end
    end
end

// Vsync adjustment for 60Hz, Adjust hsync to center image
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_V_CNTR >= 9'd249 && ABS_V_CNTR <= 9'd251)
        begin
            vsync_tune <= 1'b0;
        end
        else
        begin
            vsync_tune <= 1'b1;
        end

        if(ABS_H_CNTR > 9'd171 && ABS_H_CNTR < 9'd210)
        begin
            hsync_tune <= 1'b0;
        end
        else
        begin
            hsync_tune <= 1'b1;
        end
    end
end

//CSYNC
wire            DMUX_7F_Y4_n =  ((ABS_V_CNTR[8] | DFFD_7H_B_Q) == 1'b1) ? 1'b1 :
                                (ABS_V_CNTR[5:3] == 3'd4) ? 1'b0 : 1'b1; //goes low V224-231

assign  o_CSYNC_n = DMUX_7F_Y4_n & DFFD_7E_B_Q_n;
reg vsync_tune, hsync_tune;
//for upscaler
assign  o_HSYNC_n = i_EMU_PXCNTR_ADJ_MODE[0] ? hsync_tune : DFFD_7E_B_Q_n;
assign  o_VSYNC_n = i_EMU_PXCNTR_ADJ_MODE[0] ? vsync_tune : DMUX_7F_Y4_n;

assign  o_HBLANK_n = DFFQ_8F_Q[3];
assign  o_VBLANK_n = ~DFFQ_8F_Q[1];






///////////////////////////////////////////////////////////
//////  BACKGROUND TILEMAP(1024*512)
////

/*
    *Psychic 5 is a vertical screen game, so vertical scrolling effect 
    that appears during play is actually horizontal scroll.

    -----------> CRT scanline direction

                        LEFT     <-- effective screen direction, if i_FLIP is 0)
            2 pixels per nibble                 |
           |---|---|---|---|                    |
           c c c c c c c c A A A A A A A A      V
           c c c c c c c c A A A A A A A A
           c c c c c c c c A A A A A A A A
           c c c c c c c c A A A A A A A A
           c c c c c c c c A A A A A A A A
           c c c c c c c c A A A A A A A A
    D      c c c c c c c c A A A A A A A A
    O      c c c c c c c c A A A A A A A A      U
    W      D D D D D D D D b b b b b b b b      P
    N      D D D D D D D D b b b b b b b b
           D D D D D D D D b b b b b b b b
           D D D D D D D D b b b b b b b b
           D D D D D D D D b b b b b b b b
           D D D D D D D D b b b b b b b b
           D D D D D D D D b b b b b b b b
           D D D D D D D D b b b b b b b b

                        RIGHT

    16*16 tileset is composed of 4 consecutive 8x8 tiles, and the order is:
    A -> b -> c -> D

    Hscroll[0] selects a pixel in a nibble

    BG ROM address bits
    [6]   : tile select(horizontally, 2 tiles) - hscroll[3] ^ ~HFLIP  !Attention! HFLIP is inverted
    [5]   : tile select(vertically, 2 tiles) - vscroll[3] ^ VFLIP
    [4:2] : line select(8 lines per 8*8 sprites) - vscroll[2:0] ^ VFLIP
    [1:0] : nibble select(4 nibbles per tileline) - hscroll[2:1] ^ HFLIP
*/


//
//  scroll value register cs decoder
//

reg     [4:0]   reg_cs_n;
wire            tmbg_ctrl_reg_en_n;
wire            vscroll_msb_reg_en_n;
wire            vscroll_lsb_reg_en_n;
wire            hscroll_msb_reg_en_n;
wire            hscroll_lsb_reg_en_n;
assign  {tmbg_ctrl_reg_en_n, vscroll_msb_reg_en_n, vscroll_lsb_reg_en_n, hscroll_msb_reg_en_n, hscroll_lsb_reg_en_n} = reg_cs_n;

always @(*)
begin
    if((i_CTRL_WR_n | i_TM_BG_SCR_CS_n | ~i_ADDR_BUS[3]) == 1'b0) //3A LS138
    begin
        case(i_ADDR_BUS[2:0])
            3'd0: reg_cs_n <= 5'b11110; //C308
            3'd1: reg_cs_n <= 5'b11101; //C309
            3'd2: reg_cs_n <= 5'b11011; //C30A
            3'd3: reg_cs_n <= 5'b10111; //C30B
            3'd4: reg_cs_n <= 5'b01111; //C30C
            default: reg_cs_n <= 5'b11111;
        endcase
    end
    else
    begin
        reg_cs_n <= 5'b11111;
    end
end



//
//  color control register
//

//2C LS74 A
reg     [1:0]   tmbg_ctrl_reg;
wire            tmbg_force_grayscale; //1=grayscale 0=normal
wire            tmbg_force_black_n; //1=normal 0=black
assign  {tmbg_force_grayscale, tmbg_force_black_n} = tmbg_ctrl_reg;
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(tmbg_ctrl_reg_en_n == 1'b0)
        begin
            tmbg_ctrl_reg <= i_DATA_WRITE_BUS[1:0];
        end
    end
end



//
//  horizontal scroll section
//

wire    [7:0]   hscroll_lsb_sum;
wire            hscroll_lsb_carry;

//HSCROLL LSBs
M67673 #(.initval(initializer_buffer[39:32])) HSCROLL_LSB_REG
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (o_EMU_CLK6MPCEN_n          ),

    .i_REGEN_n                  (hscroll_lsb_reg_en_n       ),
    .i_REGDIN                   (i_DATA_WRITE_BUS           ),

    .i_CNTR                     (FLIP_HV_BUS                ),

    .o_SUM                      (hscroll_lsb_sum            ),
    .o_CARRY                    (hscroll_lsb_carry          )
);

//HSCROLL MSBs
reg     [2:0]   hscroll_msb_reg = initializer_buffer[26:24]; // 3C LS174
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(!hscroll_msb_reg_en_n)
        begin
            hscroll_msb_reg <= i_DATA_WRITE_BUS[2:0]; 
        end
    end
end



wire    [2:0]   hscroll_msb_sum = hscroll_lsb_carry + {{2{FLIP_64HA}}, ABS_256H_n} + hscroll_msb_reg; //3B LS283

reg     [10:0]  hscroll_addr; //1C LS273 and 3F LS174
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        hscroll_addr <= {hscroll_msb_sum, hscroll_lsb_sum};
    end
end



//
//  vertical scroll section
//

//LS273 6B
reg     [7:0]   flip_h_bus;
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(!DFFD_7E_A_Q_PCEN_n)
        begin
            flip_h_bus <= FLIP_HV_BUS;
        end
    end
end

wire    [8:0]   vscroll_addr;

//VSCROLL LSBs
M67673 #(.initval(initializer_buffer[23:16])) VSCROLL_LSB_REG
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (o_EMU_CLK6MPCEN_n          ),

    .i_REGEN_n                  (vscroll_lsb_reg_en_n       ),
    .i_REGDIN                   (i_DATA_WRITE_BUS           ),

    .i_CNTR                     (flip_h_bus                 ),

    .o_SUM                      (vscroll_addr[7:0]          ),
    .o_CARRY                    (vscroll_addr[8]            )
);

//VSCROLL MSB
reg             vscroll_msb_reg = initializer_buffer[8]; //, 6A LS74 A
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(!vscroll_msb_reg_en_n)
        begin
            vscroll_msb_reg <= i_DATA_WRITE_BUS[0]; 
        end
    end
end



//
//  tilemap RAM
//

wire            tmbg_eotl_n = ~&{hscroll_addr[2:0] ^ {3{i_FLIP}}}; //3K LS10 A
wire            tmbg_attrsel;

wire            tmbg_ram_rd_n = (i_TM_BG_ATTR_CS_n == 1'b0) ? i_CTRL_RD_n : 1'b0;
wire            tmbg_ram_wr_n = (i_TM_BG_ATTR_CS_n == 1'b0) ? i_CTRL_WR_n : 1'b1;
wire    [12:0]  tmbg_ram_addr = (i_TM_BG_ATTR_CS_n == 1'b0) ? i_ADDR_BUS : 
                                                              {hscroll_addr[10:4], vscroll_msb_reg ^ vscroll_addr[8], vscroll_addr[7:4], tmbg_attrsel};
wire    [7:0]   tmbg_ram_dout;

wire    [3:0]   tmbg_palettecode;
wire    [9:0]   tmbg_tilecode;
wire            tmbg_vflip;
wire            tmbg_hflip, tmbg_hflip_dlyd;

N8633V #(.aw( 13 ), .simhexfile()) TMBG_RAM
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (o_EMU_CLK6MPCEN_n          ),

    .i_IOEN_n                   (i_TM_BG_ATTR_CS_n          ),
    .i_IODIR                    (i_CTRL_RD_n                ),
    .i_DIN                      (i_DATA_WRITE_BUS           ),
    .o_DOUT                     (tmbg_ram_dout              ),

    .i_RAMRD_n                  (tmbg_ram_rd_n              ),
    .i_RAMWR_n                  (tmbg_ram_wr_n              ),
    .i_ADDR                     (tmbg_ram_addr              ),

    .i_ENDOFTILELINE_n          (tmbg_eotl_n                ),
    .i_FORCEPALETTEZERO_n       (tmbg_force_black_n         ),
    .o_TILEATTRSEL              (tmbg_attrsel               ),

    .o_PALETTECODE              (tmbg_palettecode           ),
    .o_TILECODE                 (tmbg_tilecode              ),

    .o_HFLIP                    (tmbg_hflip                 ),
    .o_HFLIP_DLYD               (tmbg_hflip_dlyd            ),
    .o_VFLIP                    (tmbg_vflip                 )
);



//
//  background tilemap ROM
//

wire             tmbg_rom_2k_cs_n = tmbg_tilecode[9]; //low half
wire             tmbg_rom_2m_cs_n = ~tmbg_tilecode[9]; //high half
wire    [15:0]   tmbg_rom_addr = {tmbg_tilecode[8:0], 
                                  hscroll_addr[3] ^ ~tmbg_hflip, 
                                  vscroll_addr[3] ^ tmbg_vflip,
                                  vscroll_addr[2:0] ^ {3{tmbg_vflip}},
                                  hscroll_addr[2:1] ^ {2{tmbg_hflip}}};

wire    [7:0]   tmbg_rom_2k_dout;
wire    [7:0]   tmbg_rom_2m_dout;

//rom
`ifdef FASTBOOT
PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_2k.txt")) ROM_2K
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tmbg_rom_addr              ),
    .o_DOUT                     (tmbg_rom_2k_dout           ),
    .i_CS_n                     (tmbg_rom_2k_cs_n           ),
    .i_RD_n                     (1'b0                       )
);

PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_2m.txt")) ROM_2M
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tmbg_rom_addr              ),
    .o_DOUT                     (tmbg_rom_2m_dout           ),
    .i_CS_n                     (tmbg_rom_2m_cs_n           ),
    .i_RD_n                     (1'b0                       )
);

`else
PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile()) ROM_2K
(
    .i_EMU_PROG_CLK             (i_EMU_MCLK                 ),
    .i_EMU_PROG_ADDR            (i_EMU_BRAM_ADDR[15:0]      ),
    .i_EMU_PROG_DIN             (i_EMU_BRAM_DATA            ),
    .i_EMU_PROG_CS_n            (i_EMU_BRAM_TMBGROM_CS_n | i_EMU_BRAM_ADDR[16]),
    .i_EMU_PROG_WR_n            (i_EMU_BRAM_WR_n            ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tmbg_rom_addr              ),
    .o_DOUT                     (tmbg_rom_2k_dout           ),
    .i_CS_n                     (tmbg_rom_2k_cs_n           ),
    .i_RD_n                     (1'b0                       )
);

PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile()) ROM_2M
(
    .i_EMU_PROG_CLK             (i_EMU_MCLK                 ),
    .i_EMU_PROG_ADDR            (i_EMU_BRAM_ADDR[15:0]      ),
    .i_EMU_PROG_DIN             (i_EMU_BRAM_DATA            ),
    .i_EMU_PROG_CS_n            (i_EMU_BRAM_TMBGROM_CS_n | ~i_EMU_BRAM_ADDR[16]),
    .i_EMU_PROG_WR_n            (i_EMU_BRAM_WR_n            ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tmbg_rom_addr              ),
    .o_DOUT                     (tmbg_rom_2m_dout           ),
    .i_CS_n                     (tmbg_rom_2m_cs_n           ),
    .i_RD_n                     (1'b0                       )
);

`endif



//
//  background tilemap pixel latch and mux
//

wire            tmbg_pixellatch_tick = ~(hscroll_addr[0] ^ i_FLIP); //1D 3K
reg     [7:0]   tmbg_pixellatch; //tri-state bus of rom_2k and rom_2m, 2N LS273
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(tmbg_pixellatch_tick == 1'b0)
        begin
            if(tmbg_tilecode[9] == 1'b0)
            begin
                tmbg_pixellatch <= tmbg_rom_2k_dout;
            end
            else
            begin
                tmbg_pixellatch <= tmbg_rom_2m_dout;
            end
        end
    end
end

//3N LS157
wire    [3:0]   tmbg_pixelout = (~tmbg_force_black_n == 1'b1) ? 4'h0 :
                                ((hscroll_addr[0] ^ tmbg_hflip_dlyd) == 1'b0) ? tmbg_pixellatch[7:4] : tmbg_pixellatch[3:0];




///////////////////////////////////////////////////////////
//////  FOREGROUND TILEMAP(256*256)
////

//
//  tilemap RAM
//

wire            tmfg_eotl_n = ~&{ABS_H_CNTR[2:0]}; //8D LS20 B
wire            tmfg_attrsel;

wire            tmfg_ram_rd_n = (i_TM_FG_ATTR_CS_n == 1'b0) ? i_CTRL_RD_n : 1'b0;
wire            tmfg_ram_wr_n = i_TM_FG_ATTR_CS_n | i_CTRL_WR_n;
wire    [10:0]  tmfg_ram_addr = (i_TM_FG_ATTR_CS_n == 1'b0) ? i_ADDR_BUS[10:0] : 
                                                              {FLIP_HV_BUS[7:3], flip_h_bus[7:3], tmfg_attrsel};
wire    [7:0]   tmfg_ram_dout;

wire    [3:0]   tmfg_palettecode;
wire    [9:0]   tmfg_tilecode;
wire            tmfg_vflip;
wire            tmfg_hflip, tmfg_hflip_dlyd;

N8633V #(.aw( 11 ), .simhexfile()) TMFG_RAM
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (o_EMU_CLK6MPCEN_n          ),

    .i_IOEN_n                   (i_TM_FG_ATTR_CS_n          ),
    .i_IODIR                    (i_CTRL_RD_n                ),
    .i_DIN                      (i_DATA_WRITE_BUS           ),
    .o_DOUT                     (tmfg_ram_dout              ),

    .i_RAMRD_n                  (tmfg_ram_rd_n              ),
    .i_RAMWR_n                  (tmfg_ram_wr_n              ),
    .i_ADDR                     (tmfg_ram_addr              ),

    .i_ENDOFTILELINE_n          (tmfg_eotl_n                ),
    .i_FORCEPALETTEZERO_n       (1'b1                       ),
    .o_TILEATTRSEL              (tmfg_attrsel               ),

    .o_PALETTECODE              (tmfg_palettecode           ),
    .o_TILECODE                 (tmfg_tilecode              ),

    .o_HFLIP                    (tmfg_hflip                 ),
    .o_HFLIP_DLYD               (tmfg_hflip_dlyd            ),
    .o_VFLIP                    (tmfg_vflip                 )
);



//
//  foreground tilemap ROM
//

wire    [14:0]  tmfg_rom_5f_addr = {tmfg_tilecode[9:0], 
                                    flip_h_bus[2:0] ^ {3{tmfg_vflip}}, 
                                    FLIP_HV_BUS[2:1]  ^ {2{tmfg_hflip}}};

wire    [7:0]   tmfg_rom_5f_dout;

`ifdef FASTBOOT
PROM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_5f.txt")) ROM_5F
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tmfg_rom_5f_addr           ),
    .o_DOUT                     (tmfg_rom_5f_dout           ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (1'b0                       )
);

`else
PROM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile()) ROM_5F
(
    .i_EMU_PROG_CLK             (i_EMU_MCLK                 ),
    .i_EMU_PROG_ADDR            (i_EMU_BRAM_ADDR[14:0]      ),
    .i_EMU_PROG_DIN             (i_EMU_BRAM_DATA            ),
    .i_EMU_PROG_CS_n            (i_EMU_BRAM_TMFGROM_CS_n    ),
    .i_EMU_PROG_WR_n            (i_EMU_BRAM_WR_n            ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tmfg_rom_5f_addr           ),
    .o_DOUT                     (tmfg_rom_5f_dout           ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (1'b0                       )
);

`endif


//
//  foreground tilemap pixel latch and mux
//

reg     [7:0]   tmfg_pixellatch; //tri-state bus of rom_2k and rom_2m, 2N LS273
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_H_CNTR[0] == 1'b1)
        begin
            tmfg_pixellatch <= tmfg_rom_5f_dout;
        end
    end
end

//5J LS157
wire    [3:0]   tmfg_pixelout = ((FLIP_HV_BUS[0] ^ tmfg_hflip_dlyd) == 1'b0) ? tmfg_pixellatch[7:4] : tmfg_pixellatch[3:0];
                                





///////////////////////////////////////////////////////////
//////  TILEMAP PALETTE RAM
////

//
//  address dffs
//

reg     [7:0]   tmbg_palette_addr_latch0; //5N LS374
reg     [7:0]   tmfg_palette_addr_latch0, tmfg_palette_addr_latch1; //7J LS273, 5M LS374
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        tmbg_palette_addr_latch0 <= {tmbg_palettecode, tmbg_pixelout}; //bg

        tmfg_palette_addr_latch0 <= {tmfg_palettecode, tmfg_pixelout}; //fg
        tmfg_palette_addr_latch1 <= tmfg_palette_addr_latch0;
    end
end


//
//  foreground tilemap transparency flag(4'hF = transparent)
//

reg             tmfg_trn_n; //5K LS74
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        tmfg_trn_n <= ~&{tmfg_palette_addr_latch0[3:0]};
    end
end



//
//  tilemap palette RAM address/control
//


wire    [8:0]   tm_palette_addr =   (i_TM_PALETTE_CS_n == 1'b0) ? i_ADDR_BUS[9:1] : //serve CPU first
                                    (tmfg_trn_n == 1'b0) ? {tmfg_trn_n, tmbg_palette_addr_latch0} : {tmfg_trn_n, tmfg_palette_addr_latch1}; 
                                                                   //transparent FG -> display BG : opaque FG -> display FG

wire    [15:0]  tm_palette_dout; //R[3:0], G[3:0], B[3:0]; low/high

wire            tm_palette_high_cs_n = ~i_TM_PALETTE_CS_n & ~i_ADDR_BUS[0]; //6N
wire            tm_palette_low_cs_n = ~i_TM_PALETTE_CS_n & i_ADDR_BUS[0]; //6M
wire            tm_palette_rd_n = (i_TM_PALETTE_CS_n == 1'b0) ? i_CTRL_RD_n : 1'b0;
wire            tm_palette_wr_n = (i_TM_PALETTE_CS_n == 1'b0) ? i_CTRL_WR_n : 1'b1;



//
//  tilemap palette RAM
//

//6M 6116
SRAM #(.aw( 9 ), .dw( 8 ), .pol( 1 ), .simhexfile()) TM_PALETTE_LOW
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tm_palette_addr            ),
    .i_DIN                      (i_DATA_WRITE_BUS           ),
    .o_DOUT                     (tm_palette_dout[15:8]      ),
    .i_CS_n                     (tm_palette_low_cs_n        ),
    .i_RD_n                     (tm_palette_rd_n            ),
    .i_WR_n                     (tm_palette_wr_n            )
);

//6N 6116
SRAM #(.aw( 9 ), .dw( 8 ), .pol( 1 ), .simhexfile()) TM_PALETTE_HIGH
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (tm_palette_addr            ),
    .i_DIN                      (i_DATA_WRITE_BUS           ),
    .o_DOUT                     (tm_palette_dout[7:0]       ),
    .i_CS_n                     (tm_palette_high_cs_n       ),
    .i_RD_n                     (tm_palette_rd_n            ),
    .i_WR_n                     (tm_palette_wr_n            )
);



//
//  grayscale LUT
//

wire    [8:0]   grayscale_lut_addr = {tm_palette_dout[7:5], tm_palette_dout[11:9], tm_palette_dout[15:13]}; //B G R
wire    [3:0]   tm_color_gray;

//grayscale conversion LUT MB7116H 512*4 2k PROM
`ifdef FASTBOOT
PROM #(.aw( 9 ), .dw( 4 ), .pol( 0 ), .simhexfile("roms/rom_7l.txt")) ROM_7L
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (grayscale_lut_addr         ),
    .o_DOUT                     (tm_color_gray              ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (1'b0                       )
);

`else
PROM #(.aw( 9 ), .dw( 4 ), .pol( 0 ), .simhexfile()) ROM_7L
(
    .i_EMU_PROG_CLK             (i_EMU_MCLK                 ),
    .i_EMU_PROG_ADDR            (i_EMU_BRAM_ADDR[8:0]       ),
    .i_EMU_PROG_DIN             (i_EMU_BRAM_DATA[3:0]       ),
    .i_EMU_PROG_CS_n            (i_EMU_BRAM_GRAYLUT_CS_n    ),
    .i_EMU_PROG_WR_n            (i_EMU_BRAM_WR_n            ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (grayscale_lut_addr         ),
    .o_DOUT                     (tm_color_gray              ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (1'b0                       )
);

`endif

//
//  outlatch
//

wire    [3:0]   tm_color_r = ((tmbg_force_grayscale & ~tmfg_trn_n) == 1'b0) ? tm_palette_dout[15:12] : tm_color_gray;
wire    [3:0]   tm_color_g = ((tmbg_force_grayscale & ~tmfg_trn_n) == 1'b0) ? tm_palette_dout[11:8] : tm_color_gray;
wire    [3:0]   tm_color_b = ((tmbg_force_grayscale & ~tmfg_trn_n) == 1'b0) ? tm_palette_dout[7:4] : tm_color_gray;






///////////////////////////////////////////////////////////
//////  SPRITE PALETTE
////

wire    [7:0]   obj_palette_addr =  (i_OBJ_PALETTE_CS_n == 1'b0) ? i_ADDR_BUS[8:1] : i_OBJ_PIXELIN;
wire    [15:0]  obj_palette_dout; //R[3:0], G[3:0], B[3:0], BLNDEN, RMODE, GMODE, BMODE
reg     [15:0]  obj_palette_latch;

wire            obj_palette_high_cs_n = ~i_OBJ_PALETTE_CS_n & ~i_ADDR_BUS[0]; //10C
wire            obj_palette_low_cs_n = ~i_OBJ_PALETTE_CS_n & i_ADDR_BUS[0]; //10B
wire            obj_palette_rd_n = (i_OBJ_PALETTE_CS_n == 1'b0) ? i_CTRL_RD_n : 1'b0;
wire            obj_palette_wr_n = (i_OBJ_PALETTE_CS_n == 1'b0) ? i_CTRL_WR_n : 1'b1;

//10B 6116
SRAM #(.aw( 8 ), .dw( 8 ), .pol( 1 ), .simhexfile()) OBJ_PALETTE_LOW
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (obj_palette_addr           ),
    .i_DIN                      (i_DATA_WRITE_BUS           ),
    .o_DOUT                     (obj_palette_dout[15:8]     ),
    .i_CS_n                     (obj_palette_low_cs_n       ),
    .i_RD_n                     (obj_palette_rd_n           ),
    .i_WR_n                     (obj_palette_wr_n           )
);

//10C 6116
SRAM #(.aw( 8 ), .dw( 8 ), .pol( 1 ), .simhexfile()) OBJ_PALETTE_HIGH
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (obj_palette_addr           ),
    .i_DIN                      (i_DATA_WRITE_BUS           ),
    .o_DOUT                     (obj_palette_dout[7:0]      ),
    .i_CS_n                     (obj_palette_high_cs_n      ),
    .i_RD_n                     (obj_palette_rd_n           ),
    .i_WR_n                     (obj_palette_wr_n           )
);

always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        obj_palette_latch <= obj_palette_dout; //9E 10E
    end
end






///////////////////////////////////////////////////////////
//////  SPRITE PRIORITY/MIXER
////

//
//  sprite transparency flag(4'hF = transparent)
//

reg             obj_trn_n; //5K LS74 B
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        obj_trn_n <= ~&{i_OBJ_PIXELIN[3:0]};
    end
end

//                   (tmfg = transparent & obj = opaque) or (tmfg = transparent & obj = opaque & obj enabled)
wire            mixer_tm_en = ~(~tmfg_trn_n & obj_trn_n) | (~tmfg_trn_n & obj_trn_n & obj_palette_latch[3]);

wire    [3:0]   obj_color_r = (obj_palette_latch[15:12] & {4{~tmfg_trn_n}}) ^ {4{obj_palette_latch[2]}};
wire    [3:0]   obj_color_g = (obj_palette_latch[11:8] & {4{~tmfg_trn_n}}) ^ {4{obj_palette_latch[1]}};
wire    [3:0]   obj_color_b = (obj_palette_latch[7:4] & {4{~tmfg_trn_n}}) ^ {4{obj_palette_latch[0]}};


//RED CHANNEL
wire    [3:0]   out_r;
wire            carry_r; 
wire            outen_r = carry_r | ~obj_palette_latch[2];
wire            forcewhite_r = carry_r & ~obj_palette_latch[2];

M67636 MIXER_R
(
    .i_OBJPIXEL                 (obj_color_r                ),
    .i_TMPIXEL                  (tm_color_r                 ),

    .i_TMEN                     (mixer_tm_en                ),
    .i_OUTEN                    (outen_r                    ),
    .i_FORCEWHITE               (forcewhite_r               ),

    .o_CARRY                    (carry_r                    ),
    .i_BLENDMODE                (obj_palette_latch[2]       ),

    .o_OUT                      (out_r                      )
);

//GREEN CHANNEL
wire    [3:0]   out_g;
wire            carry_g;
wire            outen_g = carry_g | ~obj_palette_latch[1];
wire            forcewhite_g = carry_g & ~obj_palette_latch[1];

M67636 MIXER_G
(
    .i_OBJPIXEL                 (obj_color_g                ),
    .i_TMPIXEL                  (tm_color_g                 ),

    .i_TMEN                     (mixer_tm_en                ),
    .i_OUTEN                    (outen_g                    ),
    .i_FORCEWHITE               (forcewhite_g               ),

    .o_CARRY                    (carry_g                    ),
    .i_BLENDMODE                (obj_palette_latch[1]       ),

    .o_OUT                      (out_g                      )
);

//BLUE CHANNEL
wire    [3:0]   out_b;
wire            carry_b;
wire            outen_b = carry_b | ~obj_palette_latch[0];
wire            forcewhite_b = carry_b & ~obj_palette_latch[0];

M67636 MIXER_B
(
    .i_OBJPIXEL                 (obj_color_b                ),
    .i_TMPIXEL                  (tm_color_b                 ),

    .i_TMEN                     (mixer_tm_en                ),
    .i_OUTEN                    (outen_b                    ),
    .i_FORCEWHITE               (forcewhite_b               ),

    .o_CARRY                    (carry_b                    ),
    .i_BLENDMODE                (obj_palette_latch[0]       ),

    .o_OUT                      (out_b                      )
);






///////////////////////////////////////////////////////////
//////  VIDEO OUTPUT LATCH
////

reg             driver_enable_0; //8N LS74 A
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(ABS_H_CNTR[2:0] == 3'd3)
        begin
            driver_enable_0 <= DFFQ_8F_Q[3] & DFFQ_8F_Q[2];
        end
    end
end

reg             driver_enable_1; //8N LS74 B
always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MNCEN_n)
    begin
        driver_enable_1 <= driver_enable_0;
    end
end

always @(posedge i_EMU_MCLK)
begin
    if(!o_EMU_CLK6MPCEN_n)
    begin
        if(driver_enable_1 == 1'b1)
        begin
            o_VIDEO_R <= out_r;
            o_VIDEO_G <= out_g;
            o_VIDEO_B <= out_b;
        end
        else
        begin
            o_VIDEO_R <= 4'h0;
            o_VIDEO_G <= 4'h0;
            o_VIDEO_B <= 4'h0;
        end
    end
end






///////////////////////////////////////////////////////////
//////  DATA OUTPUT MUX
////

wire    [7:0]   tm_palette_cpu_read = (i_ADDR_BUS[0] == 1'b0) ? tm_palette_dout[15:8] : tm_palette_dout[7:0];
wire    [7:0]   obj_palette_cpu_read = (i_ADDR_BUS[0] == 1'b0) ? obj_palette_dout[15:8] : obj_palette_dout[7:0];

always @(*)
begin
    if(!i_CTRL_RD_n)
    begin
        case({i_TM_BG_ATTR_CS_n, i_TM_FG_ATTR_CS_n, i_TM_PALETTE_CS_n, i_OBJ_PALETTE_CS_n})
            4'b0111: o_DATA_READ_BUS <= tmbg_ram_dout;
            4'b1011: o_DATA_READ_BUS <= tmfg_ram_dout;
            4'b1101: o_DATA_READ_BUS <= tm_palette_cpu_read;
            4'b1110: o_DATA_READ_BUS <= obj_palette_cpu_read;
            default: o_DATA_READ_BUS <= 8'hFF; //pull up
        endcase
    end
    else
    begin
        o_DATA_READ_BUS <= 8'hFF;
    end
end


endmodule