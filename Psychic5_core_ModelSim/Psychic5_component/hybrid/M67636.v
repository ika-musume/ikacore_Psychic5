/*
    Mitsubishi M67636 color blender
*/

module M67636
(
    input   wire    [3:0]   i_OBJPIXEL,
    input   wire    [3:0]   i_TMPIXEL,

    input   wire            i_TMEN, //tilemap pixel value enable
    input   wire            i_OUTEN, //output enable
    input   wire            i_FORCEWHITE, //force output white

    output  wire            o_CARRY,
    input   wire            i_BLENDMODE, //1 to subtract(2's complement), 0 to add

    output  wire    [3:0]   o_OUT
);

wire    [3:0]   TMMUX       = (i_TMEN == 1'b0) ? 4'h0 :
                              i_TMPIXEL;

wire    [4:0]   COLORADDER  = TMMUX + i_OBJPIXEL + i_BLENDMODE;
assign  o_CARRY = COLORADDER[4];

assign  o_OUT   = (i_OUTEN == 1'b0) ? 4'h0 :
                  (i_FORCEWHITE == 1'b1) ? 4'hF :
                  COLORADDER[3:0];

endmodule