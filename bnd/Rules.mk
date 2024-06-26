SRVPGMs := REPL_CMPL.SRVPGM REPL_EVAL.SRVPGM REPL_GEN.SRVPGM REPL_HLPR.SRVPGM REPL_INS.SRVPGM REPL_PM.SRVPGM REPL_PSEU.SRVPGM REPL_USR.SRVPGM REPL_VARS.SRVPGM
PGMs := REPL.PGM REPLLOAD.PGM REPLWRPR.PGM REPLPRTR.PGM

REPL_CMPL.SRVPGM: $(d)/REPL_CMPL.BND REPL_CMPL.MODULE REPL_PM.SRVPGM REPL_USR.SRVPGM
# REPL_CMPL.SRVPGM: TEXT=repl-rpg Compile Module / Program Objects

REPL_EVAL.SRVPGM: $(d)/REPL_EVAL.BND REPL_EVAL.MODULE REPL_VARS.SRVPGM REPL_INS.SRVPGM
# REPL_EVAL.SRVPGM: TEXT=repl-rpg Evaluate Lines of Code

REPL_GEN.SRVPGM: $(d)/REPL_GEN.BND REPL_GEN.MODULE REPL_USR.SRVPGM REPL_VARS.SRVPGM REPL_EVAL.SRVPGM REPL_PSEU.SRVPGM REPL_INS.SRVPGM
# REPL_GEN.SRVPGM: TEXT=repl-rpg generate source code

REPL_HLPR.SRVPGM: $(d)/REPL_HLPR.BND REPL_HLPR.MODULE
# REPL_HLPR.SRVPGM: TEXT=Helpers for REPL Generated Programs

REPL_INS.SRVPGM: $(d)/REPL_INS.BND REPL_INS.MODULE
# REPL_INS.SRVPGM: TEXT=repl-rpg Add line to generated source

REPL_PM.SRVPGM: $(d)/REPL_PM.BND REPL_PM.MODULE 
# REPL_PM.SRVPGM: TEXT=repl-rpg Program message handling

REPL_PSEU.SRVPGM: $(d)/REPL_PSEU.BND REPL_PSEU.MODULE REPL_USR.SRVPGM REPL_INS.SRVPGM
# REPL_PSEU.SRVPGM: TEXT=repl-rpg Edit pseudo code

REPL_USR.SRVPGM: $(d)/REPL_USR.BND REPL_USR.MODULE REPL_PM.SRVPGM
# REPL_USR.SRVPGM: TEXT=repl-rpg Perform User Actions

REPL_VARS.SRVPGM: $(d)/REPL_VARS.BND REPL_VARS.MODULE
# REPL_VARS.SRVPGM: TEXT=repl-rpg Interrogate Variables

REPL.PGM: private ACTGRP=*NEW
REPL.PGM: REPL.MODULE REPL_PM.SRVPGM REPL_CMPL.SRVPGM REPL_PSEU.SRVPGM REPL_GEN.SRVPGM REPL_USR.SRVPGM REPL_INS.SRVPGM

REPLLOAD.PGM: REPLLOAD.MODULE REPL_PSEU.SRVPGM

REPLWRPR.PGM: REPLWRPR.MODULE REPL_CMPL.SRVPGM REPL_EVAL.SRVPGM REPL_GEN.SRVPGM REPL_HLPR.SRVPGM REPL_PSEU.SRVPGM REPL_USR.SRVPGM

REPLPRTR.PGM: REPLPRTR.MODULE REPL_PSEU.SRVPGM
