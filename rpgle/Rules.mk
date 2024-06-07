RPGLE_SRC := $(wildcard $(d)/*.RPGLE)
SQLRPGLE_SRC := $(wildcard $(d)/*.SQLRPGLE)
RPGLE_MODULES := $(patsubst %.RPGLE,%.MODULE,$(notdir $(RPGLE_SRC)))
SQLRPGLE_MODULES := $(patsubst %.SQLRPGLE,%.MODULE,$(notdir $(SQLRPGLE_SRC)))

MODULEs := $(RPGLE_MODULES) $(SQLRPGLE_MODULES)
REFs := QRPGLEREF.FILE/REPL_HLPR.MBR QRPGLEREF.FILE/REPL_PSEUT.MBR

# TODO: Add SET OPTION to SQLRPGLE source
REPLCMD.MODULE: $(d)/REPLCMD.SQLRPGLE
REPLLOAD.MODULE: $(d)/REPLLOAD.RPGLE
REPL_CMPL.MODULE: $(d)/REPL_CMPL.SQLRPGLE
REPL_EVAL.MODULE: $(d)/REPL_EVAL.RPGLE
REPL_GEN.MODULE: $(d)/REPL_GEN.RPGLE
REPL_HLPR.MODULE: $(d)/REPL_HLPR.SQLRPGLE
REPL_INS.MODULE: $(d)/REPL_INS.SQLRPGLE
REPL_PM.MODULE: $(d)/REPL_PM.RPGLE
REPL_PSEU.MODULE: $(d)/REPL_PSEU.SQLRPGLE
REPL.MODULE: $(d)/REPL.RPGLE
REPL_USR.MODULE: $(d)/REPL_USR.RPGLE
REPL_VARS.MODULE: $(d)/REPL_VARS.SQLRPGLE
REPLWRPR.MODULE: $(d)/REPLWRPR.SQLRPGLE
REPLPRTR.MODULE: $(d)/REPLPRTR.SQLRPGLE


QRPGLEREF.FILE:
	$(call echo_cmd,"=== Creating source PF [$(notdir $@)]")
	$(eval crtcmd := CRTSRCPF FILE($(OBJLIB)/$(basename $(@F))) RCDLEN(112) CCSID(37) )
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)

# TODO: Generalise this into a generic recipe
QRPGLEREF.FILE/REPL_HLPR.MBR: $(d)/REPL_HLPR.RPGLEINC | QRPGLEREF.FILE
	$(call echo_cmd,"=== Creating ref member [$(notdir $@)]")
	$(eval crtcmd := CPYFRMSTMF FROMSTMF('$<') TOMBR('/QSYS.LIB/$(OBJLIB).LIB/$@') MBROPT(*REPLACE) )
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)

QRPGLEREF.FILE/REPL_PSEUT.MBR: $(d)/REPL_PSEUT.RPGLEINC | QRPGLEREF.FILE
	$(call echo_cmd,"=== Creating ref member [$(notdir $@)]")
	$(eval crtcmd := CPYFRMSTMF FROMSTMF('$<') TOMBR('/QSYS.LIB/$(OBJLIB).LIB/$@') MBROPT(*REPLACE) )
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)


refs: $(REFs)
all:: refs
