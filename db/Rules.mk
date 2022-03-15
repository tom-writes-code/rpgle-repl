TBL_SRC := $(wildcard $(d)/*.TABLE)
TBL_SQL := $(patsubst %.TABLE,%.SQL,$(notdir $(TBL_SRC)))
SQLs := $(TBL_SQL)

# TODO: Work out why this rebuilds every time
REPLRSLT.SQL: $(d)/REPLRSLT.TABLE
REPLSRC.SQL: $(d)/REPLSRC.TABLE
REPLVARS.SQL: $(d)/REPLVARS.TABLE
