**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) main(main);

//-----------------------------------------------------------------------

dcl-f replfm workstn indds(dspinds) sfile(codeline: s2rrn);

//-----------------------------------------------------------------------

/include repl_cmpl
/include repl_gen
/include repl_ins
/include repl_pm
/include repl_pseu
/include repl_usr

//-----------------------------------------------------------------------

dcl-pr loadSnippet extpgm('REPLLOAD') end-pr;

//-----------------------------------------------------------------------

dcl-ds dspinds qualified;
  expandResult ind pos(1);
  debugProgram ind pos(2);
  exit ind pos(3);

  showRuler ind pos(4);
  clearSheet ind pos(5);
  insertLine ind pos(6);
  showSpoolFiles ind pos(7);
  jobLog ind pos(8);

  commandLine ind pos(9);
  compile ind pos(10);
  compileAndRun ind pos(11);
  run ind pos(12);
  deleteLine ind pos(14);
  splitLine ind pos(15);
  changeControlStatement ind pos(16);
  showGeneratedSource ind pos(17);

  saveLoadSnippet ind pos(21);
  compileWithOptions ind pos(22);
  compileAndRunWithOptions ind pos(23);

  swapFunctionKeys ind pos(24);

  // for the confirmation window:

  confirm_confirm ind pos(10);
  confirm_cancel ind pos(12);

  // for the save/load window

  saveload_save ind pos(6);
  saveload_load ind pos(10);
  saveload_cancel ind pos(12);

  // for the save window

  save_confirm ind pos(10);
  save_cancel ind pos(12);
  save_saveFileAlreadyExists ind pos(99);

  // for the control statement window
  control_statement_reset_to_organisation_default ind pos(7);
  control_statement_reset_to_user_default ind pos(8);
  control_statement_save_only ind pos(10);
  control_statement_save_and_set_default ind pos(11);
  control_statement_cancel ind pos(12);

  validCodeLine ind pos(30);

  showFunctionKeySet1 ind pos(32);
  showFunctionKeySet2 ind pos(33);
  showFunctionKeySet3 ind pos(34);

  displaySubfile ind pos(40);
  displaySubfileControl ind pos(41);
  clearSubfile ind pos(42);
  endOfSubfile ind pos(43);

  isRulerLine ind pos(50);

  isTestProgram ind pos(51);
  isTestSuccess ind pos(52);
  isTestFailure ind pos(53);

end-ds;

dcl-s s2rrn packed(4);
dcl-s functionKeySet packed(1) inz(1);
dcl-c c_functionKeyPageCount 3;

dcl-ds t_exactCursorPosition qualified template;
  row packed(3);
  column packed(3);
  showingRow packed(5);
end-ds;

dcl-ds savedCursorPosition likeds(t_exactCursorPosition);

dcl-c c_setInitialRow 3;
dcl-c c_setInitialColumn 7;
dcl-c c_showFirstRow 1;

dcl-ds ps psds qualified;
  programLibrary char(10) pos(81);
  currentUser char(10) pos(358);
end-ds;

dcl-ds t_showRuler qualified template;
  beforeLine packed(5);
  spec char(71);
end-ds;

dcl-ds showRuler likeds(t_showRuler);

dcl-c c_h_spec
'HKeywords+++++++++++++++++++++++++++++++-
+++++++++++++++++++++++++++++++++++';
dcl-c c_f_spec
'FFilename++IPEASFRlen+LKlen+AIDevice+.Ke-
ywords+++++++++++++++++++++++++++++';
dcl-c c_d_spec
'DName+++++++++++ETDsFrom+++To/L+++IDc.Ke-
ywords+++++++++++++++++++++++++++++';
dcl-c c_i_spec
'IRcdname+++....Ri.......................-
...................................';
dcl-c c_c_spec
'CL0N01Factor1+++++++Opcode(E)+Factor2+++-
++++Result++++++++Len++D+HiLoEq....';
dcl-c c_o_spec
'O..............N01N02N03Field+++++++++.B-
...................................';
dcl-c c_p_spec
'PName+++++++++++..B...................Ke-
ywords+++++++++++++++++++++++++++++';

//-----------------------------------------------------------------------

dcl-proc main;
  dcl-s addedProductLibrary ind;

  callp(e) runCommand('ADDLIBLE &1' : ps.programLibrary);
  addedProductLibrary = not %error();

  savedCursorPosition = resetCursorPosition();
  showRuler = resetShowRuler();

  dow not dspinds.exit;

    displaySourceCode();
    saveSourceCode();
    processOption();

  enddo;

  dropSqlAlias();

on-exit;
  if addedProductLibrary;
    callp(e) runCommand('RMVLIBLE &1' : ps.programLibrary);
  endif;

  close replfm;
end-proc;

//-----------------------------------------------------------------------

dcl-proc resetCursorPosition;
  dcl-pi *n likeds(t_exactCursorPosition) end-pi;

  dcl-ds cursorPosition likeds(t_exactCursorPosition);

  cursorPosition.row = c_setInitialRow;
  cursorPosition.column = c_setInitialColumn;
  cursorPosition.showingRow = c_showFirstRow;

  return cursorPosition;

end-proc;

//-----------------------------------------------------------------------

dcl-proc resetShowRuler;
  dcl-pi *n likeds(t_showRuler) end-pi;

  dcl-ds showRuler likeds(t_showRuler);

  showRuler.beforeLine = 0;
  showRuler.spec = *blanks;

  return showRuler;

end-proc;

//-----------------------------------------------------------------------

dcl-proc setCursorPosition;
  dcl-pi *n;
    row packed(3);
    column packed(3);
    showingRow packed(5);
  end-pi;

  cp_setRow = %max(row: c_setInitialRow);
  // IBM bug:
  //  On a multi-page subfile where PAGEUP/PAGEDOWN are not specified,
  //  CP_SETCOL will only work on page 1.
  //  For a more consistent user experience,
  //  always put the cursor in the initial column.
  cp_setCol = c_setInitialColumn;
  cp_pos = %max(showingRow: c_showFirstRow);

end-proc;

//-----------------------------------------------------------------------

dcl-proc saveCursorPosition;
  dcl-pi *n likeds(t_exactCursorPosition) end-pi;

  dcl-ds cursorPosition likeds(t_exactCursorPosition);

  // If we're not on one of the lines of code, then
  // we put us onto it.
  if cp_recfmt <> 'CODELINE';
    cursorPosition.row = c_setInitialRow;
    cursorPosition.column = c_setInitialColumn;
    cursorPosition.showingRow = c_showFirstRow;
    return cursorPosition;
  endif;

  // Otherwise, leave us on the same row.
  // + 2 to go from the RRN to actual screen location.
  cursorPosition.row = %max(%rem(cp_rrn: 22) + 2: c_setInitialRow);
  cursorPosition.showingRow = %max(cp_rrn: c_showFirstRow);

  // If we were on a line of code, remember where we were.
  //   + 6 to go from the relative column to actual screen location
  // If we were on a result, remember where we were.
  //   + 78 to go from the relative column to actual screen location
  // Otherwise, back to the start.
  if cp_fld = 'CL_CODE';
    cursorPosition.column = %max(cp_column + 6: c_setInitialColumn);
  elseif cp_fld = 'CL_RESULT';
    cursorPosition.column = %max(cp_column + 78: c_setInitialColumn);
  else;
    cursorPosition.column = c_setInitialColumn;
  endif;

  return cursorPosition;

end-proc;

//-----------------------------------------------------------------------

dcl-proc setRulerPosition;
  dcl-pi *n likeds(t_showRuler);
    line like(t_showRuler.beforeLine) const;
    specification char(1) const;
  end-pi;

  showRuler.beforeLine = line;

  select;
    when specification = 'H';
      showRuler.spec = c_h_spec;

    when specification = 'F';
      showRuler.spec = c_f_spec;

    when specification = 'D';
      showRuler.spec = c_d_spec;

    when specification = 'I';
      showRuler.spec = c_i_spec;

    when specification = 'C';
      showRuler.spec = c_c_spec;

    when specification = 'O';
      showRuler.spec = c_o_spec;

    when specification = 'P';
      showRuler.spec = c_p_spec;

    other;
      showRuler = resetShowRuler();

  endsl;

  return showRuler;

end-proc;

//-----------------------------------------------------------------------

dcl-proc displaySourceCode;

  dcl-s justResettingTheScreen ind;

  resetCodePageScreen();

  addStoredCodeToCodePageScreen();

  write header;

  dou not justResettingTheScreen;

    dspinds.showFunctionKeySet1 = (functionKeySet = 1);
    dspinds.showFunctionKeySet2 = (functionKeySet = 2);
    dspinds.showFunctionKeySet3 = (functionKeySet = 3);

    write fkeys;

    setCursorPosition
      (savedCursorPosition.row:
       savedCursorPosition.column:
       savedCursorPosition.showingRow);

    exfmt codepage;

    msglin = *blanks;

    savedCursorPosition = saveCursorPosition();

    justResettingTheScreen = *on;

    select;

      // f1
      when dspinds.expandResult;
        showExpandedResult(cp_rrn);

      // f9
      when dspinds.commandLine;
        monitor;
          showCommandLine();
        on-error;
        endmon;

      // f24
      when dspinds.swapFunctionKeys;
        functionKeySet
          = %rem(functionKeySet: c_functionKeyPageCount) + 1;

      // any other key: too complex.
      other;
        justResettingTheScreen = *off;
        showRuler = resetShowRuler();

    endsl;

  enddo;

end-proc;

//-----------------------------------------------------------------------

dcl-proc showExpandedResult;
  dcl-pi *n;
    row packed(4) const;
  end-pi;

  if row < 1;
    return;
  endif;

  chain row codeline;

  if not %found();
    return;
  endif;

  fr_result = cl_fulrslt;

  exfmt fullresult;

end-proc;

//-----------------------------------------------------------------------

dcl-proc resetCodePageScreen;

  dspinds.displaySubfile = *on;
  dspinds.displaySubfileControl = *on;

  dspinds.clearSubfile = *on;
  write codepage;
  dspinds.clearSubfile = *off;

  dspinds.endOfSubfile = *off;

end-proc;

//-----------------------------------------------------------------------

dcl-proc addStoredCodeToCodePageScreen;

  dcl-ds lineOfCode likeds(t_lineofCode);
  dcl-s i like(t_lineOfCode.line);
  dcl-s currentCodeLineCount like(t_lineOfCode.line);
  dcl-s blankLineCount like(t_lineOfCode.line);
  dcl-ds result likeds(t_replResult);

  prepareFetchLinesOfPseudoCode();

  s2rrn = 0;
  currentCodeLineCount = 0;
  blankLineCount = 0;

  // Put all the stored code on screen
  dspinds.isTestProgram = *off;

  dow fetchLineOfPseudoCode(lineOfCode: *on);

    if not dspinds.isTestProgram;
      if (
        %len(%trim(lineOfCode.code)) >= 11
        and %lower(%subst(%trim(lineOfCode.code): 1: 11)) = 'replequals('
      );
        dspinds.isTestProgram = *on;
      endif;
    endif;

    currentCodeLineCount += 1;
    if currentCodeLineCount = showRuler.beforeLine
    and showRuler.spec <> *blanks;
      cl_lineNum = 'FMT';
      cl_code = showRuler.spec;
      cl_result = *blanks;
      dspinds.isRulerLine = *on;
      s2rrn += 1;
      write codeline;
    endif;

    cl_lineNum = %editc(%dec(%char(currentCodeLineCount):4:0): 'X');

    cl_code = lineOfCode.code;

    prepareFetchResultForLineOfCode(lineOfCode.line);
    if fetchResultForLineOfCode(result);
      cl_result = result.resultText;
      cl_fulrslt = result.resultText;
    else;
      cl_result = *blanks;
      cl_fulrslt = *blanks;
    endif;

    dspinds.validCodeLine = *on;
    dspinds.isRulerLine = *off;

    blankLineCount += 1;
    if cl_code <> *blanks;
      blankLineCount = 0;
    endif;

    dspinds.isTestSuccess = *off;
    dspinds.isTestFailure = *off;
    if result.resultType = 'TEST-SUCCESS';
      dspinds.isTestSuccess = *on;
    elseif result.resultType = 'TEST-FAILURE';
      dspinds.isTestFailure = *on;
    endif;

    s2rrn += 1;
    write codeline;

    dow fetchResultForLineOfCode(result);
      cl_lineNum = ' +';
      cl_code = *blanks;
      cl_result = result.resultText;
      cl_fulrslt = result.resultText;
      
      dspinds.isTestSuccess = *off;
      dspinds.isTestFailure = *off;
      if result.resultType = 'TEST-SUCCESS';
        dspinds.isTestSuccess = *on;
      elseif result.resultType = 'TEST-FAILURE';
        dspinds.isTestFailure = *on;
      endif;
      
      s2rrn += 1;
      write codeline;
    enddo;

  enddo;

  // Give the user another 50 lines to play with
  // subtracting any trailing blank lines they have already

  for i = blankLineCount to 50;

    currentCodeLineCount += 1;
    cl_lineNum = %editc(%dec(%char(currentCodeLineCount):4:0): 'X');
    cl_code = *blanks;
    cl_result = *blanks;
    cl_fulrslt = *blanks;

    dspinds.validCodeLine = *on;

    s2rrn += 1;
    write codeline;

  endfor;

end-proc;

//-----------------------------------------------------------------------

dcl-proc saveSourceCode;

  dcl-ds lineOfCode likeds(t_lineOfCode);
  dcl-s i like(t_lineOfCode.line);

  // we might not have explicitly set this, so save whatever the current 
  // default ctl-opt is to this particular session
  storeSessionControlStatement(fetchSessionControlStatement());

  clearSessionPseudoCode(c_mainline_code);
  lineOfCode.line = *zeros;

  i = 1;
  chain i codeline;

  dow %found();

    if cl_lineNum <> *blanks
    and %trim(cl_lineNum) <> '+'
    and %trim(cl_lineNum) <> 'FMT';

      lineOfCode.line = %dec(cl_lineNum: 6: 0);
      lineOfCode.code = cl_code;

      storeLineOfPseudoCode(c_mainline_code: lineOfCode);

    endif;

    i += 1;
    chain i codeline;

  enddo;


end-proc;

//-----------------------------------------------------------------------

dcl-proc processOption;

  dcl-ds caughtError likeds(t_caughtError);

  msglin = *blanks;

  select;

    // f2
    when dspinds.debugProgram;
      monitor;
        debugGeneratedSourceObject();
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    // f3
    when dspinds.exit;
      return;

    // f4
    when dspinds.showRuler;
      if cp_rrn = 0;
        return;
      endif;
      chain cp_rrn codeline;
      if cl_linenum = 'FMT' or cl_lineNum = ' +';
        return;
      endif;
      pr_ruler = *blanks;
      exfmt pickRuler;
      showRuler = setRulerPosition(%dec(cl_lineNum: 4: 0): pr_ruler);

    // f5
    when dspinds.clearSheet;
      dspinds.confirm_confirm = *off;
      dspinds.confirm_cancel = *off;
      cnftxt1 =
        'Are you sure you want to clear the current';
      cnftxt2 =
        'snippet? This action cannot be undone.';
      exfmt confirm;
      if dspinds.confirm_confirm;
        clearSessionPseudoCode(c_mainline_code);
        savedCursorPosition = resetCursorPosition();
      endif;
      dspinds.confirm_confirm = *off;
      dspinds.confirm_cancel = *off;

    // f6
    when dspinds.insertLine;
      if cp_rrn = 0;
        return;
      endif;
      chain cp_rrn codeline;
      dow cl_lineNum = ' +' and cp_rrn > 0;
        cp_rrn -= 1;
        chain cp_rrn codeline;
      enddo;
      insertNewLineOfPseudoCode(%dec(cl_lineNum: 4: 0));
      // Position the user to the row they just made.
      savedCursorPosition.row += 1;
      savedCursorPosition.showingRow += 1;

      // f7
    when dspinds.showSpoolFiles;
      monitor;
        showUserSpoolFiles();
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    // f8
    when dspinds.jobLog;
      monitor;
        showJobLog();
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    // f10 / f22
    when dspinds.compile
    or dspinds.compileWithOptions;
      createGeneratedSourceObject();
      monitor;
        compileGeneratedSourceObject(dspinds.compileWithOptions);
        msglin = 'Program created successfully';
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    // f11 / f23
    when dspinds.compileAndRun
    or dspinds.compileAndRunWithOptions;
      createGeneratedSourceObject();
      monitor;
        compileGeneratedSourceObject(dspinds.compileAndRunWithOptions);
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
        return;
      endmon;
      msglin = 'Running program REPL_PGM . . .';
      write fkeys;
      monitor;
        runGeneratedProgramObject();
        msglin = 'Program ran successfully';
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    // f12
    when dspinds.run;
      msglin = 'Running program REPL_PGM . . .';
      write fkeys;
      monitor;
        runGeneratedProgramObject();
        msglin = 'Program ran successfully';
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    // f14
    when dspinds.deleteLine;
      if cp_rrn = 0;
        return;
      endif;
      chain cp_rrn codeline;
      dow cl_lineNum = ' +' and cp_rrn > 0;
        cp_rrn -= 1;
        chain cp_rrn codeline;
      enddo;
      deleteLineOfPseudoCode(%dec(cl_lineNum: 4: 0));

    // f15
    when dspinds.splitLine;
      if cp_rrn = 0;
        return;
      endif;
      chain cp_rrn codeline;
      dow cl_lineNum = ' +' and cp_rrn > 0;
        cp_rrn -= 1;
        chain cp_rrn codeline;
      enddo;
      // our cursor position is literally how far along the screen we are
      //  so substract six to get "how far along the snippet".
      // We want a position of at least 1, and at most 71.
      splitLineOfPseudoCode
        (%dec(cl_lineNum: 4: 0):
         %max
           (%min
              (71: savedCursorPosition.column - 6)
           : 1));
      // Position the user to the row they just made.
      savedCursorPosition.row += 1;
      savedCursorPosition.showingRow += 1;

    // f16
    when dspinds.changeControlStatement;
      editControlStatement();

    // f17
    when dspinds.showGeneratedSource;
      monitor;
        showGeneratedSourceObject();
      on-error;
        caughtError = catch();
        setErrorMessage(caughtError);
      endmon;

    //f21
    when dspinds.saveLoadSnippet;
      saveOrLoadSnippet();

  endsl;

end-proc;

//-----------------------------------------------------------------------

dcl-proc saveOrLoadSnippet;

  dspinds.saveload_save = *off;
  dspinds.saveload_load = *off;
  dspinds.saveload_cancel = *off;

  exfmt saveLoad;

  select;
    when dspinds.saveload_cancel;
      dspinds.saveload_cancel = *off;
      return;

    when dspinds.saveload_save;
      saveSnippet();
      dspinds.saveload_save = *off;

    when dspinds.saveload_load;
      loadSnippet();
      dspinds.saveload_load = *off;

  endsl;

on-exit;

  dspinds.saveload_save = *off;
  dspinds.saveload_load = *off;
  dspinds.saveload_cancel = *off;

end-proc;

//-----------------------------------------------------------------------

dcl-proc saveSnippet;

  dspinds.save_confirm = *off;
  dspinds.save_cancel = *off;
  dspinds.save_saveFileAlreadyExists = *off;
  s_savename = *blanks;

  dow not dspinds.save_cancel;

    exfmt save;

    if dspinds.save_cancel;
      iter;
    endif;

    // no name? no saves.
    if s_savename = *blanks;
      iter;
    endif;

    // they don't have one? save it
    if not saveFileExistsForOwner(ps.currentUser: s_saveName);
      storeSessionToSaveFile(s_savename);
      dspinds.save_cancel = *on;
      iter;
    endif;

    // they already have one, and we haven't told them
    //  about it? tell them
    if saveFileExistsForOwner(ps.currentUser: s_savename)
    and not dspinds.save_saveFileAlreadyExists;
      dspinds.save_saveFileAlreadyExists = *on;
      iter;
    endif;

    // they already have one, we've told them, and they're
    //  ok with it? save it
    if saveFileExistsForOwner(ps.currentUser: s_saveName)
    and dspinds.save_saveFileAlreadyExists
    and dspinds.save_confirm;
      storeSessionToSaveFile(s_savename);
      dspinds.save_cancel = *on;
      iter;
    endif;

  enddo;

on-exit;

  dspinds.save_confirm = *off;
  dspinds.save_cancel = *off;
  dspinds.save_saveFileAlreadyExists = *off;

end-proc;

//-----------------------------------------------------------------------

dcl-proc setDisplayControlStatement;
  dcl-pi *n;
    controlStatement likeds(t_controlStatement) const;
  end-pi;

  S_CONTROL1 = controlStatement.statement(1);
  S_CONTROL2 = controlStatement.statement(2);
  S_CONTROL3 = controlStatement.statement(3);

end-proc;

//-----------------------------------------------------------------------

dcl-proc getDisplayControlStatement;
  dcl-pi *n likeds(t_controlStatement) end-pi;

  dcl-ds controlStatement likeds(t_controlStatement);

  controlStatement.statement(1) = S_CONTROL1;
  controlStatement.statement(2) = S_CONTROL2;
  controlStatement.statement(3) = S_CONTROL3;

  return controlStatement;

end-proc;

//-----------------------------------------------------------------------

dcl-proc editControlStatement;

  setDisplayControlStatement(fetchSessionControlStatement());
  
  dow not dspinds.control_statement_save_and_set_default 
  and not dspinds.control_statement_save_only
  and not dspinds.control_statement_cancel;

    if dspinds.control_statement_reset_to_organisation_default;
      setDisplayControlStatement(fetchOrganisationControlStatementDefault());
      dspinds.control_statement_reset_to_organisation_default = *off;
    endif;

    if dspinds.control_statement_reset_to_user_default;
      setDisplayControlStatement(fetchUserControlStatementDefault());
      dspinds.control_statement_reset_to_user_default = *off;
    endif;

    exfmt control;

    if dspinds.control_statement_save_only;
      storeSessionControlStatement(getDisplayControlStatement());
    endif; 

    if dspinds.control_statement_save_and_set_default;
      storeSessionControlStatement(getDisplayControlStatement());
      storeUserControlStatementDefault(getDisplayControlStatement());
    endif; 

  enddo;

  dspinds.control_statement_save_only = *off;
  dspinds.control_statement_save_and_set_default = *off;
  dspinds.control_statement_cancel = *off;  

end-proc;

//-----------------------------------------------------------------------

dcl-proc setErrorMessage;
  dcl-pi *n;
    caughtError likeds(t_caughtError) const;
  end-pi;

  select;
    when caughtError.errorCode = c_error_module_not_created;
      msglin = 'Module not created. F7 to check spool files, '
              + 'F17 to view generated source';

    when caughtError.errorCode = c_error_program_not_created;
      msglin = 'Program not created. F7 to check spool files, '
              + 'F17 to view generated source';

    when caughtError.errorCode = c_program_exception;
      msglin = 'Program not ran. F8 to check job log';

    when caughtError.errorCode = c_error_showing_generated_source;
      msglin = 'Error showing generated source. F8 to check job log';

    when caughtError.errorCode = c_problem_starting_debug;
      msglin = 'Error starting debug mode. F8 to check job log';

    when caughtError.errorCode = c_problem_showing_spool_files;
      msglin = 'Error displaying spool files. F8 to check job log';

    when caughtError.errorCode = c_problem_showing_job_log;
      msglin = 'Error display command line. F8 to check job log';

  endsl;

end-proc;

//-----------------------------------------------------------------------
