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
  end-pi;

  exec sql
    INSERT INTO replrslt
      (line_number, result_number, result_description)
      (SELECT :repl_line,
              COALESCE(MAX(result_number), 0)+1,
              TRIM(:repl_name) CONCAT ' = ' CONCAT
              CASE WHEN :repl_i = 1
                THEN 'true'
                ELSE 'false' END
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


