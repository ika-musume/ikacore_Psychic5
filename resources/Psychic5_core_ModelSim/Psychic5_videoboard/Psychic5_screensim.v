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

module Psychic5_screensim
(
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,
    input   wire            i_EMU_MRST_n,

    input   wire    [8:0]   i_HCOUNTER,
    input   wire    [8:0]   i_VCOUNTER,
    input   wire    [11:0]  i_VIDEODATA
);


/*
    valid pixel

    VCNTR
    272 - HCNTR 269~511 + 273 - 128~140; 141 end of line
    ~
    495 - HCNTR 269~511 + 496 - 128~140; 141 end of frame
*/

reg     [7:0]   RESNET_CONSTANT[31:0];
reg     [7:0]   BITMAP_HEADER[63:0];
integer         BITMAP_LINE_ADDRESS = 32'h29D36;

reg     [7:0]   BITMAP_FILE_BUFFER[0:172085];

wire    [3:0]   R = i_VIDEODATA[11:8];
wire    [3:0]   G = i_VIDEODATA[7:4];
wire    [3:0]   B = i_VIDEODATA[3:0];

integer         fd;
integer         i;
reg             screen_active = 1'b0;
reg     [17:0]  buffer_pointer = 18'h0;
reg     [15:0]  frame = 16'd0;

initial begin
    $readmemh("screensim/debug_resnet_level.txt", RESNET_CONSTANT);
    $readmemh("screensim/debug_bitmap_header.txt", BITMAP_HEADER);
end

always @(posedge i_EMU_MCLK) begin
    if(i_EMU_MRST_n == 1'b1) begin
        if(!i_EMU_CLK6MPCEN_n) begin
            if(i_VCOUNTER >= 9'd272 && i_VCOUNTER <= 9'd496) begin 
                if(i_VCOUNTER == 9'd272) begin //first scanline
                    if(i_HCOUNTER == 9'd267) begin //start recording
                        BITMAP_LINE_ADDRESS = 20'h29D36; //reset line

                        for(i = 0; i < 54; i = i + 1) begin //write bitmap header
                            BITMAP_FILE_BUFFER[i] = BITMAP_HEADER[i];
                        end  

                        /*
                        fd = $fopen($sformatf("screensim/p5_frame%0d.bmp", frame), "wb"); //generate new file

                        for(i = 0; i < 54; i = i + 1) begin //write bitmap header
                            $fwrite(fd, "%c", BITMAP_HEADER[i]);
                        end
                        */    

                        $display("Start of frame %d", frame); //debug message
                    end
                    else if(i_HCOUNTER == 9'd268) begin
                        //$fseek(fd, BITMAP_LINE_ADDRESS, 0); //set current line address
                        buffer_pointer = BITMAP_LINE_ADDRESS[17:0];
                    end
                    else if(i_HCOUNTER >= 9'd269) begin
                        //$fwrite(fd, "%c%c%c", RESNET_CONSTANT[B], RESNET_CONSTANT[G], RESNET_CONSTANT[R]); //B G R
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[B]; buffer_pointer = buffer_pointer + 18'h1;
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[G]; buffer_pointer = buffer_pointer + 18'h1;
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[R]; buffer_pointer = buffer_pointer + 18'h1;
                    end
                    else begin
                        
                    end
                end

                else if(i_VCOUNTER == 9'd496) begin //end of the last scanine
                    if(i_HCOUNTER <= 9'd140) begin //stop recording
                        //$fwrite(fd, "%c%c%c", RESNET_CONSTANT[B], RESNET_CONSTANT[G], RESNET_CONSTANT[R]); //B G R
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[B]; buffer_pointer = buffer_pointer + 18'h1;
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[G]; buffer_pointer = buffer_pointer + 18'h1;
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[R]; buffer_pointer = buffer_pointer + 18'h1;
                    end
                    else if(i_HCOUNTER == 9'd141) begin
                    //$fclose(fd); //close this frame

                    fd = $fopen($sformatf("screensim/p5_frame%0d.bmp", frame), "wb");

                    $display("Frame %d saved", frame); //debug message
                    for(i = 0; i < 172086; i = i + 1) begin //write bitmap header
                        $fwrite(fd, "%c", BITMAP_FILE_BUFFER[i]);
                    end
                    $fclose(fd); //close this frame

                    frame = frame + 16'd1;
                    end
                    else begin
                        
                    end
                end

                else begin
                    if(i_HCOUNTER == 9'd141) begin
                        BITMAP_LINE_ADDRESS = BITMAP_LINE_ADDRESS - 32'h300; //decrease line
                    end
                    else if(i_HCOUNTER == 9'd268) begin
                        //$fseek(fd, BITMAP_LINE_ADDRESS, 0); //set current line address
                        buffer_pointer = BITMAP_LINE_ADDRESS[17:0];
                    end
                    else if(i_HCOUNTER >= 9'd269 || i_HCOUNTER <= 9'd140) begin
                        //$fwrite(fd, "%c%c%c", RESNET_CONSTANT[B], RESNET_CONSTANT[G], RESNET_CONSTANT[R]); //B G R
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[B]; buffer_pointer = buffer_pointer + 18'h1;
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[G]; buffer_pointer = buffer_pointer + 18'h1;
                        BITMAP_FILE_BUFFER[buffer_pointer] = RESNET_CONSTANT[R]; buffer_pointer = buffer_pointer + 18'h1;
                    end
                    else begin
                        
                    end
                end
            end
        end
    end
end


endmodule