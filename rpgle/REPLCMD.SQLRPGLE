**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked);

dcl-pi *n;
  csUserServicePrograms char(250);
end-pi;

/include repl_cmpl
/include repl_gen
/define STMF_COMPILE
/include repl_hlpr
/include repl_pseu
/include repl_usr

dcl-ds userServicePrograms likeds(t_serviceProgram) dim(10);
dcl-ds ps psds qualified;
  currentUser char(10) pos(358);
end-ds;

clearSessionPseudoResults();
clearSessionPseudoVariables();

userServicePrograms = readServicePrograms(csUserServicePrograms);

monitor;
  createGeneratedSourceObject();
on-error;
  replResult_recordCustomMessage(
    'Unexpected error in setting up workfiles. Request cancelled.'
  );
  quit();
endmon;

monitor;
  compileGeneratedSourceObject(*off: *on: userServicePrograms);
on-error;
  addSpoolFileDataToResults();
  quit();
endmon;

monitor;
  runGeneratedProgramObject();
on-error;
  quit();
endmon;

quit();
return;

//-----------------------------------------------------------------------

dcl-proc readServicePrograms;
  dcl-pi *n likeds(t_serviceProgram) dim(10);
    csUserServicePrograms char(250);
  end-pi;

  dcl-ds servicePrograms likeds(t_serviceProgram) dim(10);
  dcl-s itemCount packed(2) inz(1);

  dow itemFound(csUserServicePrograms: servicePrograms(itemCount))
  and itemCount < 10;
    // What an unusual loop.
    itemCount += 1;
  enddo;

  return servicePrograms;

end-proc;

//-----------------------------------------------------------------------

dcl-proc itemFound;
  dcl-pi *n ind;
    csUserServicePrograms char(250);
    serviceProgram likeds(t_serviceProgram);
  end-pi;

  dcl-s currentItem char(21);

  // An empty string. We have finished processing.
  if csUserServicePrograms = *blanks;
    return *off;
  endif;

  csUserServicePrograms = %trim(csUserServicePrograms);

  if %scan(',': csUserServicePrograms) <> 0;
    currentItem = %trim(%subst(
      csUserServicePrograms:
      1:
      %scan(',': csUserServicePrograms) - 1
    ));
    csUserServicePrograms = %trim(%subst(
      csUserServicePrograms:
      %scan(',': csUserServicePrograms) + 1
    ));
  else;
    currentItem = csUserServicePrograms;
    csUserServicePrograms = *blanks;
  endif;

  // A blank item. Weird, but OK.
  if currentItem = *blanks;
    return *on;
  endif;

  // If the user gave a specific library, use that.
  // Otherwise, use *LIBL.
  if %scan('/': currentItem) <> 0;
    serviceProgram.library = %trim(%subst(
      currentItem:
      1:
      %scan('/': currentItem) - 1
    ));
    serviceProgram.name = %trim(%subst(
      currentItem:
      %scan('/': currentItem) + 1
    ));
  else;
    serviceProgram.library = '*LIBL';
    serviceProgram.name = currentItem;
  endif;

  return *on;

end-proc;

//-----------------------------------------------------------------------

dcl-proc addSpoolFileDataToResults;

  dcl-ds got qualified;
    joblog ind;
    module ind;
    source ind;
  end-ds;

  dcl-ds generationTime qualified;
    joblog timestamp inz(*loval);
    module timestamp inz(*loval);
    source timestamp inz(*loval);
  end-ds;

  got.joblog = createSpoolFileCopy('QPJOBLOG');
  got.module = createSpoolFileCopy(c_generatedModule);
  got.source = createSpoolFileCopy(c_generatedSourceFile);

  if got.joblog;
    generationTime.joblog = getGenerationTime('QPJOBLOG');
  endif;
  if got.module;
    generationTime.module = getGenerationTime(c_generatedModule);
  endif;
  if got.source;
    generationTime.source = getGenerationTime(c_generatedSourceFile);
  endif;

  if generationTime.joblog >= generationTime.module
  and generationTime.joblog >= generationTime.source;
    printFile('QPJOBLOG');
    return;
  endif;

  if generationTime.module >= generationTime.source;
    printFile(c_generatedModule);
    return;
  endif;

  if generationTime.source <> *loval;
    printFile(c_generatedSourceFile);
    return;
  endif;

  replResult_recordCustomMessage('Failure reason cannot be determined.');

end-proc;

//-----------------------------------------------------------------------

dcl-proc createSpoolFileCopy;
  dcl-pi *n ind;
    fileName char(10) const;
  end-pi;

  monitor;
    runCommand('DLTF FILE(&1/&2)':
               'QTEMP': fileName);
  on-error;
  endmon;

  monitor;
    runCommand('CRTPF FILE(&1/&2) RCDLEN(&3)':
               'QTEMP': fileName: '132');
  on-error;
  endmon;

  monitor;
    runCommand('CPYSPLF FILE(&1) TOFILE(&2/&1) ' +
                 'SPLNBR(&3) CRTDATE(&3) ' +
                 'JOB(&4/&5)':
               fileName: 'QTEMP': '*LAST': ps.currentUser: 'QPRTJOB');
  on-error;
    return *off;
  endmon;

  return *on;

end-proc;

//-----------------------------------------------------------------------

dcl-proc getGenerationTime;
  dcl-pi *n timestamp;
    fileName char(10) const;
  end-pi;

  dcl-s sqlQuery varchar(200);
  dcl-s generationTime timestamp;

  sqlQuery =
    'SELECT TO_DATE(substring('
       + %trim(fileName)
       + ', 95, 17), ''DD/MM/YY HH24:MI:SS'') ' +
      'FROM qtemp/' + %trim(fileName) + ' ';

  exec sql
    PREPARE genTimeSqlBlock FROM :sqlQuery;

  exec sql
    DECLARE genTIme CURSOR FOR genTimeSqlBlock;

  exec sql
    OPEN genTime;

  exec sql
    FETCH NEXT FROM genTime INTO :generationTime;

  exec sql
    CLOSE genTime;

  return generationTime;

end-proc;

//-----------------------------------------------------------------------

dcl-proc printFile;
  dcl-pi *n;
    fileName char(10) const;
  end-pi;

  dcl-s sqlQuery varchar(100);
  dcl-s row char(132);

  replResult_recordCustomMessage(
    'Unable to complete - run details shown below:'
  );

  replResult_recordCustomMessage(*blanks);

  sqlQuery =
    'SELECT * ' +
      'FROM qtemp/' + %trim(fileName) + ' ';

  exec sql
    PREPARE resultDataSqlBlock FROM :sqlQuery;

  exec sql
    DECLARE resultData CURSOR FOR resultDataSqlBlock;

  exec sql
    OPEN resultData;

  exec sql
    FETCH NEXT FROM resultData INTO :row;

  dow sqlstt = '00000';

    replResult_recordCustomMessage(row);

    exec sql
      FETCH NEXT FROM resultData INTO :row;

  enddo;

  exec sql
    CLOSE resultData;

end-proc;

//-----------------------------------------------------------------------

dcl-proc quit;
  *inlr = *on;
end-proc;


