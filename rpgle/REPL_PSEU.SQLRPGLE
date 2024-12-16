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
    sourceType like(t_sourceType) const;
    sessionId char(28) const options(*nopass);
  end-pi;

  if %parms < %parmnum(sessionId);

    exec sql
      DELETE FROM replsrc
       WHERE session_id = (QSYS2.JOB_NAME)
       AND source_type = :sourceType;

    clearSessionPseudoVariables();

    clearSessionPseudoResults();

  else;

    exec sql
      DELETE FROM replsrc
       WHERE session_id = :sessionId
       AND source_type = :sourceType;

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
    iSourceLocation likeds(t_sourceLocation) const options(*nopass);
    startingLine like(t_lineOfCode.line) const options(*nopass);
  end-pi;

  dcl-s alreadyProcessed ind;
  dcl-s from like(t_lineOfCode.line);
  dcl-ds sourceLocation likeds(t_sourceLocation);

  if %parms() >= %parmnum(iSourceLocation);
    eval-corr sourceLocation = iSourceLocation;  
  endif;

  if sourceLocation.library = *blanks;
    sourceLocation.library = '*LIBL';
  endif;
  if sourceLocation.file = *blanks;
    sourceLocation.file = 'REPLSRC';
  endif;
  if sourceLocation.member = *blanks;
    sourceLocation.member = 'REPLSRC';
  endif;

  // if we've specified somewhere other than the default location
  if (
    %passed(iSourceLocation)
    and not (
      %upper(sourceLocation.library) = '*LIBL'
      and %upper(sourceLocation.file) = 'REPLSRC'
      and %upper(sourceLocation.member) = 'REPLSRC'  
  )) or (
    %passed(iSourceLocation) 
    and sourceLocation.isUserDirected = *on
    and sourceLocation.snippetName = *blanks  
  );

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
               sourceLocation.library:
               sourceLocation.file:
               sourceLocation.member);

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
        WHERE ((:sourceLocation.snippetName = '' 
                AND session_id = (QSYS2.JOB_NAME)
               ) 
               OR (:sourceLocation.snippetName <> '' 
                   AND save_name = :sourceLocation.snippetName
               )
              )
              AND source_type = :c_mainline_code
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
    iSourceLocation likeds(t_sourceLocation) const options(*nopass);
  end-pi;

  if not replCode 
  or (
    %passed(iSourceLocation) 
    and iSourceLocation.isUserDirected
    and iSourceLocation.snippetName = *blanks
  );

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
    sourceType like(t_sourceType) const;
    lineOfCode likeds(t_lineOfCode) const;
  end-pi;

  exec sql
    INSERT INTO replsrc
      (owner, session_id, source_type, line_number, code, last_update)
    VALUES
      (SESSION_USER,
       (QSYS2.JOB_NAME),
       :sourceType,
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
           AND source_type = :c_mainline_code
           AND line_number >= :line + 1;

  lineOfCode.line = line + 1;
  storeLineOfPseudoCode(c_mainline_code: lineOfCode);

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
           AND source_type = :c_mainline_code
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
           AND source_type = :c_mainline_code
           AND line_number = :line;

  // Make room for our new line
  exec sql
    UPDATE replsrc
       SET line_number = line_number + 1
     WHERE session_id = (QSYS2.JOB_NAME)
           AND source_type = :c_mainline_code
           AND line_number >= :line + 1;

  // Insert our new line
  rightLineOfCode.line = line + 1;
  storeLineOfPseudoCode(c_mainline_code: rightLineOfCode);

end-proc;

//-----------------------------------------------------------------------

dcl-proc deleteLineOfPseudoCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    DELETE FROM replsrc
     WHERE session_id = (QSYS2.JOB_NAME)
           AND source_type = :c_mainline_code
           AND line_number = :line;

  exec sql
    UPDATE replsrc
       SET line_number = line_number - 1
     WHERE session_id = (QSYS2.JOB_NAME)
           AND source_type = :c_mainline_code
           AND line_number > :line;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareFetchResultForLineOfCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    DECLARE replSrc_resultForLine CURSOR FOR
     SELECT result_description, 
            line_number,
            loop_count, 
            result_number,
            (SELECT COALESCE(MAX(result_number), 0)
               FROM replrslt
              WHERE session_id = (QSYS2.JOB_NAME)
                    AND line_number = :line),
            result_type
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

dcl-proc prepareFetchResultForAllCode export;
  dcl-pi *n;
    externalSessionId varchar(28) const;
  end-pi;

  exec sql
    DECLARE replSrc_resultForAllLines CURSOR FOR
     SELECT result_description, 
            line_number,
            loop_count, 
            result_number,
            (SELECT COALESCE(MAX(result_number), 0)
               FROM replrslt
              WHERE external_session_id = :externalSessionId
            ),
            result_type
       FROM replrslt
      WHERE external_session_id = :externalSessionId
      ORDER BY line_number, result_number;

  exec sql
    CLOSE replSrc_resultForAllLines;

  exec sql
    OPEN replSrc_resultForAllLines;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchResultForLineOfCode export;
  dcl-pi *n ind;
    result likeds(t_replResult);
  end-pi;

  dcl-s loopCount packed(5);
  dcl-s resultNumber packed(5);
  dcl-s resultTotal packed(5);

  result.resultText = '';

  exec sql
    FETCH NEXT FROM replSrc_resultForLine
     INTO :result.resultText, 
          :result.lineNumber,
          :loopCount, 
          :resultNumber, 
          :resultTotal,
          :result.resultType;

  if sqlstt = '00000'
  and result.resultText = 'Loop executed';
    result.resultText 
      = %trim(result.resultText) + ' ' + %char(loopCount) + ' time';
    if loopCount > 1;
      result.resultText = %trim(result.resultText) + 's';
    endif;
  endif;

  if sqlstt = '00000'
  and resultTotal > 1;
    result.resultText 
      = %trim(%char(resultNumber)) + ': ' + %trim(result.resultText);
  endif;

  return (sqlstt = '00000');

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchResultForAllLinesOfCode export;
  dcl-pi *n ind;
    result likeds(t_replResult);
  end-pi;

  dcl-s loopCount packed(5);
  dcl-s resultNumber packed(5);
  dcl-s resultTotal packed(5);

  result.resultText = '';

  exec sql
    FETCH NEXT FROM replSrc_resultForAllLines
     INTO :result.resultText, 
          :result.lineNumber,
          :loopCount, 
          :resultNumber, 
          :resultTotal,
          :result.resultType;

  if sqlstt = '00000'
  and result.resultText = 'Loop executed';
    result.resultText 
      = %trim(result.resultText) + ' ' + %char(loopCount) + ' time';
    if loopCount > 1;
      result.resultText = %trim(result.resultText) + 's';
    endif;
  endif;

  if sqlstt = '00000'
  and resultTotal > 1;
    result.resultText 
      = %trim(%char(resultNumber)) + ': ' + %trim(result.resultText);
  endif;

  return (sqlstt = '00000');

end-proc;

//-----------------------------------------------------------------------

dcl-proc removeUnusedSnippets export;
  dcl-pi *n end-pi;

  // if the control options are non-blank,
  // but there is no mainline code
  // then we want to delete the control and mainline source

  exec sql
    DELETE FROM replsrc
     WHERE session_id IS NOT NULL
           AND session_id NOT IN (
    SELECT DISTINCT session_id
      FROM replsrc
     WHERE code <> ''
           AND source_type = :c_mainline_code
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
        AND source_type = :c_mainline_code
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
      WHERE ((:storedSnippet.saveName <> ''
                AND COALESCE(save_name, '') = :storedSnippet.saveName)
             OR (:storedSnippet.saveName = ''
                AND COALESCE(session_id, '') = :storedSnippet.sessionId))
            AND source_type = :c_mainline_code;

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
      (source_type, line_number, code, save_name, last_update, owner)
    SELECT source_type, line_number, code, :saveFile, 
           CURRENT TIMESTAMP, SESSION_USER
      FROM replsrc
     WHERE session_id = (QSYS2.JOB_NAME);

end-proc;

//-----------------------------------------------------------------------

dcl-proc restoreSaveFileToSession export;
  dcl-pi *n;
    owner char(10) const;
    saveFile char(20) const;
  end-pi;

  clearSessionPseudoCode(c_control_statement);
  clearSessionPseudoCode(c_mainline_code);

  exec sql
    INSERT INTO replsrc
      (source_type, line_number, code, session_id, last_update, owner)
    SELECT source_type, line_number, code, (QSYS2.JOB_NAME),
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

  clearSessionPseudoCode(c_control_statement);
  clearSessionPseudoCode(c_mainline_code);

  exec sql
    INSERT INTO replsrc
      (source_type, line_number, code, session_id, last_update, owner)
    SELECT source_type, line_number, code, (QSYS2.JOB_NAME),
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

dcl-proc fetchOrganisationControlStatementDefault export;
  dcl-pi *n likeds(t_controlStatement) end-pi;

  dcl-ds controlStatement likeds(t_controlStatement);
  dcl-s statement like(t_controlStatement.statement);
  dcl-s resultCount packed(1);

  exec sql 
    DECLARE organisationControlStatement CURSOR FOR
      SELECT code
      FROM replsrc
      WHERE session_id IS NULL
            AND save_name IS NULL
            AND owner IS NULL
            AND source_type = :c_control_statement
      ORDER BY line_number;
  exec sql
    OPEN organisationControlStatement;
  exec sql
    FETCH organisationControlStatement INTO :statement;

  resultCount = 0;

  dow resultCount < 3 and sqlstt = '00000';
    resultCount += 1;
    controlStatement.statement(resultCount) = statement;
    exec sql
      FETCH organisationControlStatement INTO :statement;
  enddo;

  if resultCount = 0;
    reset controlStatement;
    controlStatement.statement(1) = 'ctl-opt;';
  endif;

  return controlStatement;

on-exit;
  exec sql
    CLOSE organisationControlStatement;
end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchUserControlStatementDefault export;
  dcl-pi *n likeds(t_controlStatement) end-pi;

  dcl-ds controlStatement likeds(t_controlStatement);
  dcl-s statement like(t_controlStatement.statement);
  dcl-s resultCount packed(1);

  exec sql 
    DECLARE userControlStatement CURSOR FOR
      SELECT code
      FROM replsrc
      WHERE session_id IS NULL
            AND save_name IS NULL
            AND owner = SESSION_USER
            AND source_type = :c_control_statement
      ORDER BY line_number    ;
  exec sql
    OPEN userControlStatement;
  exec sql
    FETCH userControlStatement INTO :statement;

  resultCount = 0;

  dow resultCount < 3 and sqlstt = '00000';
    resultCount += 1;
    controlStatement.statement(resultCount) = statement;
    exec sql
      FETCH userControlStatement INTO :statement;
  enddo;

  if resultCount = 0;
    controlStatement = fetchOrganisationControlStatementDefault();
  endif;

  return controlStatement;

on-exit;
  exec sql
    CLOSE userControlStatement;
end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchSessionControlStatement export;
  dcl-pi *n likeds(t_controlStatement) end-pi;

  dcl-ds controlStatement likeds(t_controlStatement);
  dcl-s statement like(t_controlStatement.statement);
  dcl-s resultCount packed(1);

  exec sql 
    DECLARE sessionControlStatement CURSOR FOR
      SELECT code
      FROM replsrc
      WHERE session_id = (QSYS2.JOB_NAME)
            AND source_type = :c_control_statement
      ORDER BY line_number;
  exec sql
    OPEN sessionControlStatement;
  exec sql
    FETCH sessionControlStatement INTO :statement;

  resultCount = 0;

  dow resultCount < 3 and sqlstt = '00000';
    resultCount += 1;
    controlStatement.statement(resultCount) = statement;
    exec sql
      FETCH sessionControlStatement INTO :statement;
  enddo;

  if resultCount = 0;
    controlStatement = fetchUserControlStatementDefault();
  endif;

  return controlStatement;

on-exit;
  exec sql
    CLOSE sessionControlStatement;
end-proc;

//-----------------------------------------------------------------------

dcl-proc storeUserControlStatementDefault export;
  dcl-pi *n;
    controlStatement likeds(t_controlStatement) const;
  end-pi;
  
  dcl-ds lineOfCode likeds(t_lineOfCode);
  dcl-s i like(t_lineOfCode.line);

  exec sql
    DELETE FROM replsrc
     WHERE source_type = :c_control_statement
           AND owner = SESSION_USER
           AND session_id IS NULL
           AND save_name IS NULL;

  lineOfCode.line = *zeros;

  for i = 1 to c_control_statements;

    lineOfCode.line = i;
    lineOfCode.code = controlStatement.statement(i);

    exec sql
      INSERT INTO replsrc
        (owner, source_type, line_number, code, last_update)
      VALUES
        (SESSION_USER,
         :c_control_statement,
         :lineOfCode.line,
         :lineOfCode.code,
         CURRENT TIMESTAMP);

  endfor;
  
end-proc;

//-----------------------------------------------------------------------

dcl-proc storeSessionControlStatement export;
  dcl-pi *n;
    controlStatement likeds(t_controlStatement) const;
  end-pi;
  
  dcl-ds lineOfCode likeds(t_lineOfCode);
  dcl-s i like(t_lineOfCode.line);

  clearSessionPseudoCode(c_control_statement);
  lineOfCode.line = *zeros;

  for i = 1 to c_control_statements;

    lineOfCode.line = i;
    lineOfCode.code = controlStatement.statement(i);

    storeLineOfPseudoCode(c_control_statement: lineOfCode);

  endfor;

end-proc;

//-----------------------------------------------------------------------

dcl-proc stripComments export;
  dcl-pi *n likeds(t_lineOfCode);
    lineOfCode likeds(t_lineOfCode) value;
    execSql ind const;
  end-pi;

  dcl-s code like(t_lineOfCode.code);
  dcl-s openSlashStar ind static;

  // if we were already a comment, and have no means of closing it, then just
  // blank out and skip doing anything else.
  if openSlashStar and @scan('*/': lineOfCode.code) = 0;
    lineOfCode.code = *blanks;
    return lineOfCode;
  endif;

  // we could (terrifyingly) have multiple comments on a single line,
  // so handle that

  dou %len(%trim(code)) = %len(%trim(lineOfCode.code));

    code = lineOfCode.code;

    // pretty standard comments - could have e.g.
    // dcl-s i packed(2); // [used for indexing]

    if @scan('//': lineOfCode.code) > 0;
      lineOfCode.code = %subst(lineOfCode.code: 1: @scan('//': lineOfCode.code) - 1);
    endif;

    // it's an older code but it checks out
    // dcl-s i /* i for index, dummy */ packed(2);
    // /* we love to do 
    //    some indexing! */

    // if we were already a comment, and are closing it, then strip out
    // the comment bit
    if openSlashStar and @scan('*/': lineOfCode.code) > 0;
      openSlashStar = *off;
      lineOfCode.code = %subst(lineOfCode.code: @scan('*/': lineOfCode.code) + 2);
    endif;

    if @scan('/*': lineOfCode.code) > 0;
      openSlashStar = *on;

      select;
        // we have a /* line */ with a self-contained comment
        when @scan('*/': lineOfCode.code) > @scan('/*': lineOfCode.code);
          openSlashStar = *off;
          lineOfCode.code = 
            %subst(lineOfCode.code: 1: @scan('/*': lineOfCode.code) - 1)
            + %subst(lineOfCode.code: @scan('*/': lineOfCode.code) + 2);

        // we were already a comment */ and /* will be again
        when @scan('/*': lineOfCode.code) > @scan('*/': lineOfCode.code)
        and @scan('*/': lineOfCode.code) > 0;
          lineOfCode.code = 
            %subst(lineOfCode.code: @scan('*/': lineOfCode.code) + 2)
            + %subst(lineOfCode.code: 1: @scan('/*': lineOfCode.code) - 1);

        // we only started a comment /*
        other;
          lineOfCode.code = %subst(lineOfCode.code: 1: @scan('/*': lineOfCode.code) - 1);

      endsl;

    endif;

    // sql, naturally, can have it's own comment style.
    // exec sql 
    //   SELECT name -- this is the name
    if execSql and @scan('--': lineOfCode.code) > 0;
      lineOfCode.code = %subst(lineOfCode.code: 1: @scan('--': lineOfCode.code) - 1);
    endif;

  enddo;

  return lineOfCode;

end-proc;

//-----------------------------------------------------------------------

// An interpretation of %scan() which ignores anything that looks like
// a string literal, focusing only on the other things.

dcl-proc @scan export;
  dcl-pi *n packed(5);
    searchArgument varchar(65535) const;
    sourceString varchar(65535) value;
    startPosition packed(5) const options(*omit: *nopass);
    length packed(5) const options(*omit: *nopass);
  end-pi;

  dcl-s searchFrom packed(5);
  dcl-s searchFor packed(5);
  dcl-s character packed(5);
  dcl-s isStringLiteral ind;

  searchFrom = 1;
  searchFor = %len(sourceString);

  if %parms() >= %parmnum(startPosition) and %addr(startPosition) <> *null;
    searchFrom = startPosition;
  endif;

  if %parms() >= %parmnum(length) and %addr(length) <> *null
  and %len(sourceString) > length;
    searchFor = length;
  endif;

  // %scan('D': 'Dr. Doolittle': 2: 3)
  // for character = 1 to (3 + 2 - 1)
  // for character = 1 to 4
  // e.g. look for 'D' in 'Dr. D'
  // but we have an extra check saying that if we found it earlier, don't use it
  // we have to read from the start to ensure we're catching any relevant 
  // string literal markers

  for character = 1 to (searchFor + searchFrom - %len(searchArgument));

    if %subst(sourceString: character: 1) = '''';
      isStringLiteral = not isStringLiteral;
    endif;

    if isStringLiteral;
      iter;
    endif;

    if character < searchFrom;
      iter;
    endif;

    if %subst(sourceString: character: %len(searchArgument)) = searchArgument;
      return character;
    endif;

  endfor;

  return 0;

end-proc;

//-----------------------------------------------------------------------
