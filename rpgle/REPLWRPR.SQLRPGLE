**FREE

/// @version v3.1.0
/// @file REPLWRPR
/// @brief External wrapper program for batch/CI execution.
///
/// Called from shell scripts or external tools to generate, compile,
/// and run REPL snippets non-interactively. Accepts a source location
/// or named snippet, a verbosity level, and an external session ID
/// for result correlation. Returns 0 for success, -1 for failure.
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

dcl-pr writeout extproc('write');
  fd   int(10) value;
  buf  pointer value;
  size int(10) value;
end-pr;

//------------------------------------------------------------------------------

dcl-pi *n;
  sourceLibrary char(10) const;
  sourceFile char(10) const;
  sourceMember char(10) const;
  snippetName char(20) const;
  verbosity char(1) const;
  sessionId char(28) const;
end-pi;

dcl-ds sourceLocation likeds(t_sourceLocation);
dcl-s result char(50);
dcl-s newLine char(1) inz(x'25');

// clear any existing results

clearSessionPseudoResults();
clearSessionPseudoVariables();

// create generated source object

sourceLocation.library = sourceLibrary;
sourceLocation.file = sourceFile; 
sourceLocation.member = sourceMember;
sourceLocation.snippetName = snippetName;
sourceLocation.isUserDirected = *on; 

monitor;
  createGeneratedSourceObject(sourceLocation);
on-error;
  writeError('-1: Could not generate module' + newLine);
  exec sql
    UPDATE replrslt SET external_session_id = :sessionId
    WHERE session_id = (QSYS2.JOB_NAME)
      AND (external_session_id IS NULL OR external_session_id = '');
  *inlr = *on;
  return;
endmon;

// compile generated source object

monitor;
  compileGeneratedSourceObject(*off: *on);
on-error;
  writeError('-1: Could not generate program object' + newLine);
  exec sql
    UPDATE replrslt SET external_session_id = :sessionId
    WHERE session_id = (QSYS2.JOB_NAME)
      AND (external_session_id IS NULL OR external_session_id = '');
  *inlr = *on;
  return;
endmon;

// run generated program object

monitor;
  runGeneratedProgramObject();
on-error;
  writeError('-1: Could not run snippet' + newLine);
  exec sql
    UPDATE replrslt SET external_session_id = :sessionId
    WHERE session_id = (QSYS2.JOB_NAME)
      AND (external_session_id IS NULL OR external_session_id = '');
  *inlr = *on;
  return;
endmon;

exec sql
  UPDATE replrslt SET external_session_id = :sessionId 
  WHERE session_id = (QSYS2.JOB_NAME);
  
clearSessionPseudoVariables();

*inlr = *on;
return;

//------------------------------------------------------------------------------

dcl-proc writeError;
  dcl-pi *n;
    errorMessage char(50) value options(*exact);
  end-pi;
  dcl-s errorCode char(3);
  dcl-s newLine char(1) inz(x'25');  

  errorCode = '-1' + newLine;

  replResult_recordCustomMessage(errorMessage);

  if verbosity = '0';
    writeout(2: %addr(errorCode): %len(%trim(errorCode)));
  else;
    writeout(2: %addr(errorMessage): %len(%trim(errorMessage)));
  endif;
end-proc;

//------------------------------------------------------------------------------
