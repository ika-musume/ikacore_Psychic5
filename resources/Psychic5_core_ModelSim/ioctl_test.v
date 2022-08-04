ikacore_Psychic5.sv
rtl
sys

module ioctl_test
(
    input   wire            i_HPSIO_CLK,
    input   wire            i_RST,

    output  reg             o_IOCTL_DOWNLOAD,
    output  reg     [26:0]  o_IOCTL_ADDR,
    output  wire    [7:0]   o_IOCTL_DATA,
    output  reg             o_IOCTL_WR,
    output  reg     [15:0]  o_IOCTL_INDEX,
    input   wire            i_IOCTL_WAIT
);

localparam  [7:0]   INTERVAL = 8'd6;

integer         mra_fd;
initial begin
    mra_fd = $fopen("roms/mra.bin", "rb"); //read merged file

    $fseek(mra_fd, 0, 0);
end

reg     [8:0]   dipsw_reg [0:8];
reg     [3:0]   dipsw_cntr = 4'd0;
initial begin
    dipsw_reg[0] <= 9'h0AF;
    dipsw_reg[1] <= 9'h0FC;
    dipsw_reg[2] <= 9'h0FF;
    dipsw_reg[3] <= 9'h0FF;
    dipsw_reg[4] <= 9'h0FF;
    dipsw_reg[5] <= 9'h0FF;
    dipsw_reg[6] <= 9'h0FF;
    dipsw_reg[7] <= 9'h0FF;
    dipsw_reg[8] <= 9'h1FF;
end

reg     [2:0]   hps_state = 3'b000; //000 reset 001 rom standby 002 rom download 003 rom download end 
                                    //          004 dipsw standby 005 dipsw download 006 dipsw end

reg     [8:0]   data_read_buffer;
assign          o_IOCTL_DATA = data_read_buffer[7:0];

reg     [7:0]   cntr;
reg             cntr_en, cntr_rst;
always @(posedge i_HPSIO_CLK) begin
    if(cntr_rst) begin
        cntr <= 8'd0;
    end
    else begin
        if(cntr_en) begin
            if(cntr == 8'd255) begin cntr <= 8'd0; end
            else               begin cntr <= cntr + 8'd1; end
        end
    end
end


always @(posedge i_HPSIO_CLK) begin
    if(hps_state == 3'b000) begin
        if(i_RST == 1'b0) begin
            hps_state <= 3'b001;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b1;
        end
        else begin
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b1;
        end
    end
    else if(hps_state == 3'b001) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd192) begin
                hps_state <= 3'b010;

                cntr_en <= 1'b0;
                cntr_rst <= 1'b1;
            end
            else begin
                hps_state <= hps_state;

                cntr_en <= 1'b1;
                cntr_rst <= 1'b0;
            end
        end
        else begin //wait
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b0;
        end
    end
    else if(hps_state == 3'b010) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd1) begin
                if(data_read_buffer == 9'h1FF) begin //next state
                    hps_state <= 3'b011;

                    cntr_en <= 1'b0;
                    cntr_rst <= 1'b1;
                end
            end
            else if(cntr == INTERVAL) begin //counter reset
                hps_state <= hps_state;

                cntr_en <= 1'b0;
                cntr_rst <= 1'b1;
            end
            else begin //count
                hps_state <= hps_state;

                cntr_en <= 1'b1;
                cntr_rst <= 1'b0;
            end
        end
        else begin //wait
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b0;
        end
    end
    else if(hps_state == 3'b011) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd128) begin
                hps_state <= 3'b100;

                cntr_en <= 1'b0;
                cntr_rst <= 1'b1;
            end
            else begin
                hps_state <= hps_state;

                cntr_en <= 1'b1;
                cntr_rst <= 1'b0;
            end
        end
        else begin //wait
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b0;
        end
    end
    else if(hps_state == 3'b100) begin //dipsw standby
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd192) begin
                hps_state <= 3'b101;

                cntr_en <= 1'b0;
                cntr_rst <= 1'b1;
            end
            else begin
                hps_state <= hps_state;

                cntr_en <= 1'b1;
                cntr_rst <= 1'b0;
            end
        end
        else begin //wait
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b0;
        end
    end
    else if(hps_state == 3'b101) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd1) begin
                if(data_read_buffer == 9'h1FF) begin //next state
                    hps_state <= 3'b110;

                    cntr_en <= 1'b0;
                    cntr_rst <= 1'b1;
                end
            end
            else if(cntr == INTERVAL) begin //counter reset
                hps_state <= hps_state;

                cntr_en <= 1'b0;
                cntr_rst <= 1'b1;
            end
            else begin //count
                hps_state <= hps_state;

                cntr_en <= 1'b1;
                cntr_rst <= 1'b0;
            end
        end
        else begin //wait
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b0;
        end
    end
    else if(hps_state == 3'b110) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd192) begin
                hps_state <= 3'b111;

                cntr_en <= 1'b0;
                cntr_rst <= 1'b1;
            end
            else begin
                hps_state <= hps_state;

                cntr_en <= 1'b1;
                cntr_rst <= 1'b0;
            end
        end
        else begin //wait
            hps_state <= hps_state;

            cntr_en <= 1'b0;
            cntr_rst <= 1'b0;
        end
    end
    else begin
        $fclose(mra_fd);

        hps_state <= hps_state;

        cntr_en <= 1'b0;
        cntr_rst <= 1'b1;
    end
end



always @(posedge i_HPSIO_CLK) begin
    if(hps_state == 3'b000) begin
        o_IOCTL_INDEX <= 16'd0;
        o_IOCTL_DOWNLOAD <= 1'b0;
        o_IOCTL_ADDR <= 26'h2FF_FFFF;
        data_read_buffer <= 8'h00;
        o_IOCTL_WR <= 1'b0;
    end
    else if(hps_state == 3'b001) begin
        o_IOCTL_DOWNLOAD <= 1'b1;
        o_IOCTL_ADDR <= 26'h000_0000;
    end
    else if(hps_state == 3'b010) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd0)        begin data_read_buffer <= $fgetc(mra_fd); end
            else if(cntr == 8'd2)   begin o_IOCTL_WR <= 1'b1; end
            else if(cntr == 8'd3)   begin o_IOCTL_WR <= 1'b0; end
            else if(cntr == INTERVAL)  begin o_IOCTL_ADDR <= o_IOCTL_ADDR + 26'h1; end
            else                    begin end
        end
    end
    else if(hps_state == 3'b011) begin
        o_IOCTL_DOWNLOAD <= 1'b0;
    end
    else if(hps_state == 3'b100) begin
        o_IOCTL_INDEX <= 16'd254;
        o_IOCTL_DOWNLOAD <= 1'b1;
        o_IOCTL_ADDR <= 26'h000_0000;
    end
    else if(hps_state == 3'b101) begin
        if(i_IOCTL_WAIT == 1'b0) begin
            if(cntr == 8'd0)        begin data_read_buffer <= dipsw_reg[dipsw_cntr]; end
            else if(cntr == 8'd1)   begin dipsw_cntr <= dipsw_cntr + 4'd1; end
            else if(cntr == 8'd2)   begin o_IOCTL_WR <= 1'b1; end
            else if(cntr == 8'd3)   begin o_IOCTL_WR <= 1'b0; end
            else if(cntr == INTERVAL)  begin o_IOCTL_ADDR <= o_IOCTL_ADDR + 26'h1; end
            else                    begin end
        end
    end
    else if(hps_state == 3'b111) begin
        o_IOCTL_INDEX <= 16'd0;
        o_IOCTL_DOWNLOAD <= 1'b0;
        o_IOCTL_ADDR <= 26'h1FF_FFFF;
        data_read_buffer <= 8'h00;
        o_IOCTL_WR <= 1'b0;
    end

end

endmodule