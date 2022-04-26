**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked);

//-----------------------------------------------------------------------

dcl-f replloadfm workstn indds(dspinds) sfile(snippet: s2rrn);

//-----------------------------------------------------------------------

/include repl_pseu

//-----------------------------------------------------------------------

dcl-ds ps psds qualified;
  currentUser char(10) pos(358);
end-ds;

//-----------------------------------------------------------------------

dcl-ds dspinds qualified;

  exit ind pos(3);

  toggleSavedUnsavedSnippets ind pos(11);

  // for the confirmation window:

  confirm ind pos(10);
  cancel ind pos(12);

  displaySubfile ind pos(40);
  displaySubfileControl ind pos(41);
  clearSubfile ind pos(42);
  endOfSubfile ind pos(43);

  showingSavedSnippets ind pos(50);

  optionChoiceError ind pos(99);

end-ds;

dcl-s s2rrn packed(4);
dcl-s showSavedSnippets ind inz(*on);
dcl-s refreshScreen ind;

dcl-c c_select_snippet '1';
dcl-c c_delete_snippet '4';

//-----------------------------------------------------------------------

H_FILTER = ps.currentUser;
removeUnusedSnippets();
refreshScreen = *on;

dow not dspinds.exit;

  displaySnippets();
  processOptions();

enddo;

*inlr = *on;
return;

//-----------------------------------------------------------------------

dcl-proc displaySnippets;

  if refreshScreen;
    addSnippetsToScreen();
  endif;

  if showSavedSnippets;
    H_MODE = '  saved snippets';
  else;
    H_MODE = 'unsaved snippets';
  endif;

  dspinds.showingSavedSnippets = showSavedSnippets;
  write header;
  write fkeys;

  if not dspinds.displaySubfile;
    write norecords;
  endif;

  exfmt snippets;

  read header;

  msglin = *blanks;

end-proc;

//-----------------------------------------------------------------------

dcl-proc addSnippetsToScreen;

  dcl-ds storedSnippet likeds(t_storedSnippet);

  resetSnippetsScreen();

  prepareFetchStoredSnippets(
    H_FILTER:
    showSavedSnippets
  );

  dspinds.optionChoiceError = *off;

  dow fetchStoredSnippets(storedSnippet);

    S_SELECT = *blanks;

    if storedSnippet.saveName <> *blanks;
      S_ORIGIN =
        %trim(storedSnippet.owner)
         + ':'
         + %trim(storedSnippet.saveName);
    else;
      S_ORIGIN = storedSnippet.sessionId;
    endif;

    S_LASTCHG = %scanrpl(
      '.': '/': (%char(%date(storedSnippet.lastUpdate): *eur))
    );
    S_PREVIEW = %subst(storedSnippet.preview: 1: 85);
    S_OWNER = storedSnippet.owner;
    S_SAVENAME = storedSnippet.saveName;
    S_SESSION = storedSnippet.sessionId;

    s2rrn += 1;
    write snippet;

  enddo;

  dspinds.displaySubfile = (s2rrn > 0);

  if dspinds.displaySubfile;
    dspinds.endOfSubfile = *on;
  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc resetSnippetsScreen;

  dspinds.displaySubfile = *on;
  dspinds.displaySubfileControl = *on;

  dspinds.endOfSubfile = *off;
  dspinds.clearSubfile = *on;
  write snippets;
  dspinds.clearSubfile = *off;
  s2rrn = 0;

end-proc;

//-----------------------------------------------------------------------

dcl-proc processOptions;

  msglin = *blanks;
  dspinds.optionChoiceError = *off;

  select;

    when dspinds.exit;
      return;

    when dspinds.toggleSavedUnsavedSnippets;
      showSavedSnippets = not showSavedSnippets;
      dspinds.toggleSavedUnsavedSnippets = *off;
      refreshScreen = *on;
      return;

  endsl;

  if not dspinds.displaySubfile;
    refreshScreen = *on;
    return;
  endif;

  readc snippet;
  dow not %eof;

    dspinds.optionChoiceError = *off;

    if S_SELECT <> c_select_snippet
    and S_SELECT <> c_delete_snippet
    and S_SELECT <> *blanks;
      dspinds.optionChoiceError = *on;
      msglin = 'Unrecognised selection choice. Try again.';
      update snippet;
      refreshScreen = *off;
      return;
    endif;

    if S_SELECT = c_delete_snippet
    and S_OWNER <> ps.currentUser;
      dspinds.optionChoiceError = *on;
      msglin = 'You can only delete your own snippets.';
      update snippet;
      refreshScreen = *off;
      return;
    endif;

    if S_SELECT = c_select_snippet;
      CNFTXT1 = 'Load this snippet to your current session?';
      CNFTXT2 = 'This will delete your current snippet.';
      exfmt confirm;
      if dspinds.confirm;
        if S_SAVENAME <> *blanks;
          restoreSaveFileToSession(S_OWNER: S_SAVENAME);
        else;
          restoreSessionToSession(S_SESSION);
        endif;
        dspinds.exit = *on;
        dspinds.confirm = *off;
        S_SELECT = *blanks;
        update snippet;
        return;
      endif;
      dspinds.cancel = *off;
    endif;

    if S_SELECT = c_delete_snippet;
      CNFTXT1 = 'Delete snippet ' + %trim(S_ORIGIN) + '?';
      CNFTXT2 = 'This action is not reversible.';
      exfmt confirm;
      if dspinds.confirm;
        if S_SAVENAME <> *blanks;
          deleteSaveFileForOwner(S_OWNER: S_SAVENAME);
        else;
          clearSessionPseudoCode(c_control_statement: S_SESSION);
          clearSessionPseudoCode(c_mainline_code: S_SESSION);
        endif;
      endif;
      dspinds.cancel = *off;
      refreshScreen = *on;
    endif;

    S_SELECT = *blanks;
    update snippet;
    readc snippet;

  enddo;

end-proc;

//-----------------------------------------------------------------------

