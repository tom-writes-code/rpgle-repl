DSP_SRC := $(wildcard $(d)/*.DSPF)
DSPFs := $(patsubst %.DSPF,%.FILE,$(notdir $(DSP_SRC)))

REPLFM.FILE: $(d)/REPLFM.DSPF

REPLLOADFM.FILE: $(d)/REPLLOADFM.DSPF
