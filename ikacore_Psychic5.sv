//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [48:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output [1:0]  VGA_SL,
    output        VGA_SCALER, // Force VGA scaler

    input  [11:0] HDMI_WIDTH,
    input  [11:0] HDMI_HEIGHT,
    output        HDMI_FREEZE,

`ifdef MISTER_FB
    // Use framebuffer in DDRAM (USE_FB=1 in qsf)
    // FB_FORMAT:
    //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
    //    [3]   : 0=16bits 565 1=16bits 1555
    //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
    //
    // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
    output        FB_EN,
    output  [4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output  [7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,
`endif
`endif

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO, // 24.576 MHz
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //High latency DDR3 RAM interface
    //Use for non-critical time purposes
    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output  [7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output  [7:0] DDRAM_BE,
    output        DDRAM_WE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
    //Secondary SDRAM
    //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
    input         SDRAM2_EN,
    output        SDRAM2_CLK,
    output [12:0] SDRAM2_A,
    output  [1:0] SDRAM2_BA,
    inout  [15:0] SDRAM2_DQ,
    output        SDRAM2_nCS,
    output        SDRAM2_nCAS,
    output        SDRAM2_nRAS,
    output        SDRAM2_nWE,
`endif

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    input   [6:0] USER_IN,
    output  [6:0] USER_OUT,

    input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

///////////////////////////////////////////////////////////
//////  PLL
////

wire            CLK60M;
wire            pll_locked;

pll pll(
    .refclk                     (CLK_50M                    ),
    .rst                        (1'b0                       ),
    .outclk_0                   (CLK60M                     ),
    .outclk_1                   (SDRAM_CLK                  ),
    .locked                     (pll_locked                 )
);





///////////////////////////////////////////////////////////
//////  HPS_IO
////

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X  XXX XX X XX XX  XXX X XXXX

wire    [127:0] status; //status bits

`include "build_id.v" 
localparam CONF_STR = {
    "ikacore_Psychic5;",
    "-;",
    "P1,Scaler Settings;",
    "P1-;",
    "P1O7,Aspect ratio,original,full screen;",
    "P1O8,Orientation,vertial,horizontal;",
    "P1OA,VGA Scaler,off,on;",
    "P1O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "-;",
    "ON,Flip,normal,flip;",
    "OCD,Refresh rate,original,NTSC-friendly,custom;",
    "h0OFG,H refresh rate adj,0,2,4,6;",
    "h0OJL,V refresh rate adj,0,1,2,3,4,5,6,7;",
    "OPS,V position,original,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7;",
    "-;",
    "DIP;",
    "-;",
    "R0,Reset and close OSD;",
    "J1,Attack,Jump,Test,Service,Coin,Start;",
    "jn,A,B,Start,Select,R,L;",

    "V,v",`BUILD_DATE 
};

//ioctl
wire    [15:0]  ioctl_index;
wire            ioctl_download;
wire    [26:0]  ioctl_addr;
wire    [7:0]   ioctl_data;
wire            ioctl_wr;
wire            ioctl_wait;

wire    [1:0]   buttons; //hardware button
wire    [15:0]  joystick_0;
wire    [15:0]  joystick_1;

wire            forced_scandoubler; //?
wire    [21:0]  gamma_bus;


hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys                    (CLK60M                     ),
    .HPS_BUS                    (HPS_BUS                    ),
    .EXT_BUS                    (                           ),

    .buttons                    (buttons                    ),
    .status                     (status                     ),
    .status_in                  (128'h0                     ),

    .status_menumask            ({15'd0, status[13]}        ),
    .direct_video               (direct_video               ),

    .forced_scandoubler         (forced_scandoubler         ),
    .gamma_bus                  (gamma_bus                  ),

    .ioctl_download             (ioctl_download             ),
    .ioctl_upload               (                           ),
    .ioctl_upload_req           (1'b0                       ),
    .ioctl_wr                   (ioctl_wr                   ),
    .ioctl_addr                 (ioctl_addr                 ),
    .ioctl_dout                 (ioctl_data                 ),
    .ioctl_din                  (                           ),
    .ioctl_index                (ioctl_index                ),
    .ioctl_wait                 (ioctl_wait                 ),
    
    .joystick_0                 (joystick_0                 ),
    .joystick_1                 (joystick_1                 )
);





///////////////////////////////////////////////////////////
//////  CORE
////

wire            hsync_n, vsync_n;
wire            hblank_n, vblank_n;
wire    [3:0]   video_r, video_g, video_b; //need to use color conversion LUT

wire    [15:0]  sound;
wire            pxcen;
wire            master_reset = RESET | status[0] | buttons[1];

wire            flip = status[23];
wire    [1:0]   pxcntr_adjust_mode = status[13:12];
wire    [1:0]   pxcntr_adjust_h = status[16:15];
wire    [2:0]   pxcntr_adjust_v = status[21:19];
wire    [3:0]   vpos_adjust = status[28:25];

assign          AUDIO_L = sound;
assign          AUDIO_R = sound;
assign          AUDIO_S = 1'b1;

Psychic5_emu gameboard_top (
    .i_EMU_MCLK                 (CLK60M                     ),
    .i_EMU_INITRST              (RESET                      ),
    .i_EMU_SOFTRST              (buttons[1] | status[0]     ),

    .o_HSYNC_n                  (hsync_n                    ),
    .o_VSYNC_n                  (vsync_n                    ),
    .o_HBLANK_n                 (hblank_n                   ),
    .o_VBLANK_n                 (vblank_n                   ),

    .o_VIDEO_R                  (video_r                    ),
    .o_VIDEO_G                  (video_g                    ),
    .o_VIDEO_B                  (video_b                    ),

    .o_SOUND                    (sound                      ),

    .o_PXCEN                    (pxcen                      ),

    .i_JOYSTICK0                (joystick_0                 ),
    .i_JOYSTICK1                (joystick_1                 ),

    .i_EMU_FLIP                 (flip                       ),
    .i_EMU_VPOS_ADJ             (vpos_adjust                ),
    .i_EMU_PXCNTR_ADJ_MODE      (pxcntr_adjust_mode         ),
    .i_EMU_PXCNTR_ADJ_H         (pxcntr_adjust_h            ),
    .i_EMU_PXCNTR_ADJ_V         (pxcntr_adjust_v            ),

    .ioctl_index                (ioctl_index                ),
    .ioctl_download             (ioctl_download             ),
    .ioctl_addr                 (ioctl_addr                 ),
    .ioctl_data                 (ioctl_data                 ),
    .ioctl_wr                   (ioctl_wr                   ),
    .ioctl_wait                 (ioctl_wait                 ),

    .sdram_dq                   (SDRAM_DQ                   ),
    .sdram_a                    (SDRAM_A                    ),
    .sdram_dqml                 (SDRAM_DQML                 ),
    .sdram_dqmh                 (SDRAM_DQMH                 ),
    .sdram_ba                   (SDRAM_BA                   ),
    .sdram_nwe                  (SDRAM_nWE                  ),
    .sdram_ncas                 (SDRAM_nCAS                 ),
    .sdram_nras                 (SDRAM_nRAS                 ),
    .sdram_ncs                  (SDRAM_nCS                  ),
    .sdram_cke                  (SDRAM_CKE                  ),

    .debug                      (LED_USER                   )
);





///////////////////////////////////////////////////////////
//////  SCALER
////

assign VGA_F1 = 0;
assign VGA_SCALER = status[10];
assign HDMI_FREEZE = 0;
assign FB_FORCE_BLANK = 0;

//                   eval dv-----------|  eval fs----------|    eval horiz----| vert-|
assign VIDEO_ARX = direct_video ? 8'd4 : status[7] ? 8'd16 : status[8] ? 8'd4 : 8'd3;
assign VIDEO_ARY = direct_video ? 8'd3 : status[7] ? 8'd9  : status[8] ? 8'd3 : 8'd4;

arcade_video #(256,12) arcade_video (
    .clk_video                  (CLK60M                     ),
    .ce_pix                     (pxcen                      ),
     
    .RGB_in                     ({video_r, video_g, video_b}),
    .HBlank                     (~hblank_n                  ),
    .VBlank                     (~vblank_n                  ),
    .HSync                      (~hsync_n                   ),
    .VSync                      (~vsync_n                   ),

    .CLK_VIDEO                  (CLK_VIDEO                  ),
    .CE_PIXEL                   (CE_PIXEL                   ),
    .VGA_R                      (VGA_R                      ),
    .VGA_G                      (VGA_G                      ),
    .VGA_B                      (VGA_B                      ),
    .VGA_HS                     (VGA_HS                     ),
    .VGA_VS                     (VGA_VS                     ),
    .VGA_DE                     (VGA_DE                     ),
    .VGA_SL                     (VGA_SL                     ),

    .fx                         (status[5:3]                ), //3bit
    .forced_scandoubler         (forced_scandoubler         ),
    .gamma_bus                  (gamma_bus                  ) //22bit
);

assign          FB_FORCE_BLANK = 1'b0;
reg             rotate_ccw = 1'b1;
wire            no_rotate = direct_video | status[7] | status[8];
wire            video_rotated;
screen_rotate screen_rotate ( .* );








endmodule
