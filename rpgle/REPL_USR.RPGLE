**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;
//----------------------------------------------------------------------

/include repl_cmpl
/include repl_pm

/include repl_usr

//-----------------------------------------------------------------------

dcl-proc runGeneratedProgramObject export;
  dcl-ds thrownError likeds(t_thrownError);

  monitor;
    runCommand('CALL PGM(&1/&2)':
                 c_generatedSourceLibrary:
                 c_generatedProgram);
  on-error;
    thrownError.errorCode = c_program_exception;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc showGeneratedSourceObject export;
  dcl-ds thrownError likeds(t_thrownError);

  monitor;
    runCommand('DSPPFM FILE(&1/&2) MBR(&3)':
                c_generatedSourceLibrary:
                c_generatedSourceFile:
                c_generatedSourceMember);
  on-error;
    thrownError.errorCode = c_error_showing_generated_source;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc debugGeneratedSourceObject export;
  dcl-ds thrownError likeds(t_thrownError);

  monitor;
    runCommand('ADDENVVAR ENVVAR(&1) VALUE(&2) LEVEL(&3) REPLACE(*YES)':
                'ILE_DEBUGGER_1':
                'ALLOW_WIDE_SCREEN':
                '*JOB');
  on-error;
  endmon;

  monitor;
    runCommand('ENDDBG');
  on-error;
  endmon;
  monitor;
    runCommand('STRDBG PGM(&1/&2) UPDPROD(*YES) OPMSRC(*YES)':
               c_generatedSourceLibrary:
               c_generatedProgram);
  on-error;
    thrownError.errorCode = c_problem_starting_debug;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc showUserSpoolFiles export;
  dcl-ds thrownError likeds(t_thrownError);

  monitor;
    runCommand('WRKSPLF');
  on-error;
    thrownError.errorCode = c_problem_showing_spool_files;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc showCommandLine export;
  dcl-ds thrownError likeds(t_thrownError);

  monitor;
    runCommand('CALL QSYS/QCMD');
  on-error;
    thrownError.errorCode = c_problem_showing_command_line;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc showJobLog export;
  dcl-ds thrownError likeds(t_thrownError);

  monitor;
    runCommand('DSPJOBLOG');
  on-error;
    thrownError.errorCode = c_problem_showing_job_log;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------
dcl-proc runCommand export;
  dcl-pi *n;
    command varchar(1024) const;
    parm1 varchar(100) const options(*nopass);
    parm2 varchar(100) const options(*nopass);
    parm3 varchar(100) const options(*nopass);
    parm4 varchar(100) const options(*nopass);
    parm5 varchar(100) const options(*nopass);
    parm6 varchar(100) const options(*nopass);
  end-pi;

  dcl-pr QCMDEXC extpgm;
    command char(32702) const options(*varsize);
    commandLength packed(15:5) const;
    igcProcessControl char(3) const options(*nopass);
  end-pr;

  dcl-s wkCommand varchar(32702);

    select;
      when %parms = %parmnum(command);
        wkCommand = command;
      when %parms = %parmnum(parm1);
        wkCommand = formatString(command:
          parm1);
      when %parms = %parmnum(parm2);
        wkCommand = formatString(command:
          parm1: parm2);
      when %parms = %parmnum(parm3);
        wkCommand = formatString(command:
          parm1: parm2: parm3);
      when %parms = %parmnum(parm4);
        wkCommand = formatString(command:
          parm1: parm2: parm3: parm4);
      when %parms = %parmnum(parm5);
        wkCommand = formatString(command:
          parm1: parm2: parm3: parm4: parm5);
      when %parms = %parmnum(parm6);
        wkCommand = formatString(command:
          parm1: parm2: parm3: parm4: parm5: parm6);
    endsl;

    qcmdexc(wkCommand: %len(wkCommand));

end-proc;
//-----------------------------------------------------------------------
dcl-proc formatString export;
  dcl-pi *n varchar(1024);
    message varchar(1024) const;
    parm1  varchar(100) const;
    parm2  varchar(100) const options(*nopass);
    parm3  varchar(100) const options(*nopass);
    parm4  varchar(100) const options(*nopass);
    parm5  varchar(100) const options(*nopass);
    parm6  varchar(100) const options(*nopass);
  end-pi;

  dcl-s result like(message);

  result = message;
  result = %scanrpl('&1' : %trim(parm1) : result);
  if %parms >= %parmnum(parm2);
    result = %scanrpl('&2' : %trim(parm2) : result);
  endif;
  if %parms >= %parmnum(parm3);
    result = %scanrpl('&3' : %trim(parm3) : result);
  endif;
  if %parms >= %parmnum(parm4);
    result = %scanrpl('&4' : %trim(parm4) : result);
  endif;
  if %parms >= %parmnum(parm5);
    result = %scanrpl('&5' : %trim(parm5) : result);
  endif;
  if %parms >= %parmnum(parm6);
    result = %scanrpl('&6' : %trim(parm6) : result);
  endif;

  return result;

end-proc;
//-----------------------------------------------------------------------

