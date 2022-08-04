derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -exclusive \
   -group [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] \

# core specific constraints
