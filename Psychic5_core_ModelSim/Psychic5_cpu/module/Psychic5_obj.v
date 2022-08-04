module Psychic5_obj
(
    //clocks
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,

    input   wire            i_EMU_MRST_n,

    //DMA control
    output  reg             o_OBJDMA_BUSRQ_n = 1'b1,
    input   wire            i_OBJDMA_BUSACK_n,

    //data/addr
    output  wire    [12:0]  o_OBJDMA_ADDR_BUS,
    input   wire    [7:0]   i_OBJDMA_DATA_READ_BUS,
    output  wire            o_OBJDMA_CTRL_RD_n,
    output  wire            o_OBJDMA_CTRL_WR_n,

    //flip
    input   wire            i_FLIP,
    input   wire            i_OBJ_BUF_INIT_STOP_n,

    //Video timings
    input   wire    [7:0]   i_FLIP_HV_BUS,
    input   wire            i_ABS_4H, i_ABS_2H, i_ABS_1H, //hcounter bits

    input   wire            i_DFFD_7E_A_Q, //IDC PIN D6
    input   wire            i_DFFD_7E_A_Q_PCEN_n,
    input   wire            i_DFFD_8E_B_Q, //IDC PIN D7
    input   wire            i_DFFQ_8F_Q2_NCEN_n, //negative edge enable signal
    input   wire            i_DFFQ_8F_Q1, //IDC PIN D8

    //delayed video timings from CPU board
    input   wire            i_DFFQ_8F_Q1_DLYD_n, //8M LS175 PIN3
    input   wire            i_DFFQ_8F_Q3_DLYD, //8M LS175 PIN7
    input   wire            i_DFFQ_8F_Q2_DLYD, //8M LS175 PIN10
    input   wire            i_DFFQ_8F_Q2_DLYD_n, //8M LS175 PIN11

    output  wire    [7:0]   o_OBJ_PIXELOUT
);


///////////////////////////////////////////////////////////
//////  SPRITE ENGINE
////

//
//  DMA SECTION
//

//DMA I/O
assign  o_OBJDMA_CTRL_RD_n = 1'b0;
assign  o_OBJDMA_CTRL_WR_n = 1'b1;


//async DMA control
//this code emulates the original asynchronous circuit
reg             objdma_start_n; //6L LS74 A
wire            objdma_complete; //4H LS161 carry

always @(posedge i_EMU_MCLK or negedge i_EMU_MRST_n)
begin
    if(!i_EMU_MRST_n) 
    begin
        o_OBJDMA_BUSRQ_n <= 1'b1; //ASYNC RESET
    end
    else 
    begin
        if(!i_EMU_CLK6MPCEN_n)
        begin
            if(i_ABS_1H == 1'b1) //top condition: 1H_n clocked [5L LS74 A] can set [6L LS74 B] asynchronously to negate busrq_n
            begin
                if(objdma_complete == 1'b1)
                begin
                    o_OBJDMA_BUSRQ_n <= 1'b1; //negate o_OBJDMA_BUSRQ_n unconditionally(async set)
                    objdma_start_n <= 1'b1; //negate objdma_start_n through [6L LS74 B] unconditionally(async set)
                end
                else
                begin
                    if(i_DFFQ_8F_Q2_NCEN_n == 1'b0) 
                    begin
                        o_OBJDMA_BUSRQ_n <= 1'b0; //async set not asserted: just load 0
                    end
                    else
                    begin
                        o_OBJDMA_BUSRQ_n <= o_OBJDMA_BUSRQ_n; //hold
                    end

                    if(o_OBJDMA_BUSRQ_n == 1'b1) 
                    begin
                        objdma_start_n <= 1'b1; //[6L LS74 A] cannot load data if busrq_n still holds 1
                    end
                    else
                    begin
                        objdma_start_n <= i_OBJDMA_BUSACK_n; //load
                    end
                end
            end
            else
            begin
                if(i_DFFQ_8F_Q2_NCEN_n == 1'b0)
                begin
                    o_OBJDMA_BUSRQ_n <= 1'b0; //async set is not yet or not sampled by [5L LS74 A]: load 0
                end
                else
                begin
                    o_OBJDMA_BUSRQ_n <= o_OBJDMA_BUSRQ_n; //hold
                end

                if(o_OBJDMA_BUSRQ_n == 1'b1) 
                begin
                    objdma_start_n <= 1'b1; //[6L LS74 A] cannot load data if busrq_n still holds 1
                end
                else
                begin
                    objdma_start_n <= objdma_start_n; //[6L LS74 A] holds data at this time
                end
            end
        end
    end
end



//
//  DMA RAM address counter
//

//sprite code/attribute counter
reg     [3:0]   objdma_attr_cntr = 4'b1011; //attributes are start from byte B and end at F
reg     [7:0]   objdma_objcode_cntr = 8'b1010_0000;

//attr counter flags
wire            objdma_attr_byte_f = &{objdma_attr_cntr}; //5J LS161 carry out
wire            objdma_attr_byte_7_n = ~&{~objdma_attr_cntr[3], objdma_attr_cntr[2:0]}; //7L LS04, 6M LS20

//sprite code counter control
wire            next_objcode; //output of sequencer ROM: feedback signal
wire            objcode_cntup = ((~objdma_attr_byte_7_n & next_objcode) | objdma_attr_byte_f); //(7L LS04 C, 7K LS08 D) 8L LS32 D
wire            objcode_rst_n = ~objdma_start_n | i_DFFD_8E_B_Q; //8L LS32 B
assign  objdma_complete = &{objdma_objcode_cntr, objcode_cntup}; //carry out of entire code counter

//sprite table RAM control
wire    [9:0]   objtable_ram_addr = {objdma_objcode_cntr[6:0], objdma_attr_cntr[2:0]};
wire            objtable_ram_rd = ~i_OBJDMA_BUSACK_n; //7L LS04 F
wire            objtable_ram_wr = objdma_start_n | ~i_ABS_1H; //8L LS32 A

//sprite table DMA address
assign  o_OBJDMA_ADDR_BUS = {2'b10, objdma_objcode_cntr[6:0], objdma_attr_cntr[3:0]};

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_ABS_1H == 1'b1)
        begin
            //A2-A0, 5J LS161
            if((~objcode_cntup & objcode_rst_n) == 1'b0)
            begin
                objdma_attr_cntr <= {~i_OBJDMA_BUSACK_n, 3'b011};
            end
            else
            begin
                if(objdma_attr_byte_7_n == 1'b1)
                begin
                    objdma_attr_cntr <= objdma_attr_cntr + 4'h1;
                end
            end

            //A9-A3, 4J 4H LS161
            if(objcode_rst_n == 1'b0)
            begin
                objdma_objcode_cntr <= 8'hA0;
            end
            else
            begin
                if(objcode_cntup == 1'b1)
                begin
                    objdma_objcode_cntr <= objdma_objcode_cntr + 8'h01;
                end
            end
        end
    end
end



//
//  object table RAM
//

//3J 6116
wire    [7:0]   objtable_dout;
SRAM #(.aw( 10 ), .dw( 8 ), .pol( 1 ), .simhexfile()) OBJTABLE
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (objtable_ram_addr          ),
    .i_DIN                      (i_OBJDMA_DATA_READ_BUS     ),
    .o_DOUT                     (objtable_dout              ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (objtable_ram_rd            ),
    .i_WR_n                     (objtable_ram_wr            )
);



//
//  attribute latches
//

reg     [7:0]   obj_attr_latch_a, obj_attr_latch_b, obj_attr_latch_c, obj_attr_latch_d;
reg     [5:0]   obj_attr_latch_e, obj_attr_latch_f;

//obj attributes
wire    [8:0]   obj_hpos = {obj_attr_latch_c[0], obj_attr_latch_b};
wire    [7:0]   obj_vpos = obj_attr_latch_a;
wire    [9:0]   obj_code = {obj_attr_latch_e[5:4], obj_attr_latch_d};
wire            obj_disable = obj_attr_latch_f[4];
wire            obj_size = obj_attr_latch_e[1]; //0 = 16*16; 1 = 32*32
wire    [3:0]   obj_palette = obj_attr_latch_f[3:0];
wire            obj_hflip = obj_attr_latch_e[2];
wire            obj_hflip_dlyd = obj_attr_latch_f[5];
wire            obj_vflip = obj_attr_latch_e[3];

//(3)   Y7 Y6 Y5 Y4 Y3 Y2 Y1 Y0      a  3N
//(4)   X7 X6 X5 X4 X3 X2 X1 X0      b  4T
//(5)   O9 O8 VF HF SZ -- EN X8      c  3M
//(6)   C7 C6 C5 C4 C3 C2 C1 C0      d  2N
//            O9 O8 VF HF SZ --      e  4L   get [5:0] from 3M[7:2]
//(7)         HF EN P3 P2 P1 P0      f  3L   get HF from 4L, get EN from 3M

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_ABS_1H == 1'b1)
        begin
            if(i_DFFD_8E_B_Q == 1'b1) //see 4K LS138 PIN6 
            begin
                case(objtable_ram_addr[2:0])
                    3'h3: obj_attr_latch_a <= objtable_dout;      
                    3'h4: obj_attr_latch_b <= objtable_dout;      
                    3'h5: obj_attr_latch_c <= objtable_dout;      
                    3'h6: begin obj_attr_latch_d <= objtable_dout; obj_attr_latch_e <= obj_attr_latch_c[7:2]; end 
                    3'h7: obj_attr_latch_f <= {obj_attr_latch_e[2], obj_attr_latch_c[1], objtable_dout[3:0]};
                    default: ;
                endcase
            end
        end
    end
end



//
//  sequencer section
//

/*
    I hate this shit but it's inevitable.

    obj_size = 0
    counter A carry drives counter B
    C and D are stuck at 4'hE

    obj_size = 1
    counter A carry drives counter C, C drives B, and B drives D
    counter C and D always starts at 4'hE

    toggling obj_size 1->0 while counting
    counter B will work by receiving A's carry
    counter C stops, and reset when A is 4'hF
    counter D stops, and reset when B is 4'hF
*/

reg     [3:0]   seqrom_cntr_A = 4'h0;
reg     [3:0]   seqrom_cntr_B = 4'h0;
reg     [3:0]   seqrom_cntr_C = 4'hE;
reg     [3:0]   seqrom_cntr_D = 4'hE;

wire    [9:0]   seqrom_addr = {seqrom_cntr_D[0], seqrom_cntr_C[0], seqrom_cntr_B, seqrom_cntr_A};
wire    [3:0]   seqrom_dout;
assign  next_objcode = (obj_size == 1'b0) ? seqrom_dout[2] : seqrom_dout[3];

wire    [7:0]   obj_rom_low_dout, obj_rom_high_dout;
reg     [7:0]   obj_pixellatch = 8'hFF; //3R LS273, why is this here? This LS273 is clocked by ~seqrom_cntr_A[0]
wire            obj_buf_hcntr_ld_n = seqrom_dout[0];
wire            obj_buf_vcntr_ld_n = seqrom_dout[1];

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_DFFQ_8F_Q1 == 1'b0) //synchronous reset
        begin
            seqrom_cntr_A <= 4'h0;
            seqrom_cntr_B <= 4'h0;
            seqrom_cntr_C <= 4'hE;
            seqrom_cntr_D <= 4'hE;
        end
        else //count up
        begin
            //sequencer ROM address counter A; 4U LS161
            if(seqrom_cntr_A == 4'hF)
            begin
                seqrom_cntr_A <= 4'h0;
            end
            else
            begin
                seqrom_cntr_A <= seqrom_cntr_A + 4'h1;
            end

            if(seqrom_cntr_A[0] == 1'b1)
            begin
                if(obj_code[9] == 1'b0) //obj rom pixellatch
                begin
                    obj_pixellatch <= obj_rom_low_dout;
                end
                else
                begin
                    obj_pixellatch <= obj_rom_high_dout;
                end
            end

            //sequencer ROM address counter B; 2T LS161
            if(obj_size == 1'b0)
            begin
                if(seqrom_cntr_A == 4'hF) //count up when cntr_A's carry is 1
                begin
                    if(seqrom_cntr_B == 4'hF)
                    begin
                        seqrom_cntr_B <= 4'h0;
                    end
                    else
                    begin
                        seqrom_cntr_B <= seqrom_cntr_B + 4'h1;
                    end
                end
            end
            else
            begin
                if(seqrom_cntr_A == 4'hF && seqrom_cntr_C == 4'hF) //count up when A->C->carry is 1
                begin
                    if(seqrom_cntr_B == 4'hF)
                    begin
                        seqrom_cntr_B <= 4'h0;
                    end
                    else
                    begin
                        seqrom_cntr_B <= seqrom_cntr_B + 4'h1;
                    end
                end
            end

            //sequencer ROM address counter C; 3U LS161
            if(obj_size == 1'b0)
            begin
                if(seqrom_cntr_A == 4'hF) //reset counter with 4'h7 when obj_size is 0
                begin
                    seqrom_cntr_C <= 4'hE;
                end
            end
            else
            begin
                if(seqrom_cntr_A == 4'hF) //count up when 3A->carry is 1
                begin
                    if(seqrom_cntr_C == 4'hF)
                    begin
                        seqrom_cntr_C <= 4'hE;
                    end
                    else
                    begin
                        seqrom_cntr_C <= seqrom_cntr_C + 4'h1;
                    end
                end
            end

            //sequencer ROM address counter D; 1U LS161
            if(obj_size == 1'b0)
            begin
                if(seqrom_cntr_B == 4'hF) //reset counter with 4'h7 when obj_size is 0
                begin
                    seqrom_cntr_D <= 4'hE;
                end
            end
            else
            begin
                if(seqrom_cntr_A == 4'hF && seqrom_cntr_C == 4'hF && seqrom_cntr_B == 4'hF) //count up when A->C->B->carry is 1
                begin
                    if(seqrom_cntr_D == 4'hF)
                    begin
                        seqrom_cntr_D <= 4'hE;
                    end
                    else
                    begin
                        seqrom_cntr_D <= seqrom_cntr_D + 4'h1;
                    end
                end
            end
        end
    end
end


//sequencer ROM MB7122E = 82S137
PROM #(.aw( 10 ), .dw( 4 ), .pol( 0 ), .simhexfile("roms/rom_3t.txt")) ROM_3T
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (seqrom_addr                ),
    .o_DOUT                     (seqrom_dout                ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (1'b0                       )
);



//
//  sprite ROM
//

wire    [15:0]  obj_rom_addr;
assign  obj_rom_addr[15:9] = obj_code[8:2];
assign  obj_rom_addr[8:7] = (obj_size == 1'b0) ? obj_code[1:0] : {seqrom_addr[8] ^ obj_hflip, seqrom_addr[9] ^ obj_vflip};
assign  obj_rom_addr[6:0] = {seqrom_addr[3], seqrom_addr[7:4], seqrom_addr[2:1]} ^ {obj_hflip, {4{obj_vflip}}, {2{obj_hflip}}};

wire    [3:0]   obj_pixelout = ((obj_hflip_dlyd ^ seqrom_addr[0]) == 1'b0) ? obj_pixellatch[7:4] : obj_pixellatch[3:0];//3S LS32 B

PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_4p.txt")) ROM_4P
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (obj_rom_addr               ),
    .o_DOUT                     (obj_rom_low_dout           ),
    .i_CS_n                     (obj_code[9]                ),
    .i_RD_n                     (1'b0                       )
);

PROM #(.aw( 16 ), .dw( 8 ), .pol( 1 ), .simhexfile("roms/rom_4s.txt")) ROM_4S
(
    .i_EMU_PROG_CLK             (                           ),
    .i_EMU_PROG_ADDR            (                           ),
    .i_EMU_PROG_DIN             (                           ),
    .i_EMU_PROG_CS_n            (1'b1                       ),
    .i_EMU_PROG_WR_n            (                           ),
    
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (obj_rom_addr               ),
    .o_DOUT                     (obj_rom_high_dout          ),
    .i_CS_n                     (~obj_code[9]               ),
    .i_RD_n                     (1'b0                       )
);



//
//  frame buffer section
//

//hpos counter
reg     [8:0]   obj_buf_hcntr; //5T 5U 8U LS163
wire            obj_offscreen_n = obj_buf_hcntr[8];
wire    [7:0]   obj_buf_hcntr_flip = obj_buf_hcntr ^ {8{(i_FLIP && i_DFFQ_8F_Q2_DLYD)}}; //7T LS08 B

wire    [7:0]   obj_buf_even_dout, obj_buf_odd_dout;
reg     [15:0]  obj_buf_pixellatch; //this pixellatches are clocked by hcntr[0]

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if((i_DFFQ_8F_Q3_DLYD || i_DFFQ_8F_Q2_DLYD_n) == 1'b0) //synchronous reset
        begin
            obj_buf_hcntr <= 9'd0;
        end
        else
        begin
            if(obj_buf_hcntr_ld_n == 1'b0) //synchronous load
            begin
                obj_buf_hcntr <= {~obj_hpos[8], obj_hpos[7:0]}; 

                if(obj_buf_hcntr == 1'b0 && obj_hpos == 1'b1) obj_buf_pixellatch <= {obj_buf_even_dout, obj_buf_odd_dout};
            end
            else
            begin
                obj_buf_hcntr <= obj_buf_hcntr + 9'd1; //count up

                if(obj_buf_hcntr == 1'b0) obj_buf_pixellatch <= {obj_buf_even_dout, obj_buf_odd_dout};
            end
        end
    end
end


//vpos counter
reg     [7:0]   obj_buf_vcntr; //4N 4M LS161, reset is tied to Vcc
reg     [7:0]   flip_v_bus;
wire    [7:0]   obj_buf_vcntr_flip = (i_DFFQ_8F_Q2_DLYD == 1'b0) ? obj_buf_vcntr : flip_v_bus;

//LS273 8N
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(!i_DFFD_7E_A_Q_PCEN_n)
        begin
            flip_v_bus <= i_FLIP_HV_BUS;
        end
    end
end

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(obj_buf_vcntr_ld_n == 1'b0) //synchronous load
        begin
            obj_buf_vcntr <= obj_vpos;
        end
        else
        begin
            if(~obj_buf_hcntr_ld_n == 1'b1) //ENT ENP
            begin
                obj_buf_vcntr <= obj_buf_vcntr + 8'd1; //count up
            end
            else
            begin
                obj_buf_vcntr <= obj_buf_vcntr;
            end
        end
    end
end


//framebuffer write timing generator

//switches between empty data(FF) and pixel data
wire            obj_buf_even_din_en_n = i_DFFQ_8F_Q1_DLYD_n | obj_buf_hcntr_flip[0]; //7S LS32 D
wire            obj_buf_odd_din_en_n = i_DFFQ_8F_Q1_DLYD_n | ~obj_buf_hcntr_flip[0]; //7S LS32 C

//flags
wire            obj_buf_write_stop_n = {~obj_disable & obj_offscreen_n}; //7M LS04 F, 7T LS08 C
wire            obj_pixel_trn_n = ~&{obj_pixelout}; //6M LS20 A
wire            obj_buf_init_n = ~&{i_OBJ_BUF_INIT_STOP_n, obj_buf_hcntr[0], {i_DFFQ_8F_Q3_DLYD & i_DFFQ_8F_Q2_DLYD}}; //7U LS10 A, 7K LS08 B

//we, origianl circuit ORed this one with CLK6M to compensate gate delay
wire            obj_buf_even_we_n = {~&{~obj_buf_even_din_en_n, obj_buf_write_stop_n, obj_pixel_trn_n} & obj_buf_init_n}; //7U LS10 B, 7T LS08 B
wire            obj_buf_odd_we_n = {~&{~obj_buf_odd_din_en_n, obj_buf_write_stop_n, obj_pixel_trn_n} & obj_buf_init_n}; //7U LS10 C, 7T LS08 A


//sprite buffer address
wire    [14:0]  obj_buf_addr = {obj_buf_vcntr_flip, obj_buf_hcntr_flip[7:1]};
wire    [7:0]   obj_buf_even_din = (obj_buf_even_din_en_n == 1'b0) ? {obj_palette, obj_pixelout} : 8'hFF; //pull ups
wire    [7:0]   obj_buf_odd_din = (obj_buf_odd_din_en_n == 1'b0) ? {obj_palette, obj_pixelout} : 8'hFF; //pull ups


SRAM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile()) OBJ_BUF_EVEN
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (obj_buf_addr               ),
    .i_DIN                      (obj_buf_even_din           ),
    .o_DOUT                     (obj_buf_even_dout          ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (~i_DFFQ_8F_Q1_DLYD_n       ),
    .i_WR_n                     (obj_buf_even_we_n          )
);

SRAM #(.aw( 15 ), .dw( 8 ), .pol( 1 ), .simhexfile()) OBJ_BUF_ODD
(
    .i_MCLK                     (i_EMU_MCLK                 ),
    .i_ADDR                     (obj_buf_addr               ),
    .i_DIN                      (obj_buf_odd_din            ),
    .o_DOUT                     (obj_buf_odd_dout           ),
    .i_CS_n                     (1'b0                       ),
    .i_RD_n                     (~i_DFFQ_8F_Q1_DLYD_n       ),
    .i_WR_n                     (obj_buf_odd_we_n           )
);


//frame buffer output mux
reg     [15:0]      obj_outlatch;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(obj_buf_hcntr[0] == 1'b0)
        begin
            obj_outlatch <= {obj_buf_even_dout, obj_buf_odd_dout};
        end
    end
end

assign  o_OBJ_PIXELOUT = (~obj_buf_hcntr_flip[0] == 1'b0) ? obj_outlatch[15:8] : obj_outlatch[7:0];


endmodule