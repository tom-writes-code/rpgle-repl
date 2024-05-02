CMD_SRC := $(wildcard $(d)/*.CMDSRC)
CMDs := $(patsubst %.CMDSRC,%.CMD,$(notdir $(CMD_SRC)))

REPL.CMD: $(d)/REPL.CMDSRC
REPLWRPR.CMD: $(d)/REPLWRPR.CMDSRC
REPLPRTR.CMD: $(d)/REPLPRTR.CMDSRC


# Experiments
# -----------

# $(info CMDs = $(CMDs))

# $(CMDs): %.CMD: $(d)/%.CMDSRC
