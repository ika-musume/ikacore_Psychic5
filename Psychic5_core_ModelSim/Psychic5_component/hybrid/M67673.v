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