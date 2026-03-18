**FREE

/// @version v3.1.0
/// @file REPLEXEC
/// @brief RPG pipeline runner for notebook integration.
///
/// Called by the SQL procedure REPL_EXECUTE after it has already
/// parsed and inserted source lines into REPLSRC. This program
/// runs the generate/compile/run pipeline only.
/// Result tagging and cursor management are handled by the SQL caller.
///
/// @author Tom Sharp

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked);

//------------------------------------------------------------------------------

/include repl_cmpl
/include repl_eval
/include repl_gen
/include repl_hlpr
/include repl_pseu
/include repl_usr

//------------------------------------------------------------------------------

dcl-pi *n;
  p_snippetName char(20);
end-pi;

dcl-ds sourceLocation likeds(t_sourceLocation);
dcl-s hasError ind inz(*off);

//------------------------------------------------------------------------------

clearSessionPseudoResults();
clearSessionPseudoVariables();

// --- Run REPL pipeline ---

sourceLocation.snippetName = p_snippetName;
sourceLocation.isUserDirected = *on;

monitor;
  createGeneratedSourceObject(sourceLocation);
on-error;
  replResult_recordCustomMessage(
    'Could not generate module');
  hasError = *on;
endmon;

if not hasError;
  monitor;
    compileGeneratedSourceObject(*off: *on);
  on-error;
    replResult_recordCustomMessage(
      'Could not compile program object');
    hasError = *on;
  endmon;
endif;

if not hasError;
  monitor;
    runGeneratedProgramObject();
  on-error;
    replResult_recordCustomMessage(
      'Could not run snippet');
    hasError = *on;
  endmon;
endif;

clearSessionPseudoVariables();

*inlr = *on;
return;
