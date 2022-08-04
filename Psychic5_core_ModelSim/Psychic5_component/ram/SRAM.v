/*
    SRAM
*/

module SRAM #(parameter dw=8, aw=10, pol=1, simhexfile="")
(
    input   wire            i_MCLK,
    input   wire   [aw-1:0] i_ADDR,
    input   wire   [dw-1:0] i_DIN,
    output  reg    [dw-1:0] o_DOUT,
    input   wire            i_CS_n,
    input   wire            i_RD_n,
    input   wire            i_WR_n
);

reg     [dw-1:0]   RAM [0:(2**aw)-1];

generate
    if(pol == 1'b1)
    begin
        always @(posedge i_MCLK) //read
        begin
            if(i_CS_n == 1'b0)
            begin
                if(i_RD_n == 1'b0)
                begin
                    o_DOUT <= RAM[i_ADDR];
                end
            end
        end

        always @(posedge i_MCLK)
        begin
            if(i_CS_n == 1'b0)
            begin
                if(i_WR_n == 1'b0)
                begin
                    RAM[i_ADDR] <= i_DIN;
                end
            end
        end
    end

    else
    begin
        always @(negedge i_MCLK) //read
        begin
            if(i_CS_n == 1'b0)
            begin
                if(i_RD_n == 1'b0)
                begin
                    o_DOUT <= RAM[i_ADDR];
                end
            end
        end

        always @(negedge i_MCLK)
        begin
            if(i_CS_n == 1'b0)
            begin
                if(i_WR_n == 1'b0)
                begin
                    RAM[i_ADDR] <= i_DIN;
                end
            end
        end
    end
endgenerate


initial
begin
    if( simhexfile != "" ) begin
        $readmemh(simhexfile, RAM);
    end
end

endmodule
