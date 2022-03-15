**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

//-----------------------------------------------------------------------

/include repl_pm
/include repl_pseu
/include repl_usr

/include repl_cmpl

//-----------------------------------------------------------------------

dcl-proc compileGeneratedSourceObject export;
  dcl-pi *n;
    showModuleInstructions ind const;
    piBatchMode ind const options(*omit: *nopass);
    piUserServicePrograms
      likeds(t_serviceProgram) dim(10) const options(*omit: *nopass);
  end-pi;

  dcl-s promptIt char(1);
  dcl-ds serviceProgram likeds(t_serviceProgram);
  dcl-s boundServicePrograms varchar(1000);
  dcl-s batchMode ind;
  dcl-ds userServicePrograms likeds(t_serviceProgram) dim(10);
  dcl-s i packed(2);
  dcl-ds thrownError likeds(t_thrownError);

  if %parms >= %parmnum(piBatchMode) and %addr(piBatchMode) <> *null;
    batchMode = piBatchMode;
  else;
    batchMode = *off;
  endif;

  if %parms >= %parmnum(piUserServicePrograms)
  and %addr(piUserServicePrograms) <> *null;
    userServicePrograms = piUserServicePrograms;
  endif;

  if showModuleInstructions and not batchMode;
    promptIt = '?';
  endif;

  monitor;
    runCommand(promptIt +
               'CRTSQLRPGI OBJ(&1/&2) SRCFILE(&1/&3) SRCMBR(&4) ' +
               'OBJTYPE(*MODULE) DBGVIEW(*SOURCE) DATFMT(*ISO) ' +
               'RPGPPOPT(*LVL2) COMMIT(*NONE)':
                 c_generatedSourceLibrary:
                 c_generatedModule:
                 c_generatedSourceFile:
                 c_generatedSourceMember);
  on-error;
    thrownError.errorCode = c_error_module_not_created;
    throw(thrownError);
  endmon;

  boundServicePrograms = '*LIBL/REPL_HLPR';

  prepareUserBoundServicePrograms();
  dow userBoundServiceProgram(serviceProgram: promptIt: batchMode);

    if serviceProgram.name = *blanks;
      iter;
    endif;

    // If the user provided this, use whatever they provided.
    i = %lookup(serviceProgram.name: userServicePrograms(*).name);
    if i <> 0;
      iter;
    endif;

    boundServicePrograms
      = %trim(boundServicePrograms)
         + ') ('
         + %trim(serviceProgram.library)
         + '/'
         + %trim(serviceProgram.name);

  enddo;

  for i = 1 to 10;
    // Don't do anything with a blank name.
    // These might be off sequence because of what
    //  happened above.
    if userServicePrograms(i).name = *blanks;
      iter;
    endif;

    boundServicePrograms
      = %trim(boundServicePrograms)
         + ') ('
         + %trim(userServicePrograms(i).library)
         + '/'
         + %trim(userServicePrograms(i).name);
  endfor;

  if batchMode;
    promptIt = *blanks;
  endif;

  monitor;
    runCommand(promptIt +
               'CRTPGM PGM(&1/&2) MODULE(&1/&3) BNDSRVPGM(('
                 + %trim(boundServicePrograms) + '))':
                 c_generatedSourceLibrary:
                 c_generatedProgram:
                 c_generatedModule);
    // Success? Then leave!
    return;
  on-error;
    thrownError.errorCode = c_error_program_not_created;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareUserBoundServicePrograms export;

  exec sql
    DECLARE repl_userServicePrograms CURSOR FOR
     SELECT UPPER(code) FROM replsrc
      WHERE session_id = (QSYS2.JOB_NAME)
            AND (UPPER(TRIM(code)) LIKE '/INCLUDE%'
                 OR UPPER(TRIM(code)) LIKE '/COPY%');

  exec sql
    CLOSE repl_userServicePrograms;

  exec sql
    OPEN repl_userServicePrograms;

end-proc;

//-----------------------------------------------------------------------

dcl-proc userBoundServiceProgram export;
  dcl-pi *n ind;
    serviceProgram likeds(t_serviceProgram);
    promptNeeded char(1);
    batchMode ind const;
  end-pi;

  dcl-s code like(t_lineOfCode.code);

  exec sql
    FETCH NEXT FROM repl_userServicePrograms INTO :code;

  if sqlstt <> '00000';
    return *off;
  endif;

  // take out the /include or /copy part
  code = %trim(%scanrpl('/INCLUDE': ' ': code));
  code = %trim(%scanrpl('/COPY': ' ': code));

  // if there isn't a slash,
  // or it's after the rpgleref,file#name,
  // then there isn't a library specified
  if %scan('/': code) = 0
  or (%scan('/': code) > %scan(',': code));
    serviceProgram.library = '*LIBL';
  else;
    serviceProgram.library = %subst(
      code:
      1:
      %scan('/': code) - 1);
  endif;

  // Get rid of everything to the left of the comma
  code = %trim(
           %subst(
             code:
             %scan(
               ',':
               code) + 1));

  // Get rid of anything to the right of the reference source
  if %scan(' ': %trim(code)) <> 0;
    code = %subst(
              code:
              1:
              %scan(' ': %trim(code)) - 1);
  endif;

  serviceProgram.name = code;

  if isExistingObject(
    serviceProgram.name:
    '*SRVPGM':
    serviceProgram.library
  );
    return *on;
  endif;

  if %scan('#': serviceProgram.name) <> 0;
    serviceProgram.name = %scanrpl('#': '.': serviceProgram.name);

    if isExistingObject(
      serviceProgram.name:
      '*SRVPGM':
      serviceProgram.library
    );
      return *on;
    endif;
  endif;

  promptNeeded = '?';

  if batchMode;
    serviceProgram.name = *blanks;
  endif;

  return *on;

end-proc;

//-----------------------------------------------------------------------

dcl-proc closeReplCmpl export;

  exec sql CLOSE repl_userServicePrograms;

end-proc;

//-----------------------------------------------------------------------

dcl-proc isExistingObject;
  dcl-pi *n ind;
    object char(10) const;
    type char(7) const;
    library char(10) const;
  end-pi;

  monitor;
    runCommand('CHKOBJ OBJ(&1/&2) OBJTYPE(&3)': library: object: type);
  on-error;
    return *off;
  endmon;

  return *on;

end-proc;

//-----------------------------------------------------------------------

