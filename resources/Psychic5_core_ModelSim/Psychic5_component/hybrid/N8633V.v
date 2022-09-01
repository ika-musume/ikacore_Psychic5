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
    TOYOCOM N-8633-V Tilemap RAM
*/

module N8633V #(parameter aw=11, simhexfile="")
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,

    input   wire            i_IOEN_n, //LS245
    input   wire            i_IODIR, //LS245
    input   wire    [7:0]   i_DIN,
    output  wire    [7:0]   o_DOUT,

    input   wire            i_RAMRD_n, //RAM OE
    input   wire            i_RAMWR_n, //RAM WE
    input   wire   [aw-1:0] i_ADDR,

    input   wire            i_ENDOFTILELINE_n,
    input   wire            i_FORCEPALETTEZERO_n,
    output  wire            o_TILEATTRSEL,

    output  reg     [3:0]   o_PALETTECODE,
    output  wire    [9:0]   o_TILECODE,

    output  wire            o_HFLIP,
    output  reg             o_HFLIP_DLYD,
    output  wire            o_VFLIP
);


//
//  timing generator
//

/*
    1. WAVEFORM WITHOUT CPU ACCESS
    
    4H      ¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|
    2H      ¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    1H      ¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|
    px       7   0   1   2   3   4   5   6   7   0   1   2   3   4   5   6   7   0   1   2   3   4   5   6   7  

    CLK6M   ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    EOTL    ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|
    IOEN    ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    161[2]  _______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|____  pos: ATTR1 LATCH0 TICK
    161[1]  _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|____  pos: ATTR0 LATCH0 TICK / RAM A0
    161[0]  ___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|
    val      0   1   2   3   4   5   6   7   0   1   2   3   4   5   6   7   0   1   2   3   4   5   6   7   0
    A0

    dffa_n  ___|¯¯¯|___________________________|¯¯¯|___________________________|¯¯¯|___________________________|  pos: ATTR0 LATCH1 TICK / ATTR1 LATCH1 EN(373)
    dffb_n  ¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯  pos: palette code latch tick
    
    
    2. WAVEFORM WITH CPU ACCESS(Z80 @ 6MHz memory read/write cycle)

    4H      ¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|
    2H      ¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    1H      ¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|
    px       7   0   1   2   3   4   5   6   7   0   1   2   3   4   5   6   7   0   1   2   3   4   5   6   7  

    CLK6M   ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    tile      > <             CODE            > <             CODE            > <             CODE            >   
    EOTL    ___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|
    IOEN    ¯¯¯¯¯|_______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯
                 t1  t2  t3                                  t1  t2  t3                          t1  t2  t3  
    161[2]  ___________________________|¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|____  pos: ATTR1 LATCH0 TICK
    161[1]  ___________________|¯¯¯¯¯¯¯|___________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|____________________  pos: ATTR0 LATCH0 TICK / RAM A0
    161[0]  ___|¯¯¯|_______|¯¯¯|___|¯¯¯|_______|¯¯¯|___|¯¯¯|___________|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___________|
    val      0   1   0   0   1   2   3   4   0   1   2   3   4   4   4   5   0   1   2   3   4   5   4   4   0
    syncval  7   1   0   0   1   2   3   4   5   1   2   3   4   4   4   5   6   1   2   3   4   5   4   4   5

    dffa_n  ___|¯¯¯|___________________________|¯¯¯|___________________________|¯¯¯|___________________________|  pos: ATTR0 LATCH1 TICK / ATTR1 LATCH1 EN(373)
    dffb_n  ¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯  pos: palette code latch tick
    
    ATTR0 LATCH0: 카운터 1또는 5일때 래치, IOEN이 0일경우 래치하지 않음
    ATTR1 LATCH0: 카운터 3일때 래치, IOEN이 0일경우 래치하지 않음
*/

reg     [2:0]   counter161 = 3'd0;
assign  o_TILEATTRSEL = counter161[1];


always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_ENDOFTILELINE_n == 1'b0) //async reset originally, asserted at every px7
        begin
            counter161 <= 3'd1;
        end
        else
        begin
            if(i_IOEN_n == 1'b0)
            begin
                counter161 <= {counter161[2:1], 1'b0};
            end
            else
            begin
                if(counter161 < 3'd7)
                begin
                    counter161 <= counter161 + 3'd1;
                end
                else
                begin
                    counter161 <= 3'd0;
                end
            end
        end    
    end
end


/*
always @(posedge i_EMU_MCLK or negedge i_ENDOFTILELINE_n)
begin
    if(i_ENDOFTILELINE_n == 1'b0) //async reset originally, asserted at every px7
    begin
        counter161 <= 3'd0;
    end
    else
    begin
        if(!i_EMU_CLK6MPCEN_n)
        begin
            if(i_IOEN_n == 1'b0)
            begin
                counter161 <= {counter161[2:1], 1'b0};
            end
            else
            begin
                if(counter161 < 3'd7)
                begin
                    counter161 <= counter161 + 3'd1;
                end
                else
                begin
                    counter161 <= 3'd0;
                end
            end
        end
    end    
end
*/


reg             dffa_n = 1'b0;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        dffa_n <= ~i_ENDOFTILELINE_n;
    end
end

reg             dffb_n = 1'b1;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        dffb_n <= ~dffa_n;
    end
end


//
//  RAM module
//

wire    [7:0]   ram_dout;
wire    [7:0]   ram_din =   i_IOEN_n == 1'b1 ? 8'hFF : //no data
                            i_IODIR == 1'b1 ? i_DIN : ram_dout; //data : bus-hold


assign  o_DOUT =    i_IOEN_n == 1'b1 ? 8'hFF : //no data
                    i_IODIR == 1'b0 ? ram_dout : i_DIN; //data : bus-hold

SRAM #(.aw( aw ), .dw( 8 ), .pol( 1 ), .simhexfile(simhexfile)) N8633V_RAM
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (i_ADDR                     ),
    .i_DIN                      (ram_din                    ),
    .o_DOUT                     (ram_dout                   ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (i_RAMRD_n                  ),
    .i_WR_n                     (i_RAMWR_n                  )
);


//
//  dffs
//

reg     [7:0]   attr0_dff0; //273
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(counter161 == 3'd1 || counter161 == 3'd5)
        begin
            if(i_IOEN_n == 1'b1)
            begin
                attr0_dff0 <= ram_dout;
            end
        end
    end
end

reg     [7:0]   attr1_dff0; //273
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(counter161 == 3'd3)
        begin
            if(i_IOEN_n == 1'b1)
            begin
                attr1_dff0 <= ram_dout;
            end
        end
    end
end


reg     [7:0]   attr0_dff1; //273
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_ENDOFTILELINE_n == 1'b0) //act as CEN
        begin
            attr0_dff1 <= attr0_dff0;
        end
    end
end

reg     [7:0]   attr1_dff1; //373 en, latches at negedge of en    
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(dffa_n == 1'b1)
        begin
            attr1_dff1 <= attr1_dff0;
        end
    end
end

assign  o_TILECODE = {attr1_dff1[7:6], attr0_dff1};
assign  o_VFLIP = attr1_dff1[5];
assign  o_HFLIP = attr1_dff1[4];

always @(posedge i_EMU_MCLK) //174
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_FORCEPALETTEZERO_n == 1'b0) //original is async reset
        begin
            o_PALETTECODE <= 4'b0000;
            o_HFLIP_DLYD <= 1'b0; //this delay is needed to synchronize output timings between 
                                  //the latching of the first pixel data and
                                  //the launching of the attribute data of corresponding tileset
        end
        else
        begin
            if(dffb_n == 1'b0)
            begin
                o_PALETTECODE <= attr1_dff1[3:0];
                o_HFLIP_DLYD <= attr1_dff1[4];
            end
        end
    end
end


endmodule