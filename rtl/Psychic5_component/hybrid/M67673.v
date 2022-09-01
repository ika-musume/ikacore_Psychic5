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
    Mitsubishi M67673 tilemap raster scroller
*/

module M67673 #(parameter [7:0] initval = 8'd0)
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,

    input   wire            i_REGEN_n,
    input   wire    [7:0]   i_REGDIN,

    input   wire    [7:0]   i_CNTR,

    output  wire    [7:0]   o_SUM,
    output  wire            o_CARRY
);


//scroll value register: it originally samples data at the rising edge of Z80's /CS | /WR
//synchronized to the CLK6M
reg     [7:0]   scroll_reg; //declare as a memory space

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(!i_REGEN_n)
        begin
            scroll_reg <= i_REGDIN; 
        end
    end
end

assign  {o_CARRY, o_SUM} = scroll_reg + i_CNTR;

initial 
begin
    scroll_reg <= initval;
end

endmodule