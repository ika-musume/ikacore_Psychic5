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
    TOYOCOM N-8633-S Video Timing Generator
*/

module N8633S
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,

    input   wire    [1:0]   i_EMU_PXCNTR_ADJ_MODE,
    input   wire    [1:0]   i_EMU_PXCNTR_ADJ_H,
    input   wire    [2:0]   i_EMU_PXCNTR_ADJ_V,

    input   wire            i_FLIP,
    input   wire            i_CNTRSEL,

    output  wire            o_ABS_256H_n,
    output  wire            o_FLIP_64HA,

    output  wire    [8:0]   o_ABS_H_CNTR,
    output  wire    [8:0]   o_ABS_V_CNTR,

    output  wire    [7:0]   o_FLIP_HV_BUS
);

reg     [8:0]   horizontal_counter = 9'd128; //9'b0_1000_0000
reg     [8:0]   vertical_counter = 9'd220; //9'b0_1101_1100  

assign  o_ABS_H_CNTR = horizontal_counter;
assign  o_ABS_V_CNTR = vertical_counter;

assign  {o_ABS_256H, 
         o_ABS_128H, o_ABS_64H,  o_ABS_32H,  o_ABS_16H, 
         o_ABS_8H,   o_ABS_4H,   o_ABS_2H,   o_ABS_1H} = horizontal_counter;

assign  {o_ABS_256V, 
         o_ABS_128V, o_ABS_64V,  o_ABS_32V,  o_ABS_16V, 
         o_ABS_8V,   o_ABS_4V,   o_ABS_2V,   o_ABS_1V} = vertical_counter;

assign  o_ABS_256H_n = ~o_ABS_256H;



reg     [8:0]   vertical_start, horizontal_skip;
always @(*) begin
    case(i_EMU_PXCNTR_ADJ_MODE)
        2'd0: begin vertical_start = 9'd220; horizontal_skip = 9'd227; end //original
        2'd1: begin vertical_start = 9'd249; horizontal_skip = 9'd224; end //ntsc-friendly
        2'd2: begin vertical_start = 9'd220 + i_EMU_PXCNTR_ADJ_V; horizontal_skip = 9'd227 - {i_EMU_PXCNTR_ADJ_H, 1'b0}; end //custom
        2'd3: begin vertical_start = 9'd220; horizontal_skip = 9'd227; end //unused
    endcase
end


always @(posedge i_EMU_MCLK) if(!i_EMU_CLK6MPCEN_n) begin
    if(horizontal_counter == 9'd511)
    begin
        horizontal_counter <= 9'd128; //9'd128;

        if(vertical_counter == 9'd511)
        begin
            vertical_counter <= vertical_start; //9'd220;
        end
        else
        begin
            vertical_counter <= vertical_counter + 9'd1;
        end
    end
    else
    begin //count up
        if(horizontal_counter == horizontal_skip) horizontal_counter <= 9'd228;
        else horizontal_counter <= horizontal_counter + 9'd1;
    end
end



wire            FLIP_64HA = (o_ABS_64H ^ i_FLIP) & ~o_ABS_256H;
wire            FLIP_128HA = (o_ABS_128H ^ i_FLIP) & o_ABS_256H;
assign  o_FLIP_64HA = FLIP_64HA;

wire    [7:0]   FLIP_H_CNTR = {FLIP_128HA | FLIP_64HA, horizontal_counter[6:0] ^ {7{i_FLIP}}};

reg     [7:0]   FLIP_V_CNTR;
always @(posedge i_EMU_MCLK) if(!i_EMU_CLK6MPCEN_n) begin
    if(horizontal_counter[4:0] == 5'd15)
    begin
        FLIP_V_CNTR <= vertical_counter[7:0] ^ {8{i_FLIP}};
    end
end


assign  o_FLIP_HV_BUS = i_CNTRSEL ? FLIP_H_CNTR : FLIP_V_CNTR; //1 : 0

endmodule