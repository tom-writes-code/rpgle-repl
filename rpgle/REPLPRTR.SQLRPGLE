
**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked);

//------------------------------------------------------------------------------

/include repl_pseu

//------------------------------------------------------------------------------

dcl-pr writeout extproc('write');
  fd   int(10) value;
  buf  pointer value;
  size int(10) value;
end-pr;

//------------------------------------------------------------------------------

dcl-pi *n;
  verbosity char(1) const;
  sessionId char(28) const;
end-pi;

//------------------------------------------------------------------------------

dcl-s length int(10);
dcl-s data char(10);

dcl-s printIndividualResults ind;
dcl-s printSummaryResult ind;

dcl-ds result likeds(t_replResult);
dcl-s passCount zoned(5) inz(0);
dcl-s failCount zoned(5) inz(0);
dcl-s exceptionFound ind;

dcl-s errorCode char(3);
dcl-s successCode char(2);
dcl-s newLine char(1) inz(x'25');

//------------------------------------------------------------------------------

errorCode = '-1' + newLine;
successCode = '0' + newLine;

// 0=stdin, 1=stdout, 2=stderr
// readin(0: %addr(data): %size(data));
// writeout(1: %addr(data): %len(data));

prepareFetchResultForAllCode(sessionId);
dow fetchResultForAllLinesOfCode(result);

  if result.resultType <> 'EVALUATION';

    select;
      when result.resultType = 'TEST-SUCCESS';
        passCount += 1;
      when result.resultType = 'TEST-FAILURE';
        failCount += 1;
      other;
        exceptionFound = *on;
    endsl;      

    writeTestResult(result.lineNumber: result);

  endif;

enddo;

writeTestSummary(passCount: failCount: exceptionFound);

// return a -1 or 0 at the end

if failCount > 0 or exceptionFound;
  writeout(2: %addr(errorCode): %len(%trim(errorCode)));
else;
  writeout(1: %addr(successCode): %len(%trim(successCode)));
endif;

// clear any existing results

clearSessionPseudoResults(sessionId);

*inlr = *on;
return;

//------------------------------------------------------------------------------

dcl-proc writeTestResult;
  dcl-pi *n;
    line packed(6) const options(*exact);
    result likeds(t_replResult) const options(*exact);
  end-pi;

  dcl-s resultString char(1100) static;

  resultString = 
    'Line ' + %char(line) + ' ' +
    %trim(result.resultType) + ' ' +
    %trim(result.resultText) + 
    newLine;  

  if verbosity = '2' or verbosity = '3';
    writeout(1: %addr(resultString): %len(%trim(resultString)));
  endif;

end-proc;

//------------------------------------------------------------------------------

dcl-proc writeTestSummary;
  dcl-pi *n;
    passCount zoned(5) const options(*exact);
    failCount zoned(5) const options(*exact);
    exceptionFound ind const options(*exact);
  end-pi;

  dcl-s resultString char(100) static;

  resultString = *blanks;

  if exceptionFound;
    resultString = 
      'Could not complete build or run, run in verbose mode for details\n' + 
      newLine;  
  elseif failCount > 0;
    resultString = 
      'Failure, ' + 
      %char(passCount) + ' tests passed, ' +
      %char(failCount) + ' tests failed' + 
      newLine; 
  endif;

  if resultString <> *blanks;
    if verbosity <> '0';
      writeout(2: %addr(resultString): %len(%trim(resultString)));
    endif;
    return;
  endif;  
  
  if passCount = 0;
    resultString = 
      'No tests executed, ' + 
      %char(passCount) + ' tests passed, ' +
      %char(failCount) + ' tests failed\n' + 
      newLine; 
  else;
    resultString = 
      'Success, ' + 
      %char(passCount) + ' tests passed, ' +
      %char(failCount) + ' tests failed\n' + 
      newLine; 
  endif;

  if verbosity <> '0';
    writeout(1: %addr(resultString): %len(%trim(resultString)));
  endif;

end-proc;

//------------------------------------------------------------------------------