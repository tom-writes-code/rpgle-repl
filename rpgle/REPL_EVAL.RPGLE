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

  if triggerType = c_setValueStatement
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
  // a = b (known variable type)
  if triggerType = c_setValueStatement
  and (variable.name <> *blanks and variable.type <> *blanks);

    select;

      when variable.type = 'indicator';
        insertSingleLineOfGeneratedCode
          ('replResult_rpgIndicator('
           + %char(line) + ':'
           + '''' + %trim(%scanrpl('.':'_':variable.name)) + ''':'
           + %trim(variable.name) + ');');

      // not an array, maybe a data structure
      when variable.arraySize <= 1;
        insertSingleLineOfGeneratedCode
          ('replResult_'
              + %trim(variable.scope) + '_'
              + %trim(%scanrpl('.':'_':variable.name))
              + '_single(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(variableName) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variableName) + ');');

      // array, and we're evaluating a specific value
      when (variable.arraySize > 1)
      and arrayElement <> 0;
        insertSingleLineOfGeneratedCode
          ('replResult_'
              + %trim(variable.scope) + '_'
              + %trim(%scanrpl('.':'_':variable.name))
              + '_single(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(variableName) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variableName) + ');');

      // array, and we're evaluating all values
      when (variable.arraySize > 1)
      and arrayElement = 0;
        insertSingleLineOfGeneratedCode
          ('replResult_'
              + %trim(variable.scope) + '_'
              + %trim(%scanrpl('.':'_':variable.name))
              + '_multiple(');
        insertSingleLineOfGeneratedCode
          ('  ' + %char(line) + ':');
        insertSingleLineOfGeneratedCode
          ('  ' + '''' + %trim(variableName) + ''':');
        insertSingleLineOfGeneratedCode
          ('  ' + %trim(variableName) + ');');

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
    ('dcl-proc replResult_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':variable.name)) + '_single;');
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
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  exec sql');
  insertSingleLineOfGeneratedCode
    ('    INSERT INTO replrslt');
  insertSingleLineOfGeneratedCode
    ('      (line_number, result_number, result_description)');
  insertSingleLineOfGeneratedCode
    ('      (SELECT :repl_line,');
  insertSingleLineOfGeneratedCode
    ('              COALESCE(MAX(result_number),0)+1,');
  insertSingleLineOfGeneratedCode
    ('              TRIM(:repl_name) || '' = '' ||');

  if variable.type = 'indicator' or variable.type = '*indicator';
    insertSingleLineOfGeneratedCode
      ('            CASE WHEN :repl_i = 1 ');
    insertSingleLineOfGeneratedCode
      ('              THEN ''true'' ');
    insertSingleLineOfGeneratedCode
      ('              ELSE ''false'' END');
  elseif variable.type = 'numeric';
    insertSingleLineOfGeneratedCode
      ('              CAST (:repl_i AS CHAR(1000))');
  else;
    insertSingleLineOfGeneratedCode
      ('              '''''''''
        + '|| TRIM(CAST(:repl_i AS CHAR(1000))) '
        + '|| ''''''''');
  endif;

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
    ('dcl-proc replResult_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':variable.name)) + '_multiple;');
  insertSingleLineOfGeneratedCode
    ('  dcl-pi *n;');
  insertSingleLineOfGeneratedCode
    ('    repl_line like(t_lineOfCode.line) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_name char(70) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_i ' + %trim(variable.definition) + ' ' +
       'dim(' + %trim(%char(variable.arraySize)) + ') const;');
  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_j packed(10);');

  insertSingleLineOfGeneratedCode
    ('  for repl_j = 1 to ' + %char(variable.arraySize) + ';');
  insertSingleLineOfGeneratedCode
    ('    replResult_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':variable.name))
       + '_single');
  insertSingleLineOfGeneratedCode
    ('     (repl_line:');
  insertSingleLineOfGeneratedCode
    ('      %trim(repl_name) + ''('' + %char(repl_j) + '')'':');
  insertSingleLineOfGeneratedCode
    ('      repl_i(repl_j));' );
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
    ('dcl-proc replResult_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':variable.name)) + '_single;');
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
      ('    repl_i likeds(' + %trim(variable.name) + ') ' +' const;');
  endif;
  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  prepareListOfDataStructureFields(variable.name: variable.scope);

  dow fetchedDataStructureFields(subField);

    proc_subField = subField;
    subFieldOnly = subField;
    subfieldOnly.name
      = %subst(subFieldOnly.name:
               %max(1: %scan('.': subFieldOnly.name) + 1));

    subField.name = %scanrpl(%trim(variable.name) + '.':
                             'repl_i.':
                             subField.name);

    if subField.arraySize = 0;
      insertSingleLineOfGeneratedCode
        ('  replResult_'
           + %trim(variable.scope) + '_'
           + %trim(%scanrpl('.':'_':proc_subField.name))
           + '_single(');
      insertSingleLineOfGeneratedCode
        ('   repl_line: ');
      insertSingleLineOfGeneratedCode
        ('   %trim(repl_name) + ''.' + %trim(subFieldOnly.name) + ''':');
      insertSingleLineOfGeneratedCode
        ('   ' + %trim(subField.name) + ');');
    else;
      insertSingleLineOfGeneratedCode
        ('  replResult_'
           + %trim(variable.scope) + '_'
           + %trim(%scanrpl('.':'_':proc_subField.name))
           + '_multiple(');
      insertSingleLineOfGeneratedCode
        ('   repl_line: ');
      insertSingleLineOfGeneratedCode
        ('   %trim(repl_name) + ''.' + %trim(subFieldOnly.name) + ''':');
      insertSingleLineOfGeneratedCode
        ('   ' + %trim(subField.name) + ');');
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
    ('dcl-proc replResult_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':variable.name)) + '_multiple;');
  insertSingleLineOfGeneratedCode
    ('  dcl-pi *n;');
  insertSingleLineOfGeneratedCode
    ('    repl_line like(t_lineOfCode.line) const;');
  insertSingleLineOfGeneratedCode
    ('    repl_name char(70) const;');
  if variable.definition <> *blanks;
    insertSingleLineOfGeneratedCode
      ('    repl_i ' + %trim(variable.definition) + ' ' +
         'dim(' + %trim(%char(variable.arraySize)) + ') const;');
  else;
    insertSingleLineOfGeneratedCode
      ('    repl_i likeds(' + %trim(variable.name) + ') ' +
         'dim(' + %trim(%char(variable.arraySize)) + ') const;');
  endif;
  insertSingleLineOfGeneratedCode
    ('  end-pi;');

  insertSingleLineOfGeneratedCode
    ('  dcl-s repl_j packed(10);');

  insertSingleLineOfGeneratedCode
    ('  for repl_j = 1 to ' + %char(variable.arraySize) + ';');
  insertSingleLineOfGeneratedCode
    ('    replResult_'
       + %trim(variable.scope) + '_'
       + %trim(%scanrpl('.':'_':variable.name)) + '_single(');
  insertSingleLineOfGeneratedCode
    ('      repl_line: ');
  insertSingleLineOfGeneratedCode
    ('      %trim(repl_name) + ''('' + %char(repl_j) + '')'': ');
  insertSingleLineOfGeneratedCode
    ('      repl_i(repl_j));');
  insertSingleLineOfGeneratedCode
    ('  endfor;');

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


