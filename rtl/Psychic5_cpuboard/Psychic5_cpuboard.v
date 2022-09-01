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

`include "rtl/Psychic5_emu_header.v"

module Psychic5_cpuboard
(
    input   wire            i_EMU_MCLK,

    input   wire            i_EMU_CLK6MPCEN_n,
    input   wire            i_EMU_CLK6MNCEN_n,
    input   wire            i_EMU_CLK5MPCEN_n,
    input   wire            i_EMU_CLK5MNCEN_n,

    input   wire            i_EMU_INITRST_n,
    input   wire            i_EMU_SOFTRST_n,

    //JAMMA/dipsw
    input   wire    [7:0]   i_P1_BTN,
    input   wire    [7:0]   i_P2_BTN,
    input   wire    [7:0]   i_SYS_BTN,
    input   wire    [7:0]   i_DIPSW1,
    input   wire    [7:0]   i_DIPSW2,
    output  wire    [15:0]  o_SOUND, //16bit signed

    //CPU RW
    output  wire    [12:0]  o_ADDR_BUS,
    input   wire    [7:0]   i_DATA_READ_BUS,
    output  wire    [7:0]   o_DATA_WRITE_BUS,
    output  wire            o_CTRL_RD_n,
    output  wire            o_CTRL_WR_n,

    //RAM CS
    output  wire            o_TM_BG_ATTR_CS_n,
    output  wire            o_TM_FG_ATTR_CS_n,
    output  wire            o_TM_BG_SCR_CS_n,
    output  wire            o_TM_PALETTE_CS_n,
    output  wire            o_OBJ_PALETTE_CS_n,

    //Flip bit
    output  wire            o_FLIP,

    //Video timings
    input   wire    [7:0]   i_FLIP_HV_BUS,
    input   wire            i_ABS_4H, i_ABS_2H, i_ABS_1H, //hcounter bits

    input   wire            i_DFFD_7E_A_Q, //IDC PIN D6
    input   wire            i_DFFD_7E_A_Q_PCEN_n,
    input   wire            i_DFFD_8E_A_Q,
    input   wire            i_DFFD_8E_B_Q, //IDC PIN D7
    input   wire            i_DFFQ_8F_Q3, //IDC PIN D11
    input   wire            i_DFFQ_8F_Q2, //IDC PIN C11
    input   wire            i_DFFQ_8F_Q2_NCEN_n, //negative edge enable signal of the signal above, used by CPU sprite engine
    input   wire            i_DFFQ_8F_Q1, //IDC PIN D8

    output  wire    [7:0]   o_OBJ_PIXELOUT,

    //SDRAM requests
    output  wire    [16:0]  o_EMU_MAINCPU_ADDR,
    input   wire    [7:0]   i_EMU_MAINCPU_DATA,
    output  wire            o_EMU_MAINCPU_RQ_n,

    output  wire    [16:0]  o_EMU_OBJROM_ADDR,
    input   wire    [7:0]   i_EMU_OBJROM_DATA,
    output  wire            o_EMU_OBJROM_RQ_n,

    //BRAM programming
    input   wire    [16:0]  i_EMU_BRAM_ADDR,
    input   wire    [7:0]   i_EMU_BRAM_DATA,
    input   wire            i_EMU_BRAM_WR_n,

    input   wire            i_EMU_BRAM_SOUNDROM_CS_n,
    input   wire            i_EMU_BRAM_SEQROM_CS_n
);



///////////////////////////////////////////////////////////
//////  TIMINGS
////

reg             DFFQ_8F_Q1_DLYD_n; //IDC PIN D8  -> 8M LS175 PIN3
reg             DFFQ_8F_Q3_DLYD;   //IDC PIN D11 -> 8M LS175 PIN7
reg             DFFQ_8F_Q2_DLYD;   //IDC PIN C11 -> 8M LS175 PIN10
reg             DFFQ_8F_Q2_DLYD_n; //IDC PIN C11 -> 8M LS175 PIN11

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if({i_ABS_2H, i_ABS_1H} == 2'd1)
        begin
            DFFQ_8F_Q1_DLYD_n <= ~i_DFFQ_8F_Q1;
            DFFQ_8F_Q3_DLYD <= i_DFFQ_8F_Q3;
            DFFQ_8F_Q2_DLYD <= i_DFFQ_8F_Q2;
            DFFQ_8F_Q2_DLYD_n <= ~i_DFFQ_8F_Q2;
        end
    end
end




///////////////////////////////////////////////////////////
//////  DMA BUS SWITCH
////

wire            OBJDMA_BUSRQ_n;
wire            OBJDMA_BUSACK_n;

//BUS MASTER 0
wire    [15:0]  MAINCPU_ADDR_BUS;
wire    [7:0]   MAINCPU_DATA_WRITE_BUS;
wire            MAINCPU_CTRL_RD_n;
wire            MAINCPU_CTRL_WR_n;

//BUS MASTER 1
wire    [12:0]  OBJDMA_ADDR_BUS; //don't care A[15:13]
wire            OBJDMA_CTRL_RD_n;
wire            OBJDMA_CTRL_WR_n;

//BUS SWITCH
wire    [15:0]  SYSTEM_ADDR_BUS       = (OBJDMA_BUSACK_n == 1'b0) ? {3'b111, OBJDMA_ADDR_BUS} : MAINCPU_ADDR_BUS;
reg     [7:0]   SYSTEM_DATA_READ_BUS;
wire    [7:0]   SYSTEM_DATA_WRITE_BUS = (OBJDMA_BUSACK_n == 1'b0) ? 8'hFF                     : MAINCPU_DATA_WRITE_BUS; //pull up
wire            SYSTEM_CTRL_RD_n      = (OBJDMA_BUSACK_n == 1'b0) ? OBJDMA_CTRL_RD_n          : MAINCPU_CTRL_RD_n;
wire            SYSTEM_CTRL_WR_n      = (OBJDMA_BUSACK_n == 1'b0) ? OBJDMA_CTRL_WR_n          : MAINCPU_CTRL_WR_n;

assign          o_ADDR_BUS = SYSTEM_ADDR_BUS[12:0];
assign          o_DATA_WRITE_BUS = SYSTEM_DATA_WRITE_BUS;
assign          o_CTRL_RD_n = SYSTEM_CTRL_RD_n;
assign          o_CTRL_WR_n = SYSTEM_CTRL_WR_n;




///////////////////////////////////////////////////////////
//////  MAIN CPU
////

wire            MAINCPU_CTRL_MREQ_n;
wire            MAINCPU_CTRL_IORQ_n;
wire            MAINCPU_CTRL_RFSH_n;
wire            MAINCPU_CTRL_M1_n;
wire            MAINCPU_CTRL_INT_n;


T80pa maincpu (
    .RESET_n                    (i_EMU_SOFTRST_n             ),
    .CLK                        (i_EMU_MCLK                 ),
    .CEN_p                      (~i_EMU_CLK6MPCEN_n         ),
    .CEN_n                      (~i_EMU_CLK6MNCEN_n         ),
    .WAIT_n                     (1'b1                       ),
    .INT_n                      (MAINCPU_CTRL_INT_n         ),
    .NMI_n                      (1'b1                       ),
    .RD_n                       (MAINCPU_CTRL_RD_n          ),
    .WR_n                       (MAINCPU_CTRL_WR_n          ),
    .A                          (MAINCPU_ADDR_BUS           ),
    .DI                         (SYSTEM_DATA_READ_BUS       ),
    .DO                         (MAINCPU_DATA_WRITE_BUS     ),
    .IORQ_n                     (MAINCPU_CTRL_IORQ_n        ),
    .M1_n                       (MAINCPU_CTRL_M1_n          ),
    .MREQ_n                     (MAINCPU_CTRL_MREQ_n        ),
    .BUSRQ_n                    (OBJDMA_BUSRQ_n             ),
    .BUSAK_n                    (OBJDMA_BUSACK_n            ),
    .RFSH_n                     (MAINCPU_CTRL_RFSH_n        ),
    .out0                       (1'b0                       ), //?????
    .HALT_n                     (                           )
);




///////////////////////////////////////////////////////////
//////  INTERRUPT
////

//edge detectors for interrupt DFF trigger
reg             int_a_trig_dly, int_b_trig_dly;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        int_a_trig_dly <= ~DFFQ_8F_Q1_DLYD_n; //negedge
        int_b_trig_dly <= i_DFFD_8E_A_Q; //posedge
    end
end

wire            int_a_trig_n = int_a_trig_dly | DFFQ_8F_Q1_DLYD_n;
wire            int_b_trig_n = ~(~int_b_trig_dly & i_DFFD_8E_A_Q);

//interrupt DFF
reg             int_a_req = 1'b1;
reg             int_b_req = 1'b1;
assign          MAINCPU_CTRL_INT_n = int_a_req & int_b_req;

wire            int_ack_n = MAINCPU_CTRL_M1_n | MAINCPU_CTRL_IORQ_n;

/*
reg int_ack_n = 1'b1;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        int_ack_n <= MAINCPU_CTRL_INT_n;
    end
end
*/


always @(posedge i_EMU_MCLK or negedge int_ack_n)
begin
    if(!int_ack_n) //ASYNC RESET
    begin
        int_a_req <= 1'b1;
        int_b_req <= 1'b1;
    end
    else
    begin
        if(!i_EMU_CLK6MPCEN_n)
        begin
            begin
                if(int_a_trig_n == 1'b0)
                begin
                    int_a_req <= 1'b0;
                end

                if(int_b_trig_n == 1'b0)
                begin
                    int_b_req <= 1'b0;
                end
            end
        end
    end
end

//interrupt vector
wire    [7:0]   intvector;
assign          intvector = {3'b110, ~DFFQ_8F_Q1_DLYD_n, DFFQ_8F_Q1_DLYD_n, 3'b111};







///////////////////////////////////////////////////////////
//////  ADDRESS DECODER AND PAGE REGISTER
////

//memory space enable
wire            memspace_en_n = ~MAINCPU_CTRL_RFSH_n | MAINCPU_CTRL_MREQ_n;

//main program rom/main ram enable
wire            mainprog_cs_n = (SYSTEM_ADDR_BUS[15] == 1'b0) ? memspace_en_n : 1'b1;           //0000-7FFF
wire            mainram_cs_n = (OBJDMA_BUSACK_n == 1'b0) ? 1'b0 :
                               (SYSTEM_ADDR_BUS[15:13] == 3'b111) ? memspace_en_n : 1'b1;       //E000-FFFF

//system register
wire            soundlatch_ld_n = (SYSTEM_ADDR_BUS[15:0] == 16'hF000) ? memspace_en_n | SYSTEM_CTRL_WR_n : 1'b1;       //FFF0
wire            sysreg_ld_n     = (SYSTEM_ADDR_BUS[15:0] == 16'hF001) ? memspace_en_n | SYSTEM_CTRL_WR_n : 1'b1;       //FFF1
wire            rombanknum_ld_n = (SYSTEM_ADDR_BUS[15:0] == 16'hF002) ? memspace_en_n | SYSTEM_CTRL_WR_n : 1'b1;       //FFF2
wire            rambanknum_ld_n = (SYSTEM_ADDR_BUS[15:0] == 16'hF003) ? memspace_en_n | SYSTEM_CTRL_WR_n : 1'b1;       //FFF3
wire            objbufhalt_ld_n = (SYSTEM_ADDR_BUS[15:0] == 16'hF005) ? memspace_en_n | SYSTEM_CTRL_WR_n : 1'b1;       //FFF5

reg             flip = 1'b0;
reg             soundcpu_force_rst = 1'b0;
reg             obj_buf_halt = 1'b0;
reg             rambanknum = 1'b0;
reg     [2:0]   rombanknum = 3'b000;
assign          o_FLIP = flip;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_INITRST_n) //ASYNC RESET
    begin
        flip <= 1'b0;
        soundcpu_force_rst <= 1'b0;
        obj_buf_halt <= 1'b0;
        rambanknum <= 1'b0;
        rombanknum <= 3'b000;
    end
    else 
    begin
        if(!sysreg_ld_n) 
        begin
            flip <= SYSTEM_DATA_WRITE_BUS[7];
            soundcpu_force_rst <= SYSTEM_DATA_WRITE_BUS[4];
        end

        if(!objbufhalt_ld_n) 
        begin
            obj_buf_halt <= SYSTEM_DATA_WRITE_BUS[0];
        end

        if(!rambanknum_ld_n) 
        begin
            rambanknum <= SYSTEM_DATA_WRITE_BUS[0];
        end

        if(!rombanknum_ld_n) 
        begin
            rombanknum <= SYSTEM_DATA_WRITE_BUS[2:0];
        end
    end
end


//banked rom enables
wire            bankedrom0_cs_n = (SYSTEM_ADDR_BUS[15:14] == 2'b10) ? rombanknum[2] | memspace_en_n : 1'b1; //8000-BFFF
wire            bankedrom1_cs_n = (SYSTEM_ADDR_BUS[15:14] == 2'b10) ? ~rombanknum[2] | memspace_en_n : 1'b1;


//banked ram enables

//bank 0
assign          o_TM_BG_ATTR_CS_n =  (SYSTEM_ADDR_BUS[15:13] == 3'b110     ) ? rambanknum | memspace_en_n : 1'b1;

//bank 1
assign          o_TM_FG_ATTR_CS_n  = (SYSTEM_ADDR_BUS[15:11] == 5'b1101_0  ) ? ~rambanknum | memspace_en_n : 1'b1; //D000-D7FF
assign          o_TM_PALETTE_CS_n  = (SYSTEM_ADDR_BUS[15:11] == 5'b1100_1  ) ? ~rambanknum | memspace_en_n : 1'b1; //C800-C9FF BG, CA00-CBFF FG
assign          o_OBJ_PALETTE_CS_n = (SYSTEM_ADDR_BUS[15:9]  == 7'b1100_010) ? ~rambanknum | memspace_en_n : 1'b1; //C400-C5FF
assign          o_TM_BG_SCR_CS_n   = (SYSTEM_ADDR_BUS[15:9]  == 7'b1100_001) ? ~rambanknum | memspace_en_n : 1'b1; //C200-C3FF
wire            ioports_en_n       = (SYSTEM_ADDR_BUS[15:9]  == 7'b1100_000) ? ~rambanknum | memspace_en_n : 1'b1; //C000-C1FF


//JAMMA/dipsw
reg     [7:0]   ioports;
always @(*) begin
    if((ioports_en_n | SYSTEM_CTRL_RD_n) == 1'b1) begin
        ioports <= 8'hFF;
    end
    else begin
        case(SYSTEM_ADDR_BUS[2:0])
            3'd0: ioports <= i_SYS_BTN;
            3'd1: ioports <= i_P1_BTN;
            3'd2: ioports <= i_P2_BTN;
            3'd3: ioports <= i_DIPSW1;
            3'd4: ioports <= i_DIPSW2;
            default: ioports <= 8'hFF;
        endcase
    end
end




///////////////////////////////////////////////////////////
//////  MAIN PROGRAM ROM/MAIN RAM
////

wire    [7:0]       mainram_dout;

`ifdef FASTBOOT //USE BLOCK RAM FOR FAST BOOT
wire    [7:0]       mainprog_dout, bankedrom0_dout;

//0000-7FFF main program rom
PROM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_7a.txt")) ROM_7A
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (SYSTEM_ADDR_BUS[14:0]      ),
    .o_DOUT                     (mainprog_dout              ),
    .i_CS_n                     (mainprog_cs_n              ),
    .i_RD_n                     (1'b0                       )
);

PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_7c.txt")) ROM_7C
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     ({rombanknum[1:0], SYSTEM_ADDR_BUS[13:0]}),
    .o_DOUT                     (bankedrom0_dout            ),
    .i_CS_n                     (bankedrom0_cs_n            ),
    .i_RD_n                     (1'b0                       )
);

`endif 


//sdram request
reg     [16:0]  maincpu_rq_addr;

assign          o_EMU_MAINCPU_ADDR = maincpu_rq_addr;
assign          o_EMU_MAINCPU_RQ_n = mainprog_cs_n & bankedrom0_cs_n;

always @(*)
begin
    case({mainprog_cs_n, bankedrom0_cs_n})
        2'b00: maincpu_rq_addr <= 17'h1FFFF;
        2'b01: maincpu_rq_addr <= {2'b10, SYSTEM_ADDR_BUS[14:0]};
        2'b10: maincpu_rq_addr <= {1'b0, rombanknum[1:0], SYSTEM_ADDR_BUS[13:0]};
        2'b11: maincpu_rq_addr <= 17'h1FFFF;
    endcase
end


SRAM #(.aw( 13 ), .dw( 8 ), .pol( 1 ), .simhexfile()) MAINRAM
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (SYSTEM_ADDR_BUS[12:0]      ),
    .i_DIN                      (SYSTEM_DATA_WRITE_BUS      ),
    .o_DOUT                     (mainram_dout               ),
    .i_CS_n                     (mainram_cs_n               ),
    .i_RD_n                     (SYSTEM_CTRL_RD_n           ),
    .i_WR_n                     (SYSTEM_CTRL_WR_n           )
);




///////////////////////////////////////////////////////////
//////  SPRITE
////

wire    [7:0]   OBJ_PIXELOUT;

//sprite section on the CPU board
Psychic5_obj obj_main
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),
    .i_EMU_CLK6MPCEN_n          (i_EMU_CLK6MPCEN_n          ),
    .i_EMU_INITRST_n            (i_EMU_INITRST_n            ),

    .o_OBJDMA_BUSRQ_n           (OBJDMA_BUSRQ_n             ),
    .i_OBJDMA_BUSACK_n          (OBJDMA_BUSACK_n            ),

    .o_OBJDMA_ADDR_BUS          (OBJDMA_ADDR_BUS            ),
    .i_OBJDMA_DATA_READ_BUS     (SYSTEM_DATA_READ_BUS       ),
    .o_OBJDMA_CTRL_RD_n         (OBJDMA_CTRL_RD_n           ),
    .o_OBJDMA_CTRL_WR_n         (OBJDMA_CTRL_WR_n           ),

    .i_FLIP                     (o_FLIP                     ),
    .i_OBJ_BUF_INIT_STOP_n      (~obj_buf_halt              ),

    .i_FLIP_HV_BUS              (i_FLIP_HV_BUS              ),
    .i_ABS_4H                   (i_ABS_4H                   ),
    .i_ABS_2H                   (i_ABS_2H                   ),
    .i_ABS_1H                   (i_ABS_1H                   ),

    .i_DFFD_7E_A_Q              (i_DFFD_7E_A_Q              ),
    .i_DFFD_7E_A_Q_PCEN_n       (i_DFFD_7E_A_Q_PCEN_n       ),
    .i_DFFD_8E_B_Q              (i_DFFD_8E_B_Q              ),
    .i_DFFQ_8F_Q2_NCEN_n        (i_DFFQ_8F_Q2_NCEN_n        ),
    .i_DFFQ_8F_Q1               (i_DFFQ_8F_Q1               ),

    .i_DFFQ_8F_Q1_DLYD_n        (DFFQ_8F_Q1_DLYD_n          ),
    .i_DFFQ_8F_Q3_DLYD          (DFFQ_8F_Q3_DLYD            ),
    .i_DFFQ_8F_Q2_DLYD          (DFFQ_8F_Q2_DLYD            ),
    .i_DFFQ_8F_Q2_DLYD_n        (DFFQ_8F_Q2_DLYD_n          ),

    .o_OBJ_PIXELOUT             (o_OBJ_PIXELOUT             ),

    //SDRAM requests
    .o_EMU_OBJROM_ADDR          (o_EMU_OBJROM_ADDR          ),
    .i_EMU_OBJROM_DATA          (i_EMU_OBJROM_DATA          ),
    .o_EMU_OBJROM_RQ_n          (o_EMU_OBJROM_RQ_n          ),

    //BRAM programming
    .i_EMU_BRAM_ADDR            (i_EMU_BRAM_ADDR            ),
    .i_EMU_BRAM_DATA            (i_EMU_BRAM_DATA            ),
    .i_EMU_BRAM_WR_n            (i_EMU_BRAM_WR_n            ),

    .i_EMU_BRAM_SEQROM_CS_n     (i_EMU_BRAM_SEQROM_CS_n     )
);




///////////////////////////////////////////////////////////
//////  DATA OUTPUT MUX
////

wire            videoboard_acc_n = &{o_TM_BG_ATTR_CS_n, o_TM_FG_ATTR_CS_n, o_TM_BG_SCR_CS_n, o_TM_PALETTE_CS_n, o_OBJ_PALETTE_CS_n};

always @(*)
begin
    if(!SYSTEM_CTRL_RD_n)
    begin
        `ifdef FASTBOOT
        case({videoboard_acc_n, mainram_cs_n, bankedrom0_cs_n, mainprog_cs_n, ioports_en_n})
            5'b01111: SYSTEM_DATA_READ_BUS <= i_DATA_READ_BUS;
            5'b10111: SYSTEM_DATA_READ_BUS <= mainram_dout;
            5'b11011: SYSTEM_DATA_READ_BUS <= bankedrom0_dout;
            5'b11101: SYSTEM_DATA_READ_BUS <= mainprog_dout; 
            5'b11110: SYSTEM_DATA_READ_BUS <= ioports;
            default: SYSTEM_DATA_READ_BUS <= 8'hFF; //pull up
        endcase

        `else
        case({videoboard_acc_n, mainram_cs_n, bankedrom0_cs_n, mainprog_cs_n, ioports_en_n})
            5'b01111: SYSTEM_DATA_READ_BUS <= i_DATA_READ_BUS;
            5'b10111: SYSTEM_DATA_READ_BUS <= mainram_dout;
            5'b11011: SYSTEM_DATA_READ_BUS <= i_EMU_MAINCPU_DATA;
            5'b11101: SYSTEM_DATA_READ_BUS <= i_EMU_MAINCPU_DATA;
            5'b11110: SYSTEM_DATA_READ_BUS <= ioports;
            default: SYSTEM_DATA_READ_BUS <= 8'hFF; //pull up
        endcase

        `endif
    end
    else
    begin
        if(!int_ack_n)
        begin
            SYSTEM_DATA_READ_BUS <= intvector;
        end
        else
        begin
            SYSTEM_DATA_READ_BUS <= 8'hFF;
        end
    end
end




///////////////////////////////////////////////////////////
//////  SOUND CPU
////

//OPN clock: posedge of 2H
wire            opncen_n = i_ABS_2H | ~i_ABS_1H | i_EMU_CLK6MPCEN_n; 

//sound code
reg     [7:0]   soundcode = 8'h00;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(!soundlatch_ld_n)
        begin
            soundcode <= SYSTEM_DATA_WRITE_BUS;
        end
    end
end

Psychic5_sound sound_main
(
    .i_EMU_MCLK                 (i_EMU_MCLK                 ),

    .i_EMU_CLK5MPCEN_n          (i_EMU_CLK5MPCEN_n          ),
    .i_EMU_CLK5MNCEN_n          (i_EMU_CLK5MNCEN_n          ),
    .i_EMU_OPNCEN_n             (opncen_n                   ),

    .i_EMU_INITRST_n            (i_EMU_INITRST_n            ),
    .i_SOUNDCPU_FORCE_RST_n     (~soundcpu_force_rst        ),

    .i_SOUNDCODE                (soundcode                  ),

    .o_SOUND                    (o_SOUND                    ),

    .i_EMU_BRAM_SOUNDROM_CS_n   (i_EMU_BRAM_SOUNDROM_CS_n   ),
    .i_EMU_BRAM_ADDR            (i_EMU_BRAM_ADDR            ),
    .i_EMU_BRAM_DATA            (i_EMU_BRAM_DATA            ),
    .i_EMU_BRAM_WR_n            (i_EMU_BRAM_WR_n            )
);




endmodule