`timescale 10ns/10ns
module Psychic5_video_tb;

reg             MCLK = 1'b0; //12.000MHz
reg             CLK12MCEN_n = 1'b0;

wire            CLK6MPCEN;
wire            CLK6MNCEN;

wire    [8:0]   hcounter, vcounter;
wire    [3:0]   r, g, b;

Psychic5_video main
(
    .i_EMU_MCLK                     (MCLK                   ),

    .i_EMU_CLK12MPCEN_n             (1'b0                   ),
    .o_EMU_CLK6MPCEN_n              (CLK6MPCEN              ),
    .o_EMU_CLK6MNCEN_n              (CLK6MNCEN              ),

    .i_CPU_ADDR                     (13'h0000               ),
    .o_CPU_DIN                      (                       ),
    .i_CPU_DOUT                     (8'hFF                  ),
    .i_CPU_RD_n                     (1'b1                   ),
    .i_CPU_WR_n                     (1'b1                   ),

    .i_TM_BG_ATTR_CS_n              (1'b1                   ),
    .i_TM_FG_ATTR_CS_n              (1'b1                   ),
    .i_TM_BG_SCR_CS_n               (1'b1                   ),
    .i_TM_PALETTE_CS_n              (1'b1                   ),

    .i_FLIP                         (1'b0                   ),

    .o_CSYNC                        (                       ),
    .o_VIDEO_R                      (r                      ),
    .o_VIDEO_G                      (g                      ),
    .o_VIDEO_B                      (b                      ),

    .__REF_HCOUNTER                 (hcounter               ),
    .__REF_VCOUNTER                 (vcounter               )
);

Psychic5_screensim screen_main
(
    .i_EMU_MCLK                     (MCLK                   ),
    .i_EMU_CLK6MPCEN_n              (CLK6MPCEN              ),
    .i_HCOUNTER                     (hcounter               ),
    .i_VCOUNTER                     (vcounter               ),
    .i_VIDEODATA                    ({r, g, b}              )
);

always #1 MCLK = ~MCLK;


endmodule