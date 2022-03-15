**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt) noMain;

/include repl_pm

//-----------------------------------------------------------------------

dcl-ds t_errorStruct qualified template;
  bytesProvided int(10);
  bytesAvailable int(10);
  exceptionId char(7);
  reserved char(1);
  errorData char(1024);
end-ds;

//-----------------------------------------------------------------------

dcl-proc throw export;
  dcl-pi *n;
    thrownError likeds(t_thrownError) value;
  end-pi;

  dcl-pr QMHSNDPM extpgm('QMHSNDPM');
    messageId char(7) const;
    messageFile char(20) const;
    messageData char(32767) const;
    lengthOfMessageData int(10) const;
    messageType char(10) const;
    callStackEntry char(10) const;
    callStackCounter int(10) const;
    messageKey char(4);
    errorCode likeds(t_errorStruct) options(*varsize);

    // Optional parameter group 1
    callStackEntryLength int(10) const options(*nopass);
    callStackEntryQualification char(20) const options(*nopass);
    displayWaitTime int(10) const options(*nopass);

    // Optional parameter group 2
    callStackEntryDataType char(10) const options(*nopass);
    ccsid int(10) const options(*nopass);
  end-pr;

  dcl-ds errorStruct likeds(t_errorStruct);

  dcl-s messageKey char(4);

  QMHSNDPM(
    thrownError.errorCode:
    'QBASMSG   QSYS':
    *blanks:
    0:
    '*ESCAPE':
    '*':
    2:
    messageKey:
    errorStruct
  );

end-proc;

//-----------------------------------------------------------------------

dcl-proc catch export;
  dcl-pi *n likeds(t_caughtError) end-pi;

  dcl-pr QMHRCVPM extpgm('QMHRCVPM');
    messageInformation char(32767) options(*varsize);
    messageInfoLength int(10) const;
    formatName char(8) const;
    callStackEntry char(10) const;
    callStackCounter int(10) const;
    messageType char(10) const;
    messageKey char(4) const;
    waitTime int(10) const;
    messageAction char(10) const;
    errorCode likeds(t_errorStruct) options(*varsize);
  end-pr;

  dcl-ds rcvm0200 qualified;
    bytesReturned int(10);
    bytesAvailable int(10);
    messageSeverity int(10);
    messageId char(7);
    messageType char(2);
    messageKey char(4);
    messageFile char(10);
    librarySpecified char(10);
    libraryUsed char(10);
    sendingJob char(10);
    sendingJobUser char(10);
    sendingJobNumber char(6);
    sendingProgram char(12);
    sendingProgramInstruction char(4);
    timeSent char(13);
    receivingProgram char(10);
    receivingProgramInstruction char(4);
    sendingType char(1);
    receivingType char(1);
    reserved char(1);
    textConversionStatus int(10);
    dataConversionStatus int(10);
    alertOption char(9);
    messageCcsid int(10);
    replacementDataCcsid int(10);
    replacementDataLength int(10);
    replacementDataLengthAvailable int(10);
    messageLength int(10);
    messageLengthAvailable int(10);
    helpLength int(10);
    helpLengthAvailable int(10);
    messageData char(1000);
  end-ds;

  dcl-ds errorStruct likeds(t_errorStruct);

  dcl-ds caughtError likeds(t_caughtError);

  QMHRCVPM(
    rcvm0200:
    %size(rcvm0200):
    'RCVM0200':
    '*':
    1:
    '*EXCP':
    *blanks:
    0:
    '*REMOVE':
    errorStruct
  );

  caughtError.errorCode = rcvm0200.messageId;

  return caughtError;

end-proc;

//-----------------------------------------------------------------------
