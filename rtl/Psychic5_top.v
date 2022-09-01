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

module Psychic5_top
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK12MPCEN_n,
    input   wire            i_EMU_CLK5MPCEN_n,
    input   wire            i_EMU_CLK5MNCEN_n,

    input   wire            i_EMU_INITRST_n,
    input   wire            i_EMU_SOFTRST_n,

    //for screen recording
    output  wire            __REF_PXCEN,
    output  wire    [8:0]   __REF_HCOUNTER,
    output  wire    [8:0]   __REF_VCOUNTER,

    //video
    output  wire            o_CSYNC_n,
    output  wire            o_HSYNC_n,
    output  wire            o_VSYNC_n,

    output  wire            o_HBLANK_n,
    output  wire            o_VBLANK_n,

    output  wire    [3:0]   o_VIDEO_R,
    output  wire    [3:0]   o_VIDEO_G,
    output  wire    [3:0]   o_VIDEO_B,

    output  wire    [15:0]  o_SOUND,

    input   wire    [7:0]   i_P1_BTN,
    input   wire    [7:0]   i_P2_BTN,
    input   wire    [7:0]   i_SYS_BTN,
    input   wire    [7:0]   i_DIPSW1,
    input   wire    [7:0]   i_DIPSW2,

    //SDRAM requests
    output  wire    [16:0]  o_EMU_MAINCPU_ADDR,
    input   wire    [7:0]   i_EMU_MAINCPU_DATA,
    output  wire            o_EMU_MAINCPU_RQ_n,

    output  wire    [16:0]  o_EMU_OBJROM_ADDR,
    input   wire    [7:0]   i_EMU_OBJROM_DATA,
    output  wire            o_EMU_OBJROM_RQ_n,

    //BRAM programming
    input   wire    [16:0]  i_EMU_BRAM_ADDR,
    input   wire    [7:0]   i_EMU_BRAM_DATA,
    input   wire            i_EMU_BRAM_WR_n,
    
    input   wire            i_EMU_BRAM_SOUNDROM_CS_n,
    input   wire            i_EMU_BRAM_TMBGROM_CS_n,
    input   wire            i_EMU_BRAM_TMFGROM_CS_n,
    input   wire            i_EMU_BRAM_GRAYLUT_CS_n,
    input   wire            i_EMU_BRAM_SEQROM_CS_n
);

//clock enable
wire            CLK6MPCEN, CLK6MNCEN;

//pixel counters
wire    [7:0]   FLIP_HV_BUS;
wire            ABS_4H, ABS_2H, ABS_1H;

//timings
wire            DFFD_7E_A_Q;
wire            DFFD_7E_A_Q_PCEN_n;
wire            DFFD_8E_A_Q;
wire            DFFD_8E_B_Q;
wire            DFFQ_8F_Q3;
wire            DFFQ_8F_Q2;
wire            DFFQ_8F_Q2_NCEN_n;
wire            DFFQ_8F_Q1;

//gfx related
wire            FLIP;
wire    [7:0]   OBJ_PIXEL;

//datapath
wire    [12:0]  ADDR_BUS;
wire    [7:0]   DATA_READ_BUS, DATA_WRITE_BUS; 
wire            CTRL_RD_n, CTRL_WR_n;
wire            TM_BG_ATTR_CS_n, TM_FG_ATTR_CS_n, TM_BG_SCR_CS_n, TM_PALETTE_CS_n, OBJ_PALETTE_CS_n;

Psychic5_video video_main
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),

    .i_EMU_CLK12MPCEN_n         (i_EMU_CLK12MPCEN_n         ),
    .o_EMU_CLK6MPCEN_n          (CLK6MPCEN                  ),
    .o_EMU_CLK6MNCEN_n          (CLK6MNCEN                  ),

    .i_EMU_INITRST_n            (i_EMU_INITRST_n            ),

    .i_ADDR_BUS                 (ADDR_BUS                   ),
    .o_DATA_READ_BUS            (DATA_READ_BUS              ),
    .i_DATA_WRITE_BUS           (DATA_WRITE_BUS             ),
    .i_CTRL_RD_n                (CTRL_RD_n                  ),
    .i_CTRL_WR_n                (CTRL_WR_n                  ),

    .i_TM_BG_ATTR_CS_n          (TM_BG_ATTR_CS_n            ),
    .i_TM_FG_ATTR_CS_n          (TM_FG_ATTR_CS_n            ),
    .i_TM_BG_SCR_CS_n           (TM_BG_SCR_CS_n             ),
    .i_TM_PALETTE_CS_n          (TM_PALETTE_CS_n            ),
    .i_OBJ_PALETTE_CS_n         (OBJ_PALETTE_CS_n           ),

    .i_FLIP                     (FLIP                       ),

    .o_FLIP_HV_BUS              (FLIP_HV_BUS                ),
    .o_ABS_4H( ABS_4H ), .o_ABS_2H( ABS_2H ), .o_ABS_1H( ABS_1H ),

    .o_DFFD_7E_A_Q              (DFFD_7E_A_Q                ),
    .o_DFFD_7E_A_Q_PCEN_n       (DFFD_7E_A_Q_PCEN_n         ),
    .o_DFFD_8E_A_Q              (DFFD_8E_A_Q                ),
    .o_DFFD_8E_B_Q              (DFFD_8E_B_Q                ),
    .o_DFFQ_8F_Q3               (DFFQ_8F_Q3                 ),
    .o_DFFQ_8F_Q2               (DFFQ_8F_Q2                 ),
    .o_DFFQ_8F_Q2_NCEN_n        (DFFQ_8F_Q2_NCEN_n          ),
    .o_DFFQ_8F_Q1               (DFFQ_8F_Q1                 ),

    .i_OBJ_PIXELIN              (OBJ_PIXEL                  ),

    .o_CSYNC_n                  (o_CSYNC_n                  ),
    .o_HSYNC_n                  (o_HSYNC_n                  ),
    .o_VSYNC_n                  (o_VSYNC_n                  ),
    
    .o_HBLANK_n                 (o_HBLANK_n                 ),
    .o_VBLANK_n                 (o_VBLANK_n                 ),

    .o_VIDEO_R                  (o_VIDEO_R                  ),
    .o_VIDEO_G                  (o_VIDEO_G                  ),
    .o_VIDEO_B                  (o_VIDEO_B                  ),

    .__REF_HCOUNTER             (__REF_HCOUNTER             ),
    .__REF_VCOUNTER             (__REF_VCOUNTER             ),
    .__REF_PXCEN                (__REF_PXCEN                ),

    .i_EMU_BRAM_ADDR            (i_EMU_BRAM_ADDR            ),
    .i_EMU_BRAM_DATA            (i_EMU_BRAM_DATA            ),
    .i_EMU_BRAM_WR_n            (i_EMU_BRAM_WR_n            ),

    .i_EMU_BRAM_TMBGROM_CS_n    (i_EMU_BRAM_TMBGROM_CS_n    ),
    .i_EMU_BRAM_TMFGROM_CS_n    (i_EMU_BRAM_TMFGROM_CS_n    ),
    .i_EMU_BRAM_GRAYLUT_CS_n    (i_EMU_BRAM_GRAYLUT_CS_n    )
);

Psychic5_cpuboard cpu_main
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),

    .i_EMU_CLK6MPCEN_n          (CLK6MPCEN                  ),
    .i_EMU_CLK6MNCEN_n          (CLK6MNCEN                  ),
    .i_EMU_CLK5MPCEN_n          (i_EMU_CLK5MPCEN_n          ),
    .i_EMU_CLK5MNCEN_n          (i_EMU_CLK5MNCEN_n          ),

    .i_EMU_INITRST_n            (i_EMU_INITRST_n            ),
    .i_EMU_SOFTRST_n            (i_EMU_SOFTRST_n            ),

    .i_P1_BTN                   (i_P1_BTN                   ),
    .i_P2_BTN                   (i_P2_BTN                   ),
    .i_SYS_BTN                  (i_SYS_BTN                  ),
    .i_DIPSW1                   (i_DIPSW1                   ),
    .i_DIPSW2                   (i_DIPSW2                   ),

    .o_SOUND                    (o_SOUND                    ),

    .o_ADDR_BUS                 (ADDR_BUS                   ),
    .i_DATA_READ_BUS            (DATA_READ_BUS              ),
    .o_DATA_WRITE_BUS           (DATA_WRITE_BUS             ),
    .o_CTRL_RD_n                (CTRL_RD_n                  ),
    .o_CTRL_WR_n                (CTRL_WR_n                  ),

    .o_TM_BG_ATTR_CS_n          (TM_BG_ATTR_CS_n            ),
    .o_TM_FG_ATTR_CS_n          (TM_FG_ATTR_CS_n            ),
    .o_TM_BG_SCR_CS_n           (TM_BG_SCR_CS_n             ),
    .o_TM_PALETTE_CS_n          (TM_PALETTE_CS_n            ),
    .o_OBJ_PALETTE_CS_n         (OBJ_PALETTE_CS_n           ),

    .o_FLIP                     (FLIP                       ),

    .i_FLIP_HV_BUS              (FLIP_HV_BUS                ),
    .i_ABS_4H( ABS_4H ), .i_ABS_2H( ABS_2H ), .i_ABS_1H( ABS_1H ),    

    .i_DFFD_7E_A_Q              (DFFD_7E_A_Q                ),
    .i_DFFD_7E_A_Q_PCEN_n       (DFFD_7E_A_Q_PCEN_n         ),
    .i_DFFD_8E_A_Q              (DFFD_8E_A_Q                ),
    .i_DFFD_8E_B_Q              (DFFD_8E_B_Q                ),
    .i_DFFQ_8F_Q3               (DFFQ_8F_Q3                 ),
    .i_DFFQ_8F_Q2               (DFFQ_8F_Q2                 ),
    .i_DFFQ_8F_Q2_NCEN_n        (DFFQ_8F_Q2_NCEN_n          ),
    .i_DFFQ_8F_Q1               (DFFQ_8F_Q1                 ),

    .o_OBJ_PIXELOUT             (OBJ_PIXEL                  ),

    //SDRAM requests
    .o_EMU_MAINCPU_ADDR         (o_EMU_MAINCPU_ADDR         ),
    .i_EMU_MAINCPU_DATA         (i_EMU_MAINCPU_DATA         ),
    .o_EMU_MAINCPU_RQ_n         (o_EMU_MAINCPU_RQ_n         ),

    .o_EMU_OBJROM_ADDR          (o_EMU_OBJROM_ADDR          ),
    .i_EMU_OBJROM_DATA          (i_EMU_OBJROM_DATA          ),
    .o_EMU_OBJROM_RQ_n          (o_EMU_OBJROM_RQ_n          ),

    //BRAM programming
    .i_EMU_BRAM_ADDR            (i_EMU_BRAM_ADDR            ),
    .i_EMU_BRAM_DATA            (i_EMU_BRAM_DATA            ),
    .i_EMU_BRAM_WR_n            (i_EMU_BRAM_WR_n            ),

    .i_EMU_BRAM_SOUNDROM_CS_n   (i_EMU_BRAM_SOUNDROM_CS_n   ),
    .i_EMU_BRAM_SEQROM_CS_n     (i_EMU_BRAM_SEQROM_CS_n     )
);


endmodule