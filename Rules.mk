SUBDIRS = cmd db dsp rpgle bnd 

package:
	$(call echo_cmd,"=== PACKAGE: Creating save file [$(OBJLIB)/RPGLEREPL]")
	$(eval crtcmd := CRTSAVF FILE($(OBJLIB)/RPGLEREPL))
	@$(PRESETUP);  \
	launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 || true; \
	$(POSTCLEANUP)
	$(call echo_cmd,"=== PACKAGE: Granting public authority to library")
	$(eval crtcmd := GRTOBJAUT OBJ($(OBJLIB)/*ALL) USER(*PUBLIC) OBJTYPE(*ALL) AUT(*ALL))
	@$(PRESETUP);  \
	launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 || true; \
	$(POSTCLEANUP)
	$(call echo_cmd,"=== PACKAGE: Granting public authority to objects")
	$(eval crtcmd := GRTOBJAUT OBJ($(OBJLIB)/*ALL) USER(*PUBLIC) OBJTYPE(*ALL) AUT(*ALL))
	@$(PRESETUP);  \
	launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 || true; \
	$(POSTCLEANUP)
	$(call echo_cmd,"=== PACKAGE: Change ownership to QPGMR")
	$(eval crtcmd := CHGOWN OBJ('/QSYS.LIB/$(OBJLIB).LIB') NEWOWN(QPGMR) SUBTREE(*ALL))
	@$(PRESETUP);  \
	launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 || true; \
	$(POSTCLEANUP)
	$(call echo_cmd,"=== PACKAGE: Saving objects to [$(OBJLIB)/RPGLEREPL]")
	$(eval crtcmd := SAVOBJ OBJ(*ALL) LIB($(OBJLIB)) DEV(*SAVF) SAVF($(OBJLIB)/RPGLEREPL) CLEAR(*REPLACE) TGTRLS($(TGTRLS)) DTACPR(*YES) SELECT((*OMIT *ALL *FILE SAVF) (*OMIT *ALL *MODULE) (*OMIT EVFEVENT *FILE)))
	@$(PRESETUP);  \
	launch "$(JOBLOGFILE)" "$(crtcmd)" >> $(LOGFILE) 2>&1 || true; \
	$(POSTCLEANUP)
