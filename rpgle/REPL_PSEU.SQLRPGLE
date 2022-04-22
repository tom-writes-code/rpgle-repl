**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

//-----------------------------------------------------------------------

/include repl_cmpl
/include repl_eval
/include repl_ins
/include repl_usr
/include repl_vars

/include repl_pseu

//-----------------------------------------------------------------------

dcl-proc clearSessionPseudoCode export;
  dcl-pi *n;
    sessionId char(28) const options(*nopass);
  end-pi;

  if %parms < %parmnum(sessionId);

    exec sql
      DELETE FROM replsrc
       WHERE session_id = (QSYS2.JOB_NAME);

    clearSessionPseudoVariables();

    clearSessionPseudoResults();

  else;

    exec sql
      DELETE FROM replsrc
       WHERE session_id = :sessionId;

    clearSessionPseudoVariables(sessionId);

    clearSessionPseudoResults(sessionId);

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc clearSessionPseudoVariables export;
  dcl-pi *n;
    sessionId char(28) const options(*nopass);
  end-pi;

  if %parms < %parmnum(sessionId);

    exec sql
      DELETE FROM replvars
       WHERE session_id = (QSYS2.JOB_NAME);

  else;

    exec sql
      DELETE FROM replvars
       WHERE session_id = :sessionId;

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc clearSessionBuildVariables export;
  dcl-pi *n;
    sessionId char(28) const options(*nopass);
  end-pi;

end-proc;

//-----------------------------------------------------------------------

dcl-proc clearSessionPseudoResults export;
  dcl-pi *n;
    sessionId char(28) const options(*nopass);
  end-pi;

  if %parms < %parmnum(sessionId);

    exec sql
      DELETE FROM replrslt
       WHERE session_id = (QSYS2.JOB_NAME);

  else;

    exec sql
      DELETE FROM replrslt
       WHERE session_id = :sessionId;

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareFetchLinesOfPseudoCode export;
  dcl-pi *n;
    sourceFile likeds(t_referenceSource) const options(*nopass);
    startingLine like(t_lineOfCode.line) const options(*nopass);
  end-pi;

  dcl-s alreadyProcessed ind;
  dcl-s from like(t_lineOfCode.line);

  if %parms() >= %parmnum(sourceFile);

    monitor;
      runCommand('DLTOVR FILE(REPLREFSRC)');
    on-error;
    endmon;

    exec sql
      CLOSE replReference_linesofcode;

    if %parms() < %parmnum(startingLine);

      from = 0;

    else;

      from = startingLine;

    endif;

    runCommand('OVRDBF FILE(REPLREFSRC) TOFILE(&1/&2) MBR(&3)':
               sourceFile.library:
               sourceFile.file:
               sourceFile.member);

    exec sql
      DECLARE replReference_linesofcode CURSOR FOR
       SELECT srcseq * 100, substring(srcdta, 6, 71) AS code
         FROM replrefsrc
        WHERE srcseq * 100 > :from
        ORDER BY srcseq;

    exec sql
      OPEN replReference_linesofcode;

  else;

    exec sql
      DECLARE replPseudo_linesofcode CURSOR FOR
       SELECT line_number, code
         FROM replsrc AS withBlanks
        WHERE session_id = (QSYS2.JOB_NAME)
              AND line_number
                   <= (SELECT COALESCE(MAX(line_number), 0)
                         FROM replsrc AS nonBlanks
                        WHERE code <> '')
        ORDER BY line_number;

    exec sql
      CLOSE replPseudo_linesofcode;

    exec sql
      OPEN replPseudo_linesofcode;

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchLineOfPseudoCode export;
  dcl-pi *n ind;
    lineOfCode likeds(t_lineOfCode);
    replCode ind const;
  end-pi;

  if not replCode;

    lineOfCode.line = 0;
    exec sql
      FETCH NEXT FROM replReference_linesofcode
       INTO :lineOfCode;

  else;

    exec sql
      FETCH NEXT FROM replPseudo_linesofcode
       INTO :lineOfCode;

  endif;

  return (sqlstt = '00000');

end-proc;

//-----------------------------------------------------------------------

dcl-proc storeLineOfPseudoCode export;
  dcl-pi *n;
    lineOfCode likeds(t_lineOfCode) const;
  end-pi;

  exec sql
    INSERT INTO replsrc
      (owner, session_id, line_number, code, last_update)
    VALUES
      (SESSION_USER,
       (QSYS2.JOB_NAME),
       :lineOfCode.line,
       :lineOfCode.code,
       CURRENT TIMESTAMP);

end-proc;

//-----------------------------------------------------------------------

dcl-proc insertNewLineOfPseudoCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
  end-pi;

  dcl-ds lineOfCode likeds(t_lineOfCode);

  exec sql
    UPDATE replsrc
       SET line_number = line_number + 1
     WHERE session_id = (QSYS2.JOB_NAME)
           AND line_number >= :line + 1;

  lineOfCode.line = line + 1;
  storeLineOfPseudoCode(lineOfCode);

end-proc;

//-----------------------------------------------------------------------

dcl-proc splitLineOfPseudoCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
    column packed(3) const;
  end-pi;

  dcl-ds rightLineOfCode likeds(t_lineOfCode);
  dcl-s leftLineOfCode like(t_lineOfCode.code);

  // Grab the line we're splitting
  exec sql
    SELECT code
      INTO :rightLineOfCode.code
      FROM replsrc
     WHERE session_id = (QSYS2.JOB_NAME)
           AND line_number = :line;

  // Work out what we're leaving behind, and what we're taking
  if column > 1;
    leftLineOfCode = %subst(rightLineOfCode.code: 1: column - 1);
    rightLineOfCode.code = %subst(rightLineOfCode.code: column);
  endif;

  // Update the left hand side of the line we're leaving
  exec sql
    UPDATE replsrc
       SET code = :leftLineOfCode
     WHERE session_id = (QSYS2.JOB_NAME)
           AND line_number = :line;

  // Make room for our new line
  exec sql
    UPDATE replsrc
       SET line_number = line_number + 1
     WHERE session_id = (QSYS2.JOB_NAME)
           AND line_number >= :line + 1;

  // Insert our new line
  rightLineOfCode.line = line + 1;
  storeLineOfPseudoCode(rightLineOfCode);

end-proc;

//-----------------------------------------------------------------------

dcl-proc deleteLineOfPseudoCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    DELETE FROM replsrc
     WHERE session_id = (QSYS2.JOB_NAME)
           AND line_number = :line;

  exec sql
    UPDATE replsrc
       SET line_number = line_number - 1
     WHERE session_id = (QSYS2.JOB_NAME)
           AND line_number > :line;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareFetchResultForLineOfCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    DECLARE replSrc_resultForLine CURSOR FOR
     SELECT result_description, loop_count, result_number,
            (SELECT COALESCE(MAX(result_number), 0)
               FROM replrslt
              WHERE session_id = (QSYS2.JOB_NAME)
                    AND line_number = :line)
       FROM replrslt
      WHERE session_id = (QSYS2.JOB_NAME)
            AND line_number = :line
      ORDER BY result_number;

  exec sql
    CLOSE replSrc_resultForLine;

  exec sql
    OPEN replSrc_resultForLine;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchResultForLineOfCode export;
  dcl-pi *n ind;
    result like(t_result);
  end-pi;

  dcl-s loopCount packed(5);
  dcl-s resultNumber packed(5);
  dcl-s resultTotal packed(5);

  exec sql
    FETCH NEXT FROM replSrc_resultForLine
     INTO :result, :loopCount, :resultNumber, :resultTotal;

  if sqlstt = '00000'
  and result = 'Loop executed';
    result = %trim(result) + ' ' + %char(loopCount) + ' time';
    if loopCount > 1;
      result = %trim(result) + 's';
    endif;
  endif;

  if sqlstt = '00000'
  and resultTotal > 1;
    result = %trim(%char(resultNumber)) + ': ' + %trim(result);
  endif;

  return (sqlstt = '00000');

end-proc;

//-----------------------------------------------------------------------

dcl-proc removeUnusedSnippets export;
  dcl-pi *n end-pi;

  exec sql
    DELETE FROM replsrc
     WHERE session_id IS NOT NULL
           AND session_id NOT IN (
    SELECT DISTINCT session_id
      FROM replsrc
     WHERE code <> ''
           AND session_id IS NOT NULL);

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareFetchStoredSnippets export;
  dcl-pi *n;
    snippetsForUser char(10) const;
    savedSnippets ind const;
  end-pi;

  exec sql
    DECLARE storedSnippets CURSOR FOR
     SELECT COALESCE(owner, ''),
            COALESCE(session_id, ''),
            COALESCE(save_name, ''),
            MAX(COALESCE(last_update, '9999-12-31-24.00.00.000000'))
       FROM replsrc
      WHERE (:snippetsForUser = ''
             OR owner = :snippetsForUser)
        AND ((:savedSnippets = '1'
              AND save_name IS NOT NULL)
             OR (:savedSnippets = '0'
                 AND save_name IS NULL))
      GROUP BY owner, session_id, save_name
      ORDER BY MAX(COALESCE(last_update,
                 '9999-12-31-24.00.00.000000')) DESC
      FETCH FIRST 44 ROWS ONLY;

  exec sql
    CLOSE storedSnippets;

  exec sql
    OPEN storedSnippets;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchStoredSnippets export;
  dcl-pi *n ind;
    storedSnippet likeds(t_storedSnippet);
  end-pi;

  exec sql
    FETCH NEXT FROM storedSnippets
     INTO :storedSnippet.owner,
          :storedSnippet.sessionId,
          :storedSnippet.saveName,
          :storedSnippet.lastUpdate;

  if sqlstt <> '00000';
    return *off;
  endif;

  exec sql
    SELECT SUBSTRING(
             LISTAGG(
               TRIM(
                 code
               ),
               ' ') WITHIN GROUP (
                 ORDER BY line_number
             ),
             1, 100
           )
      INTO :storedSnippet.preview
      FROM replsrc
     WHERE (:storedSnippet.saveName <> ''
            AND COALESCE(save_name, '') = :storedSnippet.saveName)
        OR (:storedSnippet.saveName = ''
            AND COALESCE(session_id, '') = :storedSnippet.sessionId);

  return *on;

end-proc;

//-----------------------------------------------------------------------

dcl-proc storeSessionToSaveFile export;
  dcl-pi *n;
    saveFile char(20) const;
  end-pi;

  exec sql
    DELETE FROM replsrc
     WHERE owner = SESSION_USER
           AND save_name = :saveFile;

  exec sql
    INSERT INTO replsrc
      (line_number, code, save_name, last_update, owner)
    SELECT line_number, code, :saveFile, CURRENT TIMESTAMP, SESSION_USER
      FROM replsrc
     WHERE session_id = (QSYS2.JOB_NAME);

end-proc;

//-----------------------------------------------------------------------

dcl-proc restoreSaveFileToSession export;
  dcl-pi *n;
    owner char(10) const;
    saveFile char(20) const;
  end-pi;

  clearSessionPseudoCode();

  exec sql
    INSERT INTO replsrc
      (line_number, code, session_id, last_update, owner)
    SELECT line_number, code, (QSYS2.JOB_NAME),
           CURRENT TIMESTAMP, SESSION_USER
      FROM replsrc
     WHERE owner = :owner
           AND save_name = :saveFile;

end-proc;

//-----------------------------------------------------------------------

dcl-proc restoreSessionToSession export;
  dcl-pi *n;
    sessionId char(28) const;
  end-pi;

  dcl-s thisSessionId char(28);

  exec sql SET :thisSessionId = (QSYS2.JOB_NAME);

  if thisSessionId = sessionId;
    return;
  endif;

  clearSessionPseudoCode();

  exec sql
    INSERT INTO replsrc
      (line_number, code, session_id, last_update, owner)
    SELECT line_number, code, (QSYS2.JOB_NAME),
           CURRENT TIMESTAMP, SESSION_USER
      FROM replsrc
     WHERE session_id = :sessionId;

end-proc;

//-----------------------------------------------------------------------

dcl-proc saveFileExistsForOwner export;
  dcl-pi *n ind;
    owner char(10) const;
    saveFile char(20) const;
  end-pi;

  dcl-s found ind;

  exec sql
    SELECT 1 INTO :found
      FROM replsrc
     WHERE owner = :owner
           AND save_name = :saveFile
     FETCH FIRST ROW ONLY;

  return (sqlstt = '00000');

end-proc;

//-----------------------------------------------------------------------

dcl-proc deleteSaveFileForOwner export;
  dcl-pi *n;
    owner char(10) const;
    saveFile char(20) const;
  end-pi;

  exec sql
    DELETE FROM replsrc
     WHERE owner = :owner
           AND save_name = :saveFile;

end-proc;

//-----------------------------------------------------------------------

