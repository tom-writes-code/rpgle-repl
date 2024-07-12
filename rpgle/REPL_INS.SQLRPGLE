**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

//-----------------------------------------------------------------------

/include repl_cmpl

/include repl_pseu

dcl-c c_aliasName 'REPL_ALIAS';

//-----------------------------------------------------------------------

dcl-proc insertSingleLineOfGeneratedCode export;
  dcl-pi *n;
    code like(t_lineOfCode.code) const;
    line like(t_lineOfCode.line) options(*nopass) const;
  end-pi;

  dcl-s line0 like(t_lineOfCode.line) inz(0);

  if %parms() >= %parmnum(line) and %addr(line) <> *null;
    line0 = line;
  endif;

  if codeIsFixedFormat(code);

    exec sql
      INSERT INTO qtemp/repl_alias
        (srcseq, srcdta)
      VALUES
        (:line0, '     ' CONCAT :code);

  else;

    exec sql
      INSERT INTO qtemp/repl_alias
        (srcseq, srcdta)
      VALUES
        (:line0, '       ' CONCAT :code);

  endif;


end-proc;

//-----------------------------------------------------------------------

dcl-proc codeIsFixedFormat export;
  dcl-pi *n ind;
    code like(t_lineOfCode.code) const;
  end-pi;

  return
     %subst(code: 1: 1) = 'F'
  or %subst(code: 1: 1) = 'I'
  or %subst(code: 1: 1) = 'H'
  or %subst(code: 1: 1) = 'P'
  or %subst(code: 1: 1) = 'O'
  or %subst(code: 1: 1) = 'D'
  or %subst(code: 1: 1) = 'C';

end-proc;

//-----------------------------------------------------------------------

dcl-proc createSqlAlias export;
  dcl-pi *n;
  end-pi;

  dcl-s sqlQuery varchar(100);

  sqlQuery = 'CREATE ALIAS '
            + c_generatedSourceLibrary + '.' + c_aliasName
            + ' FOR '
            + c_generatedSourceLibrary
              + '.' + c_generatedSourceFile
              + ' (' + c_generatedSourceMember + ')';     

  exec sql PREPARE createAlias FROM :sqlQuery;

  exec sql EXECUTE createAlias;

end-proc;

//-----------------------------------------------------------------------

dcl-proc dropSqlAlias export;

  dcl-s sqlQuery varchar(100);

  sqlQuery = 'DROP ALIAS '
            + c_generatedSourceLibrary + '.' + c_aliasName;

  exec sql PREPARE dropAlias FROM :sqlQuery;

  exec sql EXECUTE dropAlias;

end-proc;

//-----------------------------------------------------------------------

