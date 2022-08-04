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

`include "rtl/Psychic5_emu_header.v"

module Psychic5_sound
(
    input   wire            i_EMU_MCLK,

    input   wire            i_EMU_CLK5MPCEN_n,
    input   wire            i_EMU_CLK5MNCEN_n,
    input   wire            i_EMU_OPNCEN_n,

    input   wire            i_EMU_INITRST_n,

    input   wire            i_SOUNDCPU_FORCE_RST_n,

    input   wire    [7:0]   i_SOUNDCODE,

    output  wire    [15:0]  o_SOUND,

    input   wire    [16:0]  i_EMU_BRAM_ADDR,
    input   wire    [7:0]   i_EMU_BRAM_DATA,
    input   wire            i_EMU_BRAM_WR_n,

    input   wire            i_EMU_BRAM_SOUNDROM_CS_n
);






///////////////////////////////////////////////////////////
//////  MAIN CPU
////

wire            SOUNDCPU_RST_n = i_EMU_INITRST_n & i_SOUNDCPU_FORCE_RST_n;

wire            SOUNDCPU_CTRL_IORQ_n, SOUNDCPU_CTRL_MREQ_n;
wire            SOUNDCPU_CTRL_RD_n, SOUNDCPU_CTRL_WR_n;

wire    [15:0]  SOUNDCPU_ADDR_BUS;
reg     [7:0]   SOUNDCPU_DATA_READ_BUS;
wire    [7:0]   SOUNDCPU_DATA_WRITE_BUS;

wire            SOUNDCPU_INT_n;

T80pa soundcpu (
    .RESET_n                    (SOUNDCPU_RST_n             ),
    .CLK                        (i_EMU_MCLK                 ),
    .CEN_p                      (~i_EMU_CLK5MPCEN_n         ),
    .CEN_n                      (~i_EMU_CLK5MNCEN_n         ),
    .WAIT_n                     (1'b1                       ),
    .INT_n                      (SOUNDCPU_INT_n             ),
    .NMI_n                      (1'b1                       ),
    .RD_n                       (SOUNDCPU_CTRL_RD_n         ),
    .WR_n                       (SOUNDCPU_CTRL_WR_n         ),
    .A                          (SOUNDCPU_ADDR_BUS          ),
    .DI                         (SOUNDCPU_DATA_READ_BUS     ),
    .DO                         (SOUNDCPU_DATA_WRITE_BUS    ),
    .IORQ_n                     (SOUNDCPU_CTRL_IORQ_n       ),
    .M1_n                       (                           ),
    .MREQ_n                     (SOUNDCPU_CTRL_MREQ_n       ),
    .BUSRQ_n                    (1'b1                       ),
    .BUSAK_n                    (                           ),
    .RFSH_n                     (                           ),
    .out0                       (1'b0                       ), //?????
    .HALT_n                     (                           )
);




///////////////////////////////////////////////////////////
//////  ADDRESS DECODER
////

// ADDR [15] [14] [13]
//        0    X    X  = SOUND MAINROM
//        1    0    X  = SOUND MAINROM
//        1    1    0  = SOUND MAINRAM
//        1    1    1  = SOUND CODE

//memory space
wire            soundprog_cs_n =    (SOUNDCPU_ADDR_BUS[15] == 1'b0) ? SOUNDCPU_CTRL_MREQ_n :
                                    (SOUNDCPU_ADDR_BUS[14] == 1'b0) ? SOUNDCPU_CTRL_MREQ_n : 1'b1;
wire            soundram_cs_n  =    (SOUNDCPU_ADDR_BUS[15:13] == 3'b110) ? SOUNDCPU_CTRL_MREQ_n : 1'b1;
wire            soundcode_cs_n =    (SOUNDCPU_ADDR_BUS[15:13] == 3'b111) ? SOUNDCPU_CTRL_MREQ_n : 1'b1;

//IO space
wire            sound_opn1_cs_n = (SOUNDCPU_ADDR_BUS[7] == 1'b0) ? SOUNDCPU_CTRL_IORQ_n : 1'b1;
wire            sound_opn2_cs_n = (SOUNDCPU_ADDR_BUS[7] == 1'b1) ? SOUNDCPU_CTRL_IORQ_n : 1'b1;




///////////////////////////////////////////////////////////
//////  MAIN ROM/RAM
////

//
//  MAIN SOUND ROM
//

//0000-BFFF main sound program rom(27256, use 0000-7FFF only)
wire    [7:0]       soundprog_dout;


`ifdef FASTBOOT //USE BLOCK RAM FOR FAST BOOT
PROM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_2b.txt")) ROM_2B
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (SOUNDCPU_ADDR_BUS[14:0]    ),
    .o_DOUT                     (soundprog_dout             ),
    .i_CS_n                     (soundprog_cs_n             ),
    .i_RD_n                     (1'b0                       )
);

`else
PROM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile()) ROM_2B
(
    .i_EMU_PROG_CLK             (i_EMU_MCLK                 ),
    .i_EMU_PROG_ADDR            (i_EMU_BRAM_ADDR[14:0]      ),
    .i_EMU_PROG_DIN             (i_EMU_BRAM_DATA            ),
    .i_EMU_PROG_CS_n            (i_EMU_BRAM_SOUNDROM_CS_n   ),
    .i_EMU_PROG_WR_n            (i_EMU_BRAM_WR_n            ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (SOUNDCPU_ADDR_BUS[14:0]    ),
    .o_DOUT                     (soundprog_dout             ),
    .i_CS_n                     (soundprog_cs_n             ),
    .i_RD_n                     (1'b0                       )
);

`endif




//
//  MAIN SOUND RAM
//

wire    [7:0]       soundram_dout;

SRAM #(.aw( 11 ), .dw( 8 ), .pol( 1 ), .simhexfile()) MAINRAM
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (SOUNDCPU_ADDR_BUS[10:0]    ),
    .i_DIN                      (SOUNDCPU_DATA_WRITE_BUS    ),
    .o_DOUT                     (soundram_dout              ),
    .i_CS_n                     (soundram_cs_n              ),
    .i_RD_n                     (SOUNDCPU_CTRL_RD_n         ),
    .i_WR_n                     (SOUNDCPU_CTRL_WR_n         )
);




///////////////////////////////////////////////////////////
//////  YAMAHA OPN
////

//YM2203C x2
wire    [7:0]   opn1_dout, opn2_dout;

wire            [9:0]   opn1_psg, opn2_psg;
wire    signed  [15:0]  opn1_fm, opn2_fm;

jt03 opn1 (
    .rst                        (~SOUNDCPU_RST_n            ),
    .clk                        (i_EMU_MCLK                 ),
    .cen                        (~i_EMU_OPNCEN_n            ),
    .din                        (SOUNDCPU_DATA_WRITE_BUS    ),
    .addr                       (SOUNDCPU_ADDR_BUS[0]       ),
    .cs_n                       (sound_opn1_cs_n            ),
    .wr_n                       (SOUNDCPU_CTRL_WR_n         ),

    .dout                       (opn1_dout                  ),
    .irq_n                      (SOUNDCPU_INT_n        ),

    // I/O pins used by YM2203 embedded YM2149 chip
    .IOA_in                     (8'hFF                      ),
    .IOB_in                     (8'hFF                      ),

    // Separated output
    .psg_A                      (                           ),
    .psg_B                      (                           ),
    .psg_C                      (                           ),
    .fm_snd                     (opn1_fm                    ),

    // combined output
    .psg_snd                    (opn1_psg                   ),
    .snd                        (                           ),
    .snd_sample                 (                           ),

    // Debug
    .debug_view                 (                           )
);

jt03 opn2 (
    .rst                        (~SOUNDCPU_RST_n            ),
    .clk                        (i_EMU_MCLK                 ),
    .cen                        (~i_EMU_OPNCEN_n            ),
    .din                        (SOUNDCPU_DATA_WRITE_BUS    ),
    .addr                       (SOUNDCPU_ADDR_BUS[0]       ),
    .cs_n                       (sound_opn2_cs_n            ),
    .wr_n                       (SOUNDCPU_CTRL_WR_n         ),

    .dout                       (opn2_dout                  ),
    .irq_n                      (                           ),

    // I/O pins used by YM2203 embedded YM2149 chip
    .IOA_in                     (8'hFF                      ),
    .IOB_in                     (8'hFF                      ),

    // Separated output
    .psg_A                      (                           ),
    .psg_B                      (                           ),
    .psg_C                      (                           ),
    .fm_snd                     (opn2_fm                    ),

    // combined output
    .psg_snd                    (opn2_psg                   ),
    .snd                        (                           ),
    .snd_sample                 (                           ),

    // Debug
    .debug_view                 (                           )
);




///////////////////////////////////////////////////////////
//////  BUS OUTPUT MUX
////

always @(*)
begin
    if(!SOUNDCPU_CTRL_RD_n)
    begin
        if(!SOUNDCPU_CTRL_MREQ_n) //memory space
        begin
            case({soundprog_cs_n, soundram_cs_n, soundcode_cs_n})
                3'b011: SOUNDCPU_DATA_READ_BUS <= soundprog_dout;
                3'b101: SOUNDCPU_DATA_READ_BUS <= soundram_dout;
                3'b110: SOUNDCPU_DATA_READ_BUS <= i_SOUNDCODE;
                default: SOUNDCPU_DATA_READ_BUS <= 8'hFF; //pull up
            endcase
        end
        else if(!SOUNDCPU_CTRL_IORQ_n) //IO space
        begin
            case({sound_opn1_cs_n, sound_opn2_cs_n})
                2'b01: SOUNDCPU_DATA_READ_BUS <= opn1_dout;
                2'b10: SOUNDCPU_DATA_READ_BUS <= opn2_dout;
                default: SOUNDCPU_DATA_READ_BUS <= 8'hFF; //pull up
            endcase
        end
        else
        begin
            SOUNDCPU_DATA_READ_BUS <= 8'hFF; //pull up
        end
    end
    else 
    begin
        SOUNDCPU_DATA_READ_BUS <= 8'hFF; //pull up
    end
end




///////////////////////////////////////////////////////////
//////  SOUND MIXER
////

/*
    OPN1  
    |   
    |          2.2n + 4.7k parallel
    |               |--(Z)--|
    |               |       |   + 10u
    |-----(YM3014)------|>--------||---(4.7k)---|
    |                                           |
    |---(PSG_A)---(1k)--|                       |
    |---(PSG_B)---(1k)--|                       |
    |---(PSG_C)---(1k)--|       + 10u           |
                        |---------||---(6.8k)---|
                        |                       |
                      (1k)                      |
                        |                       |
                       GND                      |
                                                |
    OPN2                                        |
    |          2.2n + 4.7k parallel             |
    |               |--(Z)--|                   |
    |               |       |   + 10u           |
    |-----(YM3014)------|>--------||---(4.7k)---|
    |                                           |
    |---(PSG_A)---(1k)--|                       |
    |---(PSG_B)---(1k)--|                       |
    |---(PSG_C)---(1k)--|       + 10u           |
                        |---------||---(6.8k)---|
                        |                       |
                      (1k)                      |
                        |                       |
                       GND                      |
                                              (1k)<-------------->>>
                                                |   | 6.8n  | 4.7n
                                                |   =       =
                                                |   |       |
                                               GND GND     GND
                        
    FM: 16bit signed
    PSG: 8bit unsigned

    SXXX_XXXX_XXXX_XXXX FM CHANNEL
              XXXX_XXXX PSG SINGLE CHANNEL

           XX_XXXX_XXXX PSG MIXED   

*/


/*
                     PSG                 FM
    stage 1    multiply volume     multiply volume
    stage 2              sum two channels
    stage 3            sum two OPN channels
*/

//3bit ring counter
reg     [2:0]   mixer_rc = 3'b110;
always @(posedge i_EMU_MCLK) begin
    if(!i_EMU_INITRST_n) begin
        mixer_rc <= 3'b110;
    end
    else begin
        mixer_rc[0] <= mixer_rc[2];
        mixer_rc[2:1] <= mixer_rc[1:0];
    end
end

reg     signed  [15:0]  st1_opn1_psg, st1_opn2_psg, st1_opn1_fm, st1_opn2_fm;
reg     signed  [15:0]  st2_opn1_snd, st2_opn2_snd;
reg     signed  [16:0]  st3_mixed_snd;
assign  o_SOUND = {st3_mixed_snd[16], st3_mixed_snd[14:0]}; //saturating

always @(posedge i_EMU_MCLK) begin
    if(!i_EMU_INITRST_n) begin
        st1_opn1_psg <= 16'sd0; st1_opn2_psg <= 16'sd0; st1_opn1_fm <= 16'sd0; st1_opn2_fm <= 16'sd0;
        st2_opn1_snd <= 16'sd0; st2_opn2_snd <= 16'sd0;
        st3_mixed_snd <= 16'sd0;
    end
    else begin
        if(!mixer_rc[0]) begin
            st1_opn1_psg <= $signed({1'b0, opn1_psg * 5'd5});
            st1_opn2_psg <= $signed({1'b0, opn2_psg * 5'd5});
            st1_opn1_fm <= opn1_fm * 16'sd1;
            st1_opn2_fm <= opn2_fm * 16'sd1;
        end
        else if(!mixer_rc[1]) begin
            st2_opn1_snd <= st1_opn1_psg + st1_opn1_fm;
            st2_opn2_snd <= st1_opn2_psg + st1_opn2_fm;
        end
        else if(!mixer_rc[2]) begin
            st3_mixed_snd <= st2_opn1_snd + st2_opn2_snd;
        end
    end
end


endmodule