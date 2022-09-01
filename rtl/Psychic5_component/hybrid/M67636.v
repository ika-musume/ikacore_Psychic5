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