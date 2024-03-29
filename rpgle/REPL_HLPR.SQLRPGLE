**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

/include repl_pseu

/define STMF_COMPILE
/include repl_hlpr

//-----------------------------------------------------------------------

dcl-proc replHlpr_recordSqlResult export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
    sqlstate varchar(5) const;
    sqlCode packed(10) const;
  end-pi;

  dcl-s resultDescription varchar(50);

  resultDescription = 'Sql State: '
                     + %trim(sqlState)
                     + ', Sql Code: '
                     + %trim(%char(sqlCode));

  exec sql
    INSERT INTO replrslt
      (line_number, result_number, result_description)
      (SELECT :line, COALESCE(MAX(result_number), 0)+1,
              :resultDescription
         FROM replrslt
        WHERE session_id = QSYS2.JOB_NAME
              AND line_number = :line);

end-proc;

//-----------------------------------------------------------------------

dcl-proc replHlpr_loop export;
  dcl-pi *n;
    repl_line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    MERGE INTO replrslt AS t
    USING
    (VALUES
       (QSYS2.JOB_NAME, :repl_line, 1, 'Loop executed'))
    AS s(session_id, line_number,
          result_number, result_description)
    ON t.session_id = s.session_id
       AND t.line_number = s.line_number
       AND t.result_number = s.result_number
    WHEN MATCHED THEN
      UPDATE set loop_count = loop_count + 1
    WHEN NOT MATCHED THEN
      INSERT
        (line_number, result_number, result_description)
      VALUES
        (s.line_number, s.result_number, s.result_description);

end-proc;

//-----------------------------------------------------------------------

dcl-proc replHlpr_unknown export;
  dcl-pi *n;
    repl_line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    INSERT INTO replrslt
      (line_number, result_number, result_description)
      (SELECT :repl_line,
              COALESCE(MAX(result_number), 0)+1,
              'Statement cannot be evaluated'
         FROM replrslt
        WHERE session_id = QSYS2.JOB_NAME
              AND line_number = :repl_line);

end-proc;

//-----------------------------------------------------------------------

dcl-proc replHlpr_conditional export;
  dcl-pi *n;
    repl_line like(t_lineOfCode.line) const;
  end-pi;

  exec sql
    INSERT INTO replrslt
      (line_number, result_number, result_description)
      (SELECT :repl_line,
              COALESCE(MAX(result_number), 0)+1,
              'Statement evaluates to true'
         FROM replrslt
        WHERE session_id = QSYS2.JOB_NAME
              AND line_number = :repl_line);

end-proc;

//-----------------------------------------------------------------------

dcl-proc replResult_rpgIndicator export;
  dcl-pi *n;
    repl_line like(t_lineOfCode.line) const;
    repl_name char(70) const;
    repl_i ind const;
    repl_result_type char(20) const options(*nopass);
    repl_expected ind const options(*nopass);
  end-pi;
  dcl-s repl_result_type_wk char(20) inz('EVALUATION');
  dcl-s result_description varchar(1000) inz('');

  if repl_i;
    result_description = %trim(repl_name) + ' = true';
  else;
    result_description = %trim(repl_name) + ' = false';
  endif;  

  if %parms() >= %parmnum(repl_result_type);
    repl_result_type_wk = repl_result_type;
    if %parms() >= %parmnum(repl_expected);
      if repl_i = repl_expected;
        repl_result_type_wk = 'TEST-SUCCESS';
        result_description = 'Success, ' + result_description;
      else;
        repl_result_type_wk = 'TEST-FAILURE';
        result_description = 'Failure, ' + result_description;
        if repl_expected;
          result_description = result_description + ', expected true';
        else;
          result_description = result_description + ', expected false';
        endif;
      endif;
    endif;
  endif;

  exec sql
    INSERT INTO replrslt
      (line_number, result_number, result_description, result_type)
      (SELECT :repl_line,
              COALESCE(MAX(result_number), 0)+1,
              :result_description,
              :repl_result_type_wk  
         FROM replrslt
        WHERE session_id = (QSYS2.JOB_NAME)
              AND line_number = :repl_line);            

end-proc;

//-----------------------------------------------------------------------

dcl-proc replResult_recordCustomMessage export;
  dcl-pi *n;
    customMessage varchar(132) const;
  end-pi;

  exec sql
    INSERT INTO replrslt
      (line_number, result_number, result_description)
      (SELECT COALESCE(MAX(line_number), 0)+1,
              1,
              :customMessage
         FROM replrslt
        WHERE session_id = QSYS2.JOB_NAME);

end-proc;

//-----------------------------------------------------------------------


