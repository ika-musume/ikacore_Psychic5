`timescale 10ns/10ns
module Psychic5_top_tb;

reg             MCLK = 1'b0; //12.000MHz
reg             CLK12MCEN_n = 1'b0;

wire            CLK6MPCEN;
wire    [8:0]   hcounter, vcounter;
wire    [3:0]   r, g, b;
reg             cpureset_n = 1'b0;

Psychic5_top main
(
    .i_EMU_MCLK                     (MCLK                   ),

    .i_EMU_CLK12MPCEN_n             (1'b0                   ),

    .i_EMU_MRST_n                     (cpureset_n             ),

    .o_VIDEO_R                      (r                      ),
    .o_VIDEO_G                      (g                      ),
    .o_VIDEO_B                      (b                      ),

    .__REF_CLK6MPCEN                (CLK6MPCEN              ),
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

initial begin
    #100 cpureset_n <= 1'b1;
end


endmodule