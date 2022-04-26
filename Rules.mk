SUBDIRS = cmd db dsp rpgle bnd 

package: RPGLEREPL.FILE
	$(call echo_cmd,"=== PACKAGE: Granting public authority to library")
	$(eval crtcmd := GRTOBJAUT OBJ($(OBJLIB)/*ALL) USER(*PUBLIC) OBJTYPE(*ALL) AUT(*ALL))
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)
	$(call echo_cmd,"=== PACKAGE: Granting public authority to objects")
	$(eval crtcmd := GRTOBJAUT OBJ($(OBJLIB)/*ALL) USER(*PUBLIC) OBJTYPE(*ALL) AUT(*ALL))
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)
	$(call echo_cmd,"=== PACKAGE: Change library ownership to QPGMR")
	$(eval crtcmd := CHGOWN OBJ('/QSYS.LIB/$(OBJLIB).LIB') NEWOWN(QPGMR))
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)
	$(call echo_cmd,"=== PACKAGE: Change object ownership to QPGMR")
	$(eval crtcmd := CHGOWN OBJ('/QSYS.LIB/$(OBJLIB).LIB') NEWOWN(QPGMR))
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)
	$(call echo_cmd,"=== PACKAGE: Saving objects to [$(OBJLIB)/RPGLEREPL]")
	$(eval crtcmd := SAVOBJ OBJ(*ALL) LIB($(OBJLIB)) DEV(*SAVF) SAVF($(OBJLIB)/RPGLEREPL) CLEAR(*REPLACE) TGTRLS($(TGTRLS)) DTACPR(*YES) SELECT((*OMIT *ALL *FILE SAVF) (*OMIT *ALL *MODULE) (*OMIT EVFEVENT *FILE)))
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)

RPGLEREPL.FILE:
	$(call echo_cmd,"=== PACKAGE: Creating save file [$(OBJLIB)/RPGLEREPL]")
	$(eval crtcmd := CRTSAVF FILE($(OBJLIB)/RPGLEREPL))
	@$(PRESETUP) \
	$(SCRIPTSPATH)/launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 && $(call logSuccess,$@) || $(call logFail,$@)
