**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

//-----------------------------------------------------------------------

/include repl_ins
/include repl_usr
/include repl_vars

/include repl_eval

//-----------------------------------------------------------------------

dcl-proc evaluateLineOfPseudoCode export;
  dcl-pi *n;
    line like(t_lineOfCode.line) const;
    triggerType like(t_triggerType) const;
    variableName like(t_variable.name) const;
    scope like(t_variable.scope) const;
    expectedValue like(t_longLineOfCode) const options(*nopass);
  end-pi;

  dcl-ds variable likeds(t_variable);
  dcl-s elementVariableName like(t_variable.name);
  dcl-s unarrayedName like(t_variable.name);
  dcl-s arrayElement like(t_variable.arraySize) inz(0);

  unarrayedName = variableName;

  dow %scan('(': unarrayedName) > 0;
    unarrayedName =
      %subst(unarrayedName: 1: %scan('(': unarrayedName) - 1)
      + %subst(unarrayedName: %scan(')': unarrayedName) + 1);
  enddo;

  if triggerType in %list(
    c_setValueStatement: 
    c_replPrintStatement: 
    c_replEqualsStatement
  )
  and variableName <> *blanks;
    variable = fetchStoredVariable(unarrayedName: scope);
    if variable.arraySize > 1 or variable.parentArraySize > 1;
      arrayElement
        = fetchArrayElementFromStatement(variableName);
    else;
      arrayElement = 0;
    endif;
    markVariableAsUsed(variable.id);
  endif;

  // conditional statement
  // if, else, elseif, when, other
  if triggerType = c_conditionalStatement;
    insertSingleLineOfGeneratedCode
      ('replHlpr_conditional(' + %char(line) + ');');
    return;
  endif;

  // value statement
  // a = b (unknown variable type)
  if triggerType = c_setValueStatement
  and (variable.name = *blanks or variable.type = *blanks);
    insertSingleLineOfGeneratedCode
      ('replHlpr_unknown(' + %char(line) + ');');
    return;
  endif;

  // value statement
  // print statement
  // assertion
  // a = b (known variable type)
  // replPrint(a) (known variable type)
  // replEquals('A': a) (known variable type)
  if triggerType in %list(
    c_setValueStatement: 
    c_replPrintStatement: 
    c_replEqualsStatement
  )
  and (variable.name <> *blanks and variable.type <> *blanks);

    select;

      when variable.type = 'indicator';
        insertSingleLineOfGeneratedCode
          ('replResult_rpgIndicator(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(%scanrpl('.':'_':variable.name)) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variable.name));
        if triggerType = c_replPrintStatement;
          insertSingleLineOfGeneratedCode
            (': ''PRINT''');
        endif;
        if triggerType = c_replEqualsStatement;
          insertSingleLineOfGeneratedCode
            (': ''TEST''');
          insertSingleLineOfGeneratedCode
            (': ' + expectedValue);
        endif;  
        insertSingleLineOfGeneratedCode
          (');');

      // not an array, maybe a data structure
      when variable.arraySize <= 1;
        insertSingleLineOfGeneratedCode
          ('repl_'
              + %trim(variable.scope) + '_'
              + %trim(%scanrpl('.':'_':%char(variable.id)))
              + '_single(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(variableName) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variableName));
        if triggerType = c_replPrintStatement;
          insertSingleLineOfGeneratedCode
            (': ''PRINT''');
        endif;
        if triggerType = c_replEqualsStatement;
          insertSingleLineOfGeneratedCode
            (': ''TEST''');
          insertSingleLineOfGeneratedCode
            (': ' + expectedValue);
        endif;  
        insertSingleLineOfGeneratedCode
          (');');

      // array, and we're evaluating a specific value
      when (variable.arraySize > 1)
      and arrayElement <> 0;
        insertSingleLineOfGeneratedCode
          ('repl_'
              + %trim(variable.scope) + '_'
              + %trim(%scanrpl('.':'_':%char(variable.id)))
              + '_single(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(variableName) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variableName));
        if triggerType = c_replPrintStatement;
          insertSingleLineOfGeneratedCode
            (': ''PRINT''');
        endif;
        if triggerType = c_replEqualsStatement;
          insertSingleLineOfGeneratedCode
            (': ''TEST''');
          insertSingleLineOfGeneratedCode
            (': ' + expectedValue);
        endif;  
        insertSingleLineOfGeneratedCode
          (');');

      // array, and we're evaluating all values
      when (variable.arraySize > 1)
      and arrayElement = 0;
        insertSingleLineOfGeneratedCode
          ('repl_'
              + %trim(variable.scope) + '_'
              + %trim(%scanrpl('.':'_':%char(variable.id)))
              + '_multiple(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(variableName) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variableName));
        if triggerType = c_replPrintStatement;
          insertSingleLineOfGeneratedCode
            (': ''PRINT''');
        endif;
        if triggerType = c_replEqualsStatement and expectedValue = *blanks;
          insertSingleLineOfGeneratedCode
            (': ''TEST-READFAILURE''');
        endif; 
        if triggerType = c_replEqualsStatement and expectedValue <> *blanks;
          insertSingleLineOfGeneratedCode
            (': ''TEST''');
          insertSingleLineOfGeneratedCode
            (': ' + expectedValue);
        endif;  
        insertSingleLineOfGeneratedCode
          (');');

    endsl;

  endif;

  // loop statement
  // dow, dou, for
  if triggerType = c_loopStatement;
    insertSingleLineOfGeneratedCode
      ('replHlpr_loop(' + %char(line) + ');');
  endif;

  // sql statement
  if triggerType = c_sqlStatement;
    insertSingleLineOfGeneratedCode
      ('replHlpr_recordSqlResult(' + %char(line) + ': sqlstt: sqlcod);');
  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc freeFormatEvaluationFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
    triggerType like(t_triggerType);
  end-pi;

  if %len(%trim(code)) >= 10 
  and %lower(%subst(%trim(code): 1: 10)) = 'replprint(';
    triggerType = c_replPrintStatement;
    return *on;
  endif;

  if %len(%trim(code)) >= 11
  and %lower(%subst(%trim(code): 1: 11)) = 'replequals(';
    triggerType = c_replEqualsStatement;
    return *on;
  endif;

  if %scan('IF ': %trim(toUpperCase(code))) = 1
  or %scan('IF%': %trim(toUpperCase(code))) = 1
  or %scan('ELSE ': %trim(toUpperCase(code))) = 1
  // why do we need the next case?
  //or %scan('ELSE%': %trim(toUpperCase(code))) = 1
  or %scan('ELSE;': %trim(toUpperCase(code))) = 1
  or %scan('ELSEIF ': %trim(toUpperCase(code))) = 1
  or %scan('ELSEIF%': %trim(toUpperCase(code))) = 1
  or %scan('WHEN ': %trim(toUpperCase(code))) = 1
  or %scan('WHEN%': %trim(toUpperCase(code))) = 1
  or %scan('OTHER ': %trim(toUpperCase(code))) = 1
  or %scan('OTHER;': %trim(toUpperCase(code))) = 1
  or %scan('ON-ERROR ': %trim(toUpperCase(code))) = 1
  or %scan('ON-ERROR;': %trim(toUpperCase(code))) = 1;

    triggerType = c_conditionalStatement;
    return *on;

  endif;

  if %scan('EXEC SQL': %trim(toUpperCase(code))) = 1;

    // DECLARE statement are non-executable, so don't
    //  evaluate them - check by removing blanks, uppercasing,
    //  and trimming.
    if %scan('EXECSQLDECLARE':
             %trim(toUpperCase(%scanrpl(' ':'':code)))
            ) <> 1;

      triggerType = c_sqlStatement;
      return *on;

    endif;

  endif;

  if %scan('DOW ': %trim(toUpperCase(code))) = 1
  or %scan('DOW%': %trim(toUpperCase(code))) = 1
  or %scan('DOU ': %trim(toUpperCase(code))) = 1
  or %scan('DOU%': %trim(toUpperCase(code))) = 1
  or %scan('FOR ': %trim(toUpperCase(code))) = 1;
  // why do we need the next case?
  //or %scan('FOR%': %trim(toUpperCase(code))) = 1;

    triggerType = c_loopStatement;
    return *on;

  endif;

  if %scan('=': %trim(code)) <> 0;

    triggerType = c_setValueStatement;
    return *on;

  endif;

  return *off;

end-proc;

//-----------------------------------------------------------------------

dcl-proc endOfFreeFormatLineFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return %scanr(';': %trim(code)) = %len(%trim(code));

end-proc;

//-----------------------------------------------------------------------

dcl-proc codeIsComment export;
  dcl-pi *n ind;
    code like(t_lineOfCode.code) const;
  end-pi;

  if %len(%trim(code)) = 0;
    return *off;
  endif;

  // It's at least one character
  if %len(%trim(code)) >= 1;
    // The first character is an asterisk
    if %subst(%trim(code): 1: 1) = '*';
      // It's at least three characters
      if %len(%trim(code)) >= 3;
        // and isn't a default RPG indicator
        if %subst(%trim(toUpperCase(code)): 1: 3) = '*IN';
          return *off;
        endif;
      endif;
      return *on;
    endif;
  endif;

  if %len(%trim(code)) >= 2;
    if %subst(%trim(code): 1: 2) = '//'
    or %subst(%trim(code): 1: 2) = '--'
    or %subst(%trim(code): 1: 2) = '/*'
    // weird rpgleref statements:
    or %subst(%trim(toUpperCase(code)): 1: 2) = '/E'
    or %subst(%trim(toUpperCase(code)): 1: 2) = '/D'
    // weird, occasional see/change nonsense
    or %subst(%trim(code): 2: 1) = '*';
      return *on;
    endif;
  endif;

  if %len(%trim(code)) >= 3;
    // weird rpgleref statements:
    if %subst(%trim(toUpperCase(code)): 1: 3) = '/IF';
      return *on;
    endif;
  endif;
  return *off;

end-proc;

//-----------------------------------------------------------------------

dcl-proc codeIsReplHelper export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  if %len(%trim(code)) = 0;
    return *off;
  endif;

  select;
    when %len(%trim(code)) >= 10 
    and %lower(%subst(%trim(code): 1: 10)) = 'replprint(';
      return *on;
    when %len(%trim(code)) >= 11
    and %lower(%subst(%trim(code): 1: 11)) = 'replequals(';
      return *on;
    other;
      return *off;  
  endsl;

end-proc;

//-----------------------------------------------------------------------

dcl-proc replresultEvaluationHelpers export;

  dcl-ds variable likeds(t_variable);

  prepareListOfVariables();

  dow fetchListOfVariables(variable);

    select;
      when variable.arraySize <= 1
      and variable.type <> 'datastruct';
        replResult_evaluate_fld_single(variable);

      when variable.arraySize > 1
      and variable.type <> 'datastruct';
        replResult_evaluate_fld_single(variable);
        replResult_evaluate_fld_multiple(variable);

      when variable.arraySize <= 1
      and variable.type = 'datastruct';
        replResult_evaluate_ds_single(variable);

      when variable.arraySize > 1
      and variable.type = 'datastruct';
        replResult_evaluate_ds_single(variable);
        replResult_evaluate_ds_multiple(variable);

    endsl;

  enddo;

end-proc;

//-----------------------------------------------------------------------

dcl-proc replResult_evaluate_fld_single export;
  dcl-pi *n;
    variable likeds(t_variable) value;
  end-pi;

  dcl-ds basedUpon likeds(t_variable);

  if %scan('LIKE(': variable.definition) > 0
  and variable.scope <> 'MAIN';
    variable.definition = %scanrpl('LIKE(': '': variable.definition);
    variable.definition = %trim(%scanrpl(')': '': variable.definition));
    basedUpon = fetchStoredVariable(variable.definition: variable.scope);
    variable.definition = basedUpon.definition;
  endif;

  insertSingleLineOfGeneratedCode
    ('dcl-proc repl_...');
  insertSingleLineOfGeneratedCode  
    (          %trim(variable.scope) + '_...');
  insertSingleLineOfGeneratedCode
    (          %trim(%scanrpl('.':'_':%char(variable.id))) + '_single;');
  insertSingleLineOfGeneratedCode
    ('  dcl-pi *n;');
  insertSingleLineOfGeneratedCode
    ('    repl_line like(t_lineOfCode.line) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_name char(70) const;');

  if variable.type = '*indicator';
    insertSingleLineOfGeneratedCode
      ('    repl_i ind const;');
  else;
    insertSingleLineOfGeneratedCode
      ('    repl_i ' + %trim(variable.definition) + ' const;');
  endif;

  insertSingleLineOfGeneratedCode
    ('    repl_result_type char(20) const options(*nopass);');
  insertSingleLineOfGeneratedCode 
    ('    repl_expected ');
  insertSingleLineOfGeneratedCode 
    ('     ' + %trim(variable.definition));
  insertSingleLineOfGeneratedCode
    ('      const options(*nopass);');

  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_result_type_wk char(20) inz(''EVALUATION'');');
  insertSingleLineOfGeneratedCode
    ('  dcl-s result_description varchar(1000) inz('''');');

  insertSingleLineOfGeneratedCode
  ('  result_description = %trim(repl_name) + '' = '';');
  if variable.type in %list('indicator': '*indicator');
    insertSingleLineOfGeneratedCode
    ('    if repl_i;');
    insertSingleLineOfGeneratedCode
    ('      result_description += ''true'';');
    insertSingleLineOfGeneratedCode
    ('    else;');
    insertSingleLineOfGeneratedCode
    ('      result_description += ''false'';');
    insertSingleLineOfGeneratedCode
    ('    endif;');
  else;
    insertSingleLineOfGeneratedCode
    ('    result_description += %trim(%char(repl_i));');
  endif;
    
  insertSingleLineOfGeneratedCode
    ('  if %parms() >= %parmnum(repl_result_type);');
  insertSingleLineOfGeneratedCode
    ('    repl_result_type_wk = repl_result_type;');
  insertSingleLineOfGeneratedCode
    ('    if %parms() >= %parmnum(repl_expected);');
  insertSingleLineOfGeneratedCode
    ('      if repl_i = repl_expected;');
  insertSingleLineOfGeneratedCode
    ('        repl_result_type_wk = ''TEST-SUCCESS'';');
  insertSingleLineOfGeneratedCode
    ('        result_description = ''Success, '' + ');
  insertSingleLineOfGeneratedCode
    ('        result_description;');
  insertSingleLineOfGeneratedCode
    ('      else;');
  insertSingleLineOfGeneratedCode
    ('        repl_result_type_wk = ''TEST-FAILURE'';');
  insertSingleLineOfGeneratedCode
    ('        result_description = ''Failure, '' + ');
  insertSingleLineOfGeneratedCode
    ('        result_description + ');
  insertSingleLineOfGeneratedCode
    ('        '', expected '' + ');
  insertSingleLineOfGeneratedCode
    ('        %trim(%char(repl_expected));');
  insertSingleLineOfGeneratedCode
    ('      endif;');
  insertSingleLineOfGeneratedCode
    ('    endif;');
  insertSingleLineOfGeneratedCode
    ('  endif;');


  insertSingleLineOfGeneratedCode
    ('  exec sql');
  insertSingleLineOfGeneratedCode
    ('    INSERT INTO replrslt');
  insertSingleLineOfGeneratedCode
    ('      (line_number, result_number, result_description, result_type)');
  insertSingleLineOfGeneratedCode
    ('      (SELECT :repl_line,');
  insertSingleLineOfGeneratedCode
    ('              COALESCE(MAX(result_number), 0)+1,');
  insertSingleLineOfGeneratedCode
    ('              :result_description,');
  insertSingleLineOfGeneratedCode
    ('              :repl_result_type_wk');
  insertSingleLineOfGeneratedCode
    ('         FROM replrslt');
  insertSingleLineOfGeneratedCode
    ('        WHERE session_id = (QSYS2.JOB_NAME)');
  insertSingleLineOfGeneratedCode
    ('              AND line_number = :repl_line);');

  insertSingleLineOfGeneratedCode
    ('end-proc;');

end-proc;

//-----------------------------------------------------------------------

dcl-proc replResult_evaluate_fld_multiple export;
  dcl-pi *n;
    variable likeds(t_variable) const;
  end-pi;

  insertSingleLineOfGeneratedCode
    ('dcl-proc repl_...');
  insertSingleLineOfGeneratedCode
    (          %trim(variable.scope) + '_...');
  insertSingleLineOfGeneratedCode
    (          %trim(%scanrpl('.':'_':%char(variable.id))) + '_multiple;');
  insertSingleLineOfGeneratedCode
    ('  dcl-pi *n;');
  insertSingleLineOfGeneratedCode
    ('    repl_line like(t_lineOfCode.line) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_name char(70) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_i ' + %trim(variable.definition));
  insertSingleLineOfGeneratedCode
    ('      dim(' + %trim(%char(variable.arraySize)) + ') const;');
  insertSingleLineOfGeneratedCode
    ('    repl_result_type char(20) const options(*nopass);');
  insertSingleLineOfGeneratedCode
    ('    repl_expected ' + %trim(variable.definition));
  insertSingleLineOfGeneratedCode
    ('      dim(' + %trim(%char(variable.arraySize)) 
                  + ') const options(*nopass);');
  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_result_type_wk char(20) inz(''EVALUATION'');');
  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_j packed(10);');

  insertSingleLineOfGeneratedCode
    ('  if %parms() >= %parmnum(repl_result_type);');
  insertSingleLineOfGeneratedCode
    ('    repl_result_type_wk = repl_result_type;');
  insertSingleLineOfGeneratedCode
    ('  endif;');

  insertSingleLineOfGeneratedCode
    ('  for repl_j = 1 to ' + %char(variable.arraySize) + ';');

  insertSingleLineOfGeneratedCode
    ('     if %parms() >= %parmnum(repl_expected);' );

  insertSingleLineOfGeneratedCode
    ('      repl_...');
  insertSingleLineOfGeneratedCode
    ('      ' + %trim(variable.scope) + '_...');
  insertSingleLineOfGeneratedCode  
    ('      ' + %trim(%scanrpl('.':'_':%char(variable.id))) + '_...');
  insertSingleLineOfGeneratedCode  
    ('      single(');
  insertSingleLineOfGeneratedCode
    ('         repl_line:');
  insertSingleLineOfGeneratedCode
    ('         %trim(repl_name) + ''('' + %char(repl_j) + '')'':');
  insertSingleLineOfGeneratedCode
    ('         repl_i(repl_j):');
  insertSingleLineOfGeneratedCode
    ('         repl_result_type_wk:');
  insertSingleLineOfGeneratedCode
    ('         repl_expected(repl_j)');
  insertSingleLineOfGeneratedCode
    ('      );' );

  insertSingleLineOfGeneratedCode
    ('     else;' );

  insertSingleLineOfGeneratedCode
    ('      repl_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':%char(variable.id)))
       + '_single');
  insertSingleLineOfGeneratedCode
    ('       (repl_line:');
  insertSingleLineOfGeneratedCode
    ('        %trim(repl_name) + ''('' + %char(repl_j) + '')'':');
  insertSingleLineOfGeneratedCode
    ('        repl_i(repl_j):');
  insertSingleLineOfGeneratedCode
    ('        repl_result_type_wk');
  insertSingleLineOfGeneratedCode
    ('       );' );

  insertSingleLineOfGeneratedCode
    ('     endif;' );

  insertSingleLineOfGeneratedCode
    ('  endfor;');

  insertSingleLineOfGeneratedCode
    ('end-proc;');

end-proc;

//-----------------------------------------------------------------------

dcl-proc replResult_evaluate_ds_single export;
  dcl-pi *n;
    variable likeds(t_variable) const;
  end-pi;

  dcl-ds subField likeds(t_variable);
  dcl-ds proc_subField likeds(t_variable);
  dcl-ds subFieldOnly likeds(t_variable);

  insertSingleLineOfGeneratedCode
    ('dcl-proc repl_...');
  insertSingleLineOfGeneratedCode  
    (          %trim(variable.scope) + '_...');
  insertSingleLineOfGeneratedCode  
    (          %trim(%scanrpl('.':'_':%char(variable.id))) + '_single;');
  insertSingleLineOfGeneratedCode
    ('  dcl-pi *n;');
  insertSingleLineOfGeneratedCode
    ('    repl_line like(t_lineOfCode.line) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_name char(70) const;');
  if variable.definition <> *blanks;
    insertSingleLineOfGeneratedCode
      ('    repl_i ' + %trim(variable.definition) + ' const;');
  else;
    insertSingleLineOfGeneratedCode
      ('    repl_i likeds(' + %trim(variable.name) + ') const;');
  endif;
  insertSingleLineOfGeneratedCode
    ('    repl_result_type char(20) const options(*nopass);');
  if variable.definition <> *blanks;
    insertSingleLineOfGeneratedCode
      ('    repl_expected ' 
            + %trim(variable.definition) 
            + ' const options(*nopass);');
  else;
    insertSingleLineOfGeneratedCode
      ('    repl_expected likeds(' 
            + %trim(variable.name) 
            + ') const options(*nopass);');
  endif;
  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_result_type_wk char(20) inz(''EVALUATION'');');

  insertSingleLineOfGeneratedCode
    ('  if %parms() >= %parmnum(repl_result_type);');
  insertSingleLineOfGeneratedCode
    ('    repl_result_type_wk = repl_result_type;');
  insertSingleLineOfGeneratedCode
    ('  endif;');

  prepareListOfDataStructureFields(variable.name: variable.scope);

  dow fetchedDataStructureFields(subField);

    proc_subField = subField;
    subFieldOnly = subField;
    subfieldOnly.name
      = %subst(subFieldOnly.name:
               %max(1: %scan('.': subFieldOnly.name) + 1));

    subField.name = %scanrpl(
        %trim(variable.name) + '.': 'repl_i.': subField.name);

    if subField.arraySize = 0;

      insertSingleLineOfGeneratedCode
        ('if %parms >= %parmnum(repl_expected);');

        insertSingleLineOfGeneratedCode
          ('  repl_...');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variable.scope) + '_...');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(%scanrpl('.':'_':%char(proc_subField.id))) + '_...');
        insertSingleLineOfGeneratedCode  
          ('  single(');
        insertSingleLineOfGeneratedCode
          ('    repl_line: ');
        insertSingleLineOfGeneratedCode
          ('    %trim(repl_name) + ''.' + %trim(subFieldOnly.name) + ''':');
        insertSingleLineOfGeneratedCode
          ('    ' + %trim(subField.name) + ':');
        insertSingleLineOfGeneratedCode
          ('    repl_result_type_wk:');
        insertSingleLineOfGeneratedCode
          ('    repl_expected.' + %trim(subFieldOnly.name));
        insertSingleLineOfGeneratedCode
          ('  );');

      insertSingleLineOfGeneratedCode
        ('else;');

        insertSingleLineOfGeneratedCode
          ('  repl_...');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variable.scope) + '_...');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(%scanrpl('.':'_':%char(proc_subField.id))) + '_...');
        insertSingleLineOfGeneratedCode  
          ('  single(');
        insertSingleLineOfGeneratedCode
          ('    repl_line: ');
        insertSingleLineOfGeneratedCode
          ('    %trim(repl_name) + ''.' + %trim(subFieldOnly.name) + ''':');
        insertSingleLineOfGeneratedCode
          ('    ' + %trim(subField.name) + ':');
        insertSingleLineOfGeneratedCode
          ('    repl_result_type_wk');
        insertSingleLineOfGeneratedCode
          ('  );');

      insertSingleLineOfGeneratedCode
        ('endif;');

    else;

      insertSingleLineOfGeneratedCode
        ('if %parms >= %parmnum(repl_expected);');

        insertSingleLineOfGeneratedCode
          ('  repl_...');
        insertSingleLineOfGeneratedCode
          (  %trim(variable.scope) + '_...');
        insertSingleLineOfGeneratedCode
          (  %trim(%scanrpl('.':'_':%char(proc_subField.id))) + '_...');
        insertSingleLineOfGeneratedCode
          ('  multiple(');
        insertSingleLineOfGeneratedCode
          ('    repl_line: ');
        insertSingleLineOfGeneratedCode
          ('    %trim(repl_name) + ''.' + %trim(subFieldOnly.name) + ''':');
        insertSingleLineOfGeneratedCode
          ('    ' + %trim(subField.name) + ':');
        insertSingleLineOfGeneratedCode
          ('    repl_result_type_wk:');
        insertSingleLineOfGeneratedCode
          ('    repl_expected.' + %trim(subFieldOnly.name));
        insertSingleLineOfGeneratedCode  
          (');');

      insertSingleLineOfGeneratedCode
        ('else;');

        insertSingleLineOfGeneratedCode
          ('  repl_...');
        insertSingleLineOfGeneratedCode
          (  %trim(variable.scope) + '_...');
        insertSingleLineOfGeneratedCode
          (  %trim(%scanrpl('.':'_':%char(proc_subField.id))) + '_...');
        insertSingleLineOfGeneratedCode
          ('  multiple(');
        insertSingleLineOfGeneratedCode
          ('    repl_line: ');
        insertSingleLineOfGeneratedCode
          ('    %trim(repl_name) + ''.' + %trim(subFieldOnly.name) + ''':');
        insertSingleLineOfGeneratedCode
          ('    ' + %trim(subField.name) + ':');
        insertSingleLineOfGeneratedCode
          ('    repl_result_type_wk');
        insertSingleLineOfGeneratedCode  
          (');');

      insertSingleLineOfGeneratedCode
        ('endif;');

    endif;

  enddo;

  insertSingleLineOfGeneratedCode
    ('end-proc;');

end-proc;

//-----------------------------------------------------------------------

dcl-proc replResult_evaluate_ds_multiple export;
  dcl-pi *n;
    variable likeds(t_variable) const;
  end-pi;

  insertSingleLineOfGeneratedCode
    ('dcl-proc repl_...');
  insertSingleLineOfGeneratedCode  
    (          %trim(variable.scope) + '_...');
  insertSingleLineOfGeneratedCode  
    (          %trim(%scanrpl('.':'_':%char(variable.id))) + '_multiple;');
  insertSingleLineOfGeneratedCode
    ('  dcl-pi *n;');
  insertSingleLineOfGeneratedCode
    ('    repl_line like(t_lineOfCode.line) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_name char(70) const;');
  if variable.definition <> *blanks;
    insertSingleLineOfGeneratedCode
      ('    repl_i ' + %trim(variable.definition));
    insertSingleLineOfGeneratedCode
      ('      dim(' + %trim(%char(variable.arraySize)) + ') const;');
  else;
    insertSingleLineOfGeneratedCode
      ('    repl_i likeds(' + %trim(variable.name) + ')');
    insertSingleLineOfGeneratedCode  
      ('      dim(' + %trim(%char(variable.arraySize)) + ') const;');
  endif;
  insertSingleLineOfGeneratedCode
    ('    repl_result_type char(20) const options(*nopass);');
  if variable.definition <> *blanks;
    insertSingleLineOfGeneratedCode
      ('    repl_expected ' + %trim(variable.definition));
    insertSingleLineOfGeneratedCode
      ('      dim(' + %trim(%char(variable.arraySize)) 
                    + ') const options(*nopass);');
  else;
    insertSingleLineOfGeneratedCode
      ('    repl_expected likeds(' + %trim(variable.name) + ')');
    insertSingleLineOfGeneratedCode  
      ('      dim(' + %trim(%char(variable.arraySize)) 
                    + ') const options(*nopass);');
  endif;

  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_result_type_wk char(20) inz(''EVALUATION'');');
  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_j packed(10);');

  insertSingleLineOfGeneratedCode
    ('  if %parms() >= %parmnum(repl_result_type);');
  insertSingleLineOfGeneratedCode
    ('    repl_result_type_wk = repl_result_type;');
  insertSingleLineOfGeneratedCode
    ('  endif;');

  insertSingleLineOfGeneratedCode
    ('if %parms >= %parmnum(repl_expected);');

    insertSingleLineOfGeneratedCode
      ('  for repl_j = 1 to ' + %char(variable.arraySize) + ';');
    insertSingleLineOfGeneratedCode
      ('    repl_...');
    insertSingleLineOfGeneratedCode  
      ('    ' + %trim(variable.scope) + '_...');
    insertSingleLineOfGeneratedCode  
      ('    ' + %trim(%scanrpl('.':'_':%char(variable.id))) + '_...');
    insertSingleLineOfGeneratedCode  
      ('    single(');
    insertSingleLineOfGeneratedCode
      ('      repl_line: ');
    insertSingleLineOfGeneratedCode
      ('      %trim(repl_name) + ''('' + %char(repl_j) + '')'': ');
    insertSingleLineOfGeneratedCode
      ('      repl_i(repl_j):');
    insertSingleLineOfGeneratedCode
      ('      repl_result_type_wk:');
    insertSingleLineOfGeneratedCode
      ('      repl_expected(repl_j)');
    insertSingleLineOfGeneratedCode  
      ('    );');
    insertSingleLineOfGeneratedCode
      ('  endfor;');

  insertSingleLineOfGeneratedCode
    ('else;');

    insertSingleLineOfGeneratedCode
      ('  for repl_j = 1 to ' + %char(variable.arraySize) + ';');
    insertSingleLineOfGeneratedCode
      ('    repl_...');
    insertSingleLineOfGeneratedCode  
      ('    ' + %trim(variable.scope) + '_...');
    insertSingleLineOfGeneratedCode  
      ('    ' + %trim(%scanrpl('.':'_':%char(variable.id))) + '_...');
    insertSingleLineOfGeneratedCode  
      ('    single(');
    insertSingleLineOfGeneratedCode
      ('      repl_line: ');
    insertSingleLineOfGeneratedCode
      ('      %trim(repl_name) + ''('' + %char(repl_j) + '')'': ');
    insertSingleLineOfGeneratedCode
      ('      repl_i(repl_j):');
    insertSingleLineOfGeneratedCode
      ('      repl_result_type_wk');
    insertSingleLineOfGeneratedCode  
      ('    );');
    insertSingleLineOfGeneratedCode
      ('  endfor;');

  insertSingleLineOfGeneratedCode
    ('endif;');

  insertSingleLineOfGeneratedCode
    ('end-proc;');

end-proc;

//-----------------------------------------------------------------------

dcl-proc separateReferenceSource export;
  dcl-pi *n likeds(t_referenceSource);
    code like(t_lineOfCode.code) value;
  end-pi;

  dcl-ds referenceSource likeds(t_referenceSource);

  // get rid of trailing / leading blanks
  code = %trim(toUpperCase(code));
  code = %trim(%scanrpl('/INCLUDE': '': code));
  code = %trim(%scanrpl('/COPY': '': code));
  if %scan(' ':code) <> 0;
    code = %trim(%subst(code: 1: %scan(' ':code)));
  endif;

  if %scan('/':code) = 0;
    referenceSource.library = '*LIBL';
  else;
    // read from the first blank: /include_
    // to the first slash: *LIBL/
    referenceSource.library
      = %subst(%trim(code):
               1:
               %scan('/':%trim(code))-1);
    code = %trim(%subst(code: %scan('/':code)+1));
  endif;

  referenceSource.file = %trim(%subst(code: 1: %scan(',':code)-1));
  code = %trim(%subst(code: %scan(',':code)+1));

  // all that's left is the name
  referenceSource.member = %trim(code);

  // not so fast! In the case that we have *LIBL,
  // we actually need to work out what the right
  // library is.
  if referenceSource.library = '*LIBL';
    referenceSource.library
       = findMyMember(referenceSource.file: referenceSource.member);
  endif;

  return referenceSource;

end-proc;

//-----------------------------------------------------------------------

dcl-proc findMyMember export;
  dcl-pi *n like(t_referenceSource.library);
    piFile like(t_referenceSource.file) const;
    piMember like(t_referenceSource.member) const;
  end-pi;

  dcl-pr memberFinder extpgm('QUSRMBRD');
    received char(135);
    receivedLen int(10) const;
    format char(8) const;
    file char(20) const;
    member char(10) const;
    overrides char(1) const;
    errors char(272);
    processingTechnique char(1) const;
  end-pr;

  dcl-ds response qualified;
    bytesReturned int(10);
    bytesAvailable int(10);
    file char(10);
    library char(10);
    member char(10);
    attribute char(10);
    sourceType char(10);
    created char(13);
    changed char(13);
    description char(50);
    sourceFile char(1);
  end-ds;

  dcl-ds errors qualified;
    bytesProvided int(10);
    bytesAvailable int(10);
    exceptionId char(7);
    reserved char(1);
    errorData char(1024);
  end-ds;

  memberFinder(
    response:
    %size(response):
    'MBRD0100':
    piFile + '*LIBL':
    piMember:
    '0':
    errors:
    '1');

  if errors.exceptionId <> *blanks;
    return '*LIBL';
  endif;

  return response.library;

end-proc;

//-----------------------------------------------------------------------


