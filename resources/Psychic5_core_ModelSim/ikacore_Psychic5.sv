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

`timescale 10ns / 10ns
module ikacore_Psychic5 (

);

//ioctl
wire    [15:0]  ioctl_index;
wire            ioctl_download;
wire    [26:0]  ioctl_addr;
wire    [7:0]   ioctl_data;
wire            ioctl_wr;
wire            ioctl_wait;

//SDRAM
wire    [15:0]  SDRAM_DQ;
wire    [12:0]  SDRAM_A;
wire            SDRAM_DQML;
wire            SDRAM_DQMH;
wire    [1:0]   SDRAM_BA;
wire            SDRAM_nWE;
wire            SDRAM_nCAS;
wire            SDRAM_nRAS;
wire            SDRAM_nCS;
wire            SDRAM_CKE;

//clock
reg             CLK60M = 1'b0;
always #1 CLK60M <= ~CLK60M;

reg             MRST = 1'b1;
initial #1200 MRST <= 1'b0;

reg             pll_locked = 1'b0;
initial #3500 pll_locked <= 1'b1;



ioctl_test ioctl_test (
    .i_HPSIO_CLK                (CLK60M                     ),
    .i_RST                      (MRST                       ),

    .o_IOCTL_INDEX              (ioctl_index                ),
    .o_IOCTL_DOWNLOAD           (ioctl_download             ),
    .o_IOCTL_ADDR               (ioctl_addr                 ),
    .o_IOCTL_DATA               (ioctl_data                 ),
    .o_IOCTL_WR                 (ioctl_wr                   ),
    .i_IOCTL_WAIT               (ioctl_wait                 )
);

mt48lc16m16a2 sdram_main (
    .Dq                         (SDRAM_DQ                   ),
    .Addr                       (SDRAM_A                    ),
    .Ba                         (SDRAM_BA                   ),
    .Clk                        (CLK60M                     ),
    .Cke                        (SDRAM_CKE                  ),
    .Cs_n                       (SDRAM_nCS                  ),
    .Ras_n                      (SDRAM_nRAS                 ),
    .Cas_n                      (SDRAM_nCAS                 ),
    .We_n                       (SDRAM_nWE                  ),
    .Dqm                        ({SDRAM_DQMH, SDRAM_DQML}   ),

    .downloading                (                           ),
    .VS                         (                           ),
    .frame_cnt                  (                           )
);






///////////////////////////////////////////////////////////
//////  CORE
////


wire            hsync_n, vsync_n;
wire            hblank_n, vblank_n;
wire    [3:0]   video_r, video_g, video_b; //need to use color conversion LUT
wire            pxcen;
wire            master_reset = MRST | ~pll_locked;


Psychic5_emu emulator_top (
    .i_EMU_MCLK                 (CLK60M                     ),
    .i_EMU_INITRST              (master_reset               ),
    .i_EMU_SOFTRST              (1'b0                       ),

    .o_HSYNC_n                  (hsync_n                    ),
    .o_VSYNC_n                  (vsync_n                    ),
    .o_HBLANK_n                 (hblank_n                   ),
    .o_VBLANK_n                 (vblank_n                   ),

    .o_VIDEO_R                  (video_r                    ),
    .o_VIDEO_G                  (video_g                    ),
    .o_VIDEO_B                  (video_b                    ),

    .o_SOUND                    (                           ),

    .o_PXCEN                    (pxcen                      ),

    .i_JOYSTICK0                (16'h00                     ),
    .i_JOYSTICK1                (16'h00                     ),

    .ioctl_index                (ioctl_index                ),
    .ioctl_download             (ioctl_download             ),
    .ioctl_addr                 (ioctl_addr                 ),
    .ioctl_data                 (ioctl_data                 ),
    .ioctl_wr                   (ioctl_wr                   ),
    .ioctl_wait                 (ioctl_wait                 ),

    .sdram_dq                   (SDRAM_DQ                   ),
    .sdram_a                    (SDRAM_A                    ),
    .sdram_dqml                 (SDRAM_DQML                 ),
    .sdram_dqmh                 (SDRAM_DQMH                 ),
    .sdram_ba                   (SDRAM_BA                   ),
    .sdram_nwe                  (SDRAM_nWE                  ),
    .sdram_ncas                 (SDRAM_nCAS                 ),
    .sdram_nras                 (SDRAM_nRAS                 ),
    .sdram_ncs                  (SDRAM_nCS                  ),
    .sdram_cke                  (SDRAM_CKE                  )
);


endmodule