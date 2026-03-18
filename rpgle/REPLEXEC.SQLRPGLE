**FREE

/// @version v3.1.0
/// @file REPLEXEC
/// @brief SQL stored procedure for notebook integration.
///
/// Accepts RPG source as a CLOB, runs it through the REPL pipeline
/// (generate, compile, run), and returns results as a SQL result set.
/// Designed for use from vscode-db2i notebooks or any SQL caller.
///
/// Usage:
///   CALL REPL_EXECUTE('dcl-s x char(10); ...', 'NB-session-123')
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

dcl-ds t_clob qualified template;
  clob_len uns(10);
  clob_data char(65536) ccsid(*jobrunmix);
end-ds;

dcl-pi *n;
  p_source likeds(t_clob);
  p_sessionId varchar(28) const;
end-pi;

dcl-ds sourceLocation likeds(t_sourceLocation);
dcl-s snippetName char(20);
dcl-s lineNum packed(6:0);
dcl-s lineStart int(10);
dcl-s lineEnd int(10);
dcl-s sourceLen int(10);
dcl-s currentLine varchar(200);
dcl-s hasError ind inz(*off);

dcl-c LF x'25';

//------------------------------------------------------------------------------

// Generate snippet name from session ID (first 20 chars)

snippetName = p_sessionId;

// --- Clear previous data for this snippet ---

exec sql
  DELETE FROM replsrc WHERE save_name = :snippetName;

clearSessionPseudoResults();
clearSessionPseudoVariables();

// --- Parse source CLOB into lines and insert into REPLSRC ---

lineNum = 1;
lineStart = 1;
sourceLen = p_source.clob_len;

if sourceLen > 0;

  dow lineStart <= sourceLen;

    lineEnd = %scan(LF: p_source.clob_data: lineStart);

    if lineEnd = 0 or lineEnd > sourceLen;
      // Last line (no trailing newline)
      currentLine = %subst(p_source.clob_data: lineStart:
                           sourceLen - lineStart + 1);
      lineStart = sourceLen + 1;
    else;
      if lineEnd > lineStart;
        currentLine = %subst(p_source.clob_data: lineStart:
                             lineEnd - lineStart);
      else;
        currentLine = '';
      endif;
      lineStart = lineEnd + 1;
    endif;

    // Strip trailing CR if present (handles CRLF)
    if %len(currentLine) > 0;
      if %subst(currentLine: %len(currentLine): 1) = x'0D';
        if %len(currentLine) > 1;
          currentLine = %subst(currentLine: 1:
                               %len(currentLine) - 1);
        else;
          currentLine = '';
        endif;
      endif;
    endif;

    // Insert each line (including blanks for correct line numbering)
    exec sql
      INSERT INTO replsrc
        (session_id, line_number, code, save_name, owner, source_type)
      VALUES
        ('', :lineNum, :currentLine, :snippetName,
         CURRENT_USER, 'mainline');

    lineNum += 1;

  enddo;

endif;

// --- Run REPL pipeline ---

sourceLocation.snippetName = snippetName;
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

// --- Tag all results with external session ID ---

exec sql
  UPDATE replrslt SET external_session_id = :p_sessionId
  WHERE session_id = (QSYS2.JOB_NAME)
    AND (external_session_id IS NULL OR external_session_id = '');

// --- Open result set cursor ---

exec sql
  DECLARE c_replResults CURSOR WITH RETURN FOR
    SELECT line_number, result_number, result_description,
           loop_count, result_type
    FROM replrslt
    WHERE external_session_id = :p_sessionId
    ORDER BY line_number, result_number;

exec sql
  OPEN c_replResults;

exec sql
  SET RESULT SETS CURSOR c_replResults;

// --- Clean up source snippet ---

exec sql
  DELETE FROM replsrc WHERE save_name = :snippetName;

clearSessionPseudoVariables();

*inlr = *on;
return;
