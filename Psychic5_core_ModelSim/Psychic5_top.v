module Psychic5_top
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK12MPCEN_n,

    input   wire            i_EMU_MRST_n,

    output  wire    [3:0]   o_VIDEO_R,
    output  wire    [3:0]   o_VIDEO_G,
    output  wire    [3:0]   o_VIDEO_B,

    //for screen recording
    output  wire            __REF_CLK6MPCEN,
    output  wire    [8:0]   __REF_HCOUNTER,
    output  wire    [8:0]   __REF_VCOUNTER
);

//clock enable
wire            CLK6MPCEN, CLK6MNCEN;
assign  __REF_CLK6MPCEN = CLK6MPCEN;

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

wire    [7:0]   OBJ_PIXEL;


//datapath
wire    [13:0]  ADDR_BUS;
wire    [7:0]   DATA_READ_BUS, DATA_WRITE_BUS; 
wire            CTRL_RD_n, CTRL_WR_n;
wire            TM_BG_ATTR_CS_n, TM_FG_ATTR_CS_n, TM_BG_SCR_CS_n, TM_PALETTE_CS_n, OBJ_PALETTE_CS_n;

Psychic5_video video_main
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),

    .i_EMU_CLK12MPCEN_n         (1'b0                       ),
    .o_EMU_CLK6MPCEN_n          (CLK6MPCEN                  ),
    .o_EMU_CLK6MNCEN_n          (CLK6MNCEN                  ),

    .i_EMU_MRST_n               (i_EMU_MRST_n               ),

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

    .i_FLIP                     (1'b0                       ),

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

    .o_CSYNC                    (                           ),
    .o_VIDEO_R                  (o_VIDEO_R                  ),
    .o_VIDEO_G                  (o_VIDEO_G                  ),
    .o_VIDEO_B                  (o_VIDEO_B                  ),

    .__REF_HCOUNTER             (__REF_HCOUNTER             ),
    .__REF_VCOUNTER             (__REF_VCOUNTER             )
);

Psychic5_cpu cpu_main
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),

    .i_EMU_CLK6MPCEN_n          (CLK6MPCEN                  ),
    .i_EMU_CLK6MNCEN_n          (CLK6MNCEN                  ),

    .i_EMU_MRST_n               (i_EMU_MRST_n               ),

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

    .o_FLIP                     (                           ),

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

    .o_OBJ_PIXELOUT             (OBJ_PIXEL                  )
);


endmodule