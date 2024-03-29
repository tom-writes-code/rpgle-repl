**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

/include repl_vars

//-----------------------------------------------------------------------

dcl-proc dataStructureStartFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  // Ignore anything likerec or likeds.
  return
    %scan('DCL-DS': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc dataStructureEndFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
    %scan('END-DS': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc variableDefinitionFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
    %scan('DCL-S': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc constantDefinitionFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
    %scan('DCL-C': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc storeVariableDefinition export;
  dcl-pi *n;
    code like(t_longLineOfCode) const;
    parentDataStructure like(t_variable.name) const;
    scope like(t_variable.scope) const;
  end-pi;

  dcl-ds variable likeds(t_variable);

  variable.name = fetchVariableNameFromCode(code);
  variable.type = fetchVariableTypeFromCode(code: scope);
  variable.arraySize = fetchVariableArraySizeFromCode(code: scope);
  variable.scope = scope;
  variable.definition = fetchVariableDefinitionFromCode(code);
  variable.template = variableIsTemplate(code);

  storeVariable(variable: parentDataStructure);

end-proc;

//-----------------------------------------------------------------------

dcl-proc variableIsTemplate export;
  dcl-pi *n like(t_variable.template);
    code like(t_longLineOfCode) value;
  end-pi;

  // upper case it
  code = toUpperCase(code);

  // get rid of the dcl-s
  code = %trim(%scanrpl('DCL-S': '': code));

  dow %scan('  ': code) <> 0;
    code = %scanrpl('  ': ' ': code);
  enddo;

  // get rid of the variable name
  code
    = %trim(%subst(
        code:
        %scan(' ': code)
      ));

  // take out all the semi-colons
  code = ' ' + %trim(%scanrpl(';': '': code)) + ' ';

  if %scan(' TEMPLATE ': code) > 0;
    return 'Y';
  else;
    return 'N';
  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc dataStructureIsTemplate export;
  dcl-pi *n like(t_variable.template);
    code like(t_longLineOfCode) value;
  end-pi;

  // upper case it
  code = toUpperCase(code);

  // get rid of the dcl-ds
  code = %trim(%scanrpl('DCL-DS': '': code));

  // if we can't split it any further, it definitely isn't a template
  if %scan(' ': code) = 0;
    return 'N';
  endif;

  // get rid of the variable name
  code
    = %trim(%subst(
        code:
        %scan(' ': code)
      ));

  // take out all the semi-colons
  code = ' ' + %trim(%scanrpl(';': '': code)) + ' ';

  if %scan(' TEMPLATE ': code) > 0;
    return 'Y';
  else;
    return 'N';
  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc storeConstantDefinition export;
  dcl-pi *n;
    code like(t_longLineOfCode) const;
    scope like(t_variable.scope) const;
  end-pi;

  dcl-ds variable likeds(t_variable);

  variable.name = fetchConstantNameFromCode(code);
  variable.type = 'constant';
  variable.arraySize = 0;
  variable.scope = scope;
  variable.definition = fetchConstantDefinitionFromCode(
                          code:
                          variable.name
                        );
  variable.template = 'N';

  storeVariable(variable: *blanks);

end-proc;

//-----------------------------------------------------------------------

dcl-proc storeDataStructureDefinition export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) const;
    scope like(t_variable.scope) const;
    parentDataStructure like(t_variable.name) const;
  end-pi;

  dcl-ds variable likeds(t_variable);
  dcl-s qualified ind;

  qualified
    = (%scan(' QUALIFIED': toUpperCase(code)) > 0);

  variable.name = fetchDataStructureNameFromCode(code);
  variable.type = 'datastruct';
  variable.arraySize = fetchDataStructureArraySizeFromCode(code: scope);
  variable.scope = scope;
  if %scan('LIKEDS': toUpperCase(code)) > 0;
    variable.definition = fetchDataStructureDefinitionFromCode(code);
  else;
    variable.definition = *blanks;
  endif;
  variable.template = dataStructureIsTemplate(code);

  storeVariable(variable: parentDataStructure: qualified);

  return variable.name;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableDefinitionFromCode export;
  dcl-pi *n like(t_variable.definition);
    code like(t_longLineOfCode) value;
  end-pi;

  // upper case it
  code = toUpperCase(code);

  // get rid of the dcl-s
  code = %trim(%scanrpl('DCL-S': '': code));

  // get rid of the variable name
  code
    = %trim(%subst(
        code:
        %scan(' ': code)
      ));

  // take out all the spaces
  code = %trim(%scanrpl(' ': '': code));

  // start of definition, up until the next closing brace:
  // unless it was a special, no closing brace definition.
  select;
    when %scan('VARCHAR(': code) > 0;
      code = %subst(
        code: %scan('VARCHAR(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('CHAR(': code) > 0;
      code = %subst(
        code: %scan('CHAR(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('INT(': code) > 0;
      code = %subst(
        code: %scan('INT(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('PACKED(': code) > 0;
      code = %subst(
        code: %scan('PACKED(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('ZONED(': code) > 0;
      code = %subst(
        code: %scan('ZONED(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('BINDEC(': code) > 0;
      code = %subst(
        code: %scan('BINDEC(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('UNSIGNED(': code) > 0;
      code = %subst(
        code: %scan('UNSIGNED(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('UNS(': code) > 0;
      code = %subst(
        code: %scan('UNS(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('FLOAT(': code) > 0;
      code = %subst(
        code: %scan('FLOAT(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('LIKE(': code) > 0;
      code = %subst(
        code: %scan('LIKE(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    when %scan('IND;': code) > 0;
      return 'IND';
    when %scan('DATE;': code) > 0;
      return 'DATE';
    when %scan('TIMESTAMP;': code) > 0
    or %scan('TIMESTAMP(': code) > 0;
      return 'TIMESTAMP(12)';
    when %scan('TIME;': code) > 0;
      return 'TIME';
    other;
      return *blanks;
  endsl;

  return code;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchDataStructureDefinitionFromCode export;
  dcl-pi *n like(t_variable.definition);
    code like(t_longLineOfCode) value;
  end-pi;

  // upper case it
  code = toUpperCase(code);

  // get rid of the dcl-s
  code = %trim(%scanrpl('DCL-DS': '': code));

  // get rid of the variable name
  code
    = %trim(%subst(
        code:
        %scan(' ': code)
      ));

  // take out all the spaces
  code = %trim(%scanrpl(' ': '': code));

  // start of definition, up until the next closing brace:
  // unless it was a special, no closing brace definition.
  select;
    when %scan('LIKEDS(': code) > 0;
      code = %subst(
        code: %scan('LIKEDS(': code)
      );
      code = %subst(
        code: 1: %scan(')': code)
      );
    other;
      return *blanks;
  endsl;

  return code;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchConstantDefinitionFromCode export;
  dcl-pi *n like(t_variable.definition);
    code like(t_longLineOfCode) const;
    variableName like(t_variable.name) const;
  end-pi;

  dcl-s constantDefinition like(t_longLineOfCode);

  if %scanr(';': code) > 0;

    // take out any trailing semi-colons and anything after it
    constantDefinition = %trim(
      %subst(
        code: 1: %scanr(';': code) - 1
      )
    );

  else;

    constantDefinition = %trim(code);

  endif;

  // take out everything after the name
  constantDefinition = %trim(
    %subst(
      constantDefinition:
      %scan(
        toUpperCase(%trim(variableName)):
        toUpperCase(constantDefinition)
      ) + %len(%trim(variableName))
    )
  );

  return constantDefinition;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableNameFromCode export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) const;
  end-pi;

  dcl-ds variable likeds(t_variable);

  // Remove leading blanks
  variable.name = %trim(code);

  // Get rid of the dcl-s
  variable.name
    = %trim(%scanrpl('DCL-S': '': toUpperCase(variable.name)));

  // get rid of semi-colons;
  variable.name = %trim(%scanrpl(';': '': variable.name));

  // Get rid of anything after a blank
  variable.name = %subst(variable.name: 1: %scan(' ': variable.name));

  return %trim(variable.name);

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchDataStructureNameFromCode export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) const;
  end-pi;

  dcl-ds variable likeds(t_variable);

  // Remove leading blanks
  variable.name = %trim(code);

  // Get rid of the dcl-ds
  variable.name
    = %trim(%scanrpl('DCL-DS': '': toUpperCase(variable.name)));

  // get rid of semi-colons;
  variable.name = %trim(%scanrpl(';': '': variable.name));

  // Get rid of anything after a blank
  variable.name = %subst(variable.name: 1: %scan(' ': variable.name));

  return %trim(variable.name);

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchConstantNameFromCode export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) const;
  end-pi;

  dcl-ds variable likeds(t_variable);

  // Remove leading blanks
  variable.name = %trim(code);

  // Get rid of the dcl-c
  variable.name
    = %trim(%scanrpl('DCL-C': '': toUpperCase(variable.name)));

  // Get rid of anything after a blank
  variable.name = %subst(variable.name: 1: %scan(' ': variable.name));

  return %trim(variable.name);

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchArrayElementFromStatement export;
  dcl-pi *n like(t_variable.arraySize);
    code like(t_longLineOfCode) const;
  end-pi;

  dcl-s snippet like(t_longLineOfCode);
  dcl-s arrayElement like(t_variable.arraySize);

  // remove all blanks
  snippet = %trim(%scanrpl(' ': '': code));

  // get rid of everything after an equals sign
  if %scan('=': snippet) > 0;
    snippet = %trim(%subst(snippet: 1: %scan('=': snippet)));
  endif;

  // no sign of the final element being an array element? bail.
  if %len(snippet) = 0;
    return 0;
  endif;

  if %subst(snippet: %len(snippet): 1) <> ')';
    return 0;
  endif;

  // get rid of the tail
  snippet = %subst(snippet:
                   1:
                   %scanr(')': snippet) - 1);

  if %len(snippet) = 0;
    return 0;
  endif;

  // get rid of the head
  snippet = %subst(snippet:
                   %scanr('(': snippet) + 1);


  monitor;
    arrayElement = %dec(snippet: 10: 0);
  on-error;
    arrayElement = 0;
  endmon;

  return arrayElement;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableTypeFromCode export;
  dcl-pi *n like(t_variable.type);
    code like(t_longLineOfCode) value;
    scope like(t_variable.scope) const;
  end-pi;

  dcl-s definition like(t_longLineOfCode);
  dcl-ds likeVariable likeds(t_variable);

  // uppercase it
  code = toUpperCase(code);

  // remove the dcl-s
  code = %trim(%scanrpl('DCL-S': '': code));

  // remove the variable name
  code = %trim(%subst(code: %scan(' ': code)));

  select;
    when %scan('CHAR(': %scanrpl(' ': '': code)) > 0
    or %scan('VARCHAR(': %scanrpl(' ': '': code)) > 0;
      return 'character';
    when %scan('INT(': %scanrpl(' ': '': code)) > 0
    or %scan('PACKED(': %scanrpl(' ': '': code)) > 0
    or %scan('ZONED(': %scanrpl(' ': '': code)) > 0
    or %scan('BINDEC(': %scanrpl(' ': '': code)) > 0
    or %scan('UNSIGNED(': %scanrpl(' ': '': code)) > 0
    or %scan('FLOAT(': %scanrpl(' ': '': code)) > 0;
      return 'numeric';
    when %scan('IND;': %scanrpl(' ': '': code)) > 0;
      return 'indicator';
    when %scan('DATE;': %scanrpl(' ': '': code)) > 0;
      return 'date';
    when %scan('TIMESTAMP;': %scanrpl(' ': '': code)) > 0
    or %scan('TIMESTAMP(': %scanrpl(' ': '': code)) > 0;
      return 'timestamp';
    when %scan('TIME;': %scanrpl(' ': '': code)) > 0;
      return 'time';
    when %scan('LIKE(': %scanrpl(' ': '': code)) > 0;
      definition = code;
      definition = %subst(
        definition: %scan('LIKE(': definition) + 5
      );
      definition = %subst(
        definition: 1: %scan(')': definition) - 1
      );
      likeVariable = fetchStoredVariable(definition: scope);
      return likeVariable.type;
    when %scan('LIKEDS(': %scanrpl(' ': '': code)) > 0;
      definition = code;
      definition = %subst(
        definition: %scan('LIKEDS(': definition) + 7
      );
      definition = %subst(
        definition: 1: %scan(')': definition) - 1
      );
      likeVariable = fetchStoredVariable(definition: scope);
      return likeVariable.type;
    other;
      return *blanks;
  endsl;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableArraySizeFromCode export;
  dcl-pi *n like(t_variable.arraySize);
    code like(t_longLineOfCode) const;
    scope like(t_variable.scope) const;
  end-pi;

  dcl-s snippet like(t_longLineOfCode);
  dcl-s arraySize packed(10);
  dcl-ds basedUpon likeds(t_variable);

  select;
    when %scan('DIM(': %scanrpl(' ': '': toUpperCase(code))) > 0;
      // get rid of blanks
      snippet = %scanrpl(' ': '': toUpperCase(code));
      // get rid of everything up to dim(x), including dim(
      snippet = %subst(
                  snippet:
                  %scan(
                    'DIM(':
                    snippet
                  ) + 4
                );
      // get rid of the closing bracket, and everything after
      snippet = %subst(
                  snippet:
                  1:
                  %scan(')': snippet) - 1
                );

      monitor;
        arraySize = %dec(snippet: 10: 0);
      on-error;

        basedUpon = fetchStoredVariable(snippet: scope);
        if basedUpon.type = 'constant';
          monitor;
            arraySize = %dec(basedUpon.definition: 10: 0);
          on-error;
            arraySize = 1;
          endmon;
        else;
          arraySize = 1;
        endif;

      endmon;

    when %scan('OCCURS(': %scanrpl(' ': '': toUpperCase(code))) > 0;
      // get rid of blanks
      snippet = %scanrpl(' ': '': toUpperCase(code));
      // get rid of everything up to occurs(x), including occurs(
      snippet = %subst(
                  snippet:
                  %scan(
                    'OCCURS(':
                    snippet
                  ) + 7
                );
      // get rid of the closing bracket, and everything after
      snippet = %subst(
                  snippet:
                  1:
                  %scan(')': snippet) - 1
                );

      monitor;
        arraySize = %dec(snippet: 10: 0);
      on-error;

        basedUpon = fetchStoredVariable(snippet: scope);
        if basedUpon.type = 'constant';
          monitor;
            arraySize = %dec(basedUpon.definition: 10: 0);
          on-error;
            arraySize = 1;
          endmon;
        else;
          arraySize = 1;
        endif;

      endmon;

    other;

      arraySize = 0;

  endsl;

  return arraySize;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchDataStructureArraySizeFromCode export;
  dcl-pi *n like(t_variable.arraySize);
    code like(t_longLineOfCode) const;
    scope like(t_variable.scope) const;
  end-pi;

  dcl-s snippet like(t_longLineOfCode);
  dcl-s arraySize packed(10);
  dcl-ds basedUpon likeds(t_variable);

  select;
    when %scan('DIM(': %scanrpl(' ': '': toUpperCase(code))) > 0;
      // get rid of blanks
      snippet = %scanrpl(' ': '': toUpperCase(code));
      // get rid of everything up to dim(x), including dim(
      snippet = %subst(
                  snippet:
                  %scan(
                    'DIM(':
                    snippet
                  ) + 4
                );
      // get rid of the closing bracket, and everything after
      snippet = %subst(
                  snippet:
                  1:
                  %scan(')': snippet) - 1
                );

      monitor;
        arraySize = %dec(snippet: 10: 0);
      on-error;

        basedUpon = fetchStoredVariable(snippet: scope);
        if basedUpon.type = 'constant';
          monitor;
            arraySize = %dec(basedUpon.definition: 10: 0);
          on-error;
            arraySize = 1;
          endmon;
        else;
          arraySize = 1;
        endif;

      endmon;

    when %scan('OCCURS(': %scanrpl(' ': '': toUpperCase(code))) > 0;
      // get rid of blanks
      snippet = %scanrpl(' ': '': toUpperCase(code));
      // get rid of everything up to occurs(x), including occurs(
      snippet = %subst(
                  snippet:
                  %scan(
                    'OCCURS(':
                    snippet
                  ) + 7
                );
      // get rid of the closing bracket, and everything after
      snippet = %subst(
                  snippet:
                  1:
                  %scan(')': snippet) - 1
                );

      monitor;
        arraySize = %dec(snippet: 10: 0);
      on-error;

        basedUpon = fetchStoredVariable(snippet: scope);
        if basedUpon.type = 'constant';
          monitor;
            arraySize = %dec(basedUpon.definition: 10: 0);
          on-error;
            arraySize = 1;
          endmon;
        else;
          arraySize = 1;
        endif;

      endmon;

    other;

      arraySize = 0;

  endsl;

  return arraySize;

end-proc;

//-----------------------------------------------------------------------

dcl-proc storeVariable export;
  dcl-pi *n;
    variable likeds(t_variable) const;
    parentDataStructure like(t_variable.name) const;
    qualifiedDataStructure ind options(*nopass) const;
  end-pi;

  dcl-s qualified char(1);

  if variable.type = *blanks;

    exec sql
      INSERT INTO replvars
        (variable_name, variable_scope)
      VALUES
        (:variable.name, :variable.scope);

    return;

  endif;

  // if we're a data structure which is like another data structure,
  // we can just copy it
  if %scan('LIKEDS(': %trim(toUpperCase(variable.definition))) > 0;

    copyDataStructureDefinitions(variable);

  elseif parentDataStructure <> *blanks;

    exec sql
      INSERT INTO replvars
        (variable_name, variable_type,
           parent_data_structure, array_size,
           declaration_order, variable_scope, definition,
           defined, is_template)
        (SELECT :variable.name, :variable.type,
                  :parentDataStructure, NULLIF(:variable.arraySize, 0),
                  COALESCE(
                    MAX(this_scope.declaration_order),
                    MAX(main_scope.declaration_order),
                    0) + 1,
                  :variable.scope, NULLIF(:variable.definition, ''),
                  'Y', :variable.template
           FROM (VALUES(1)) AS dummy(value)
           LEFT JOIN replvars AS this_scope
                ON this_scope.session_id = (QSYS2.JOB_NAME)
                AND this_scope.parent_data_structure
                      = :parentDataStructure
                AND this_scope.variable_scope = :variable.scope
           LEFT JOIN replvars AS main_scope
                ON main_scope.session_id = (QSYS2.JOB_NAME)
                AND main_scope.parent_data_structure
                      = :parentDataStructure
                AND main_scope.variable_scope = 'MAIN');

  else;

    if %parms >= %parmnum(qualifiedDataStructure);

      if qualifiedDataStructure;
        qualified = 'Y';
      else;
        qualified = 'N';
      endif;

      exec sql
        INSERT INTO replvars
          (variable_name, variable_type,
             is_qualified, array_size,
             variable_scope, definition,
             defined, is_template)
        VALUES
          (:variable.name, :variable.type,
             :qualified, NULLIF(:variable.arraySize, 0),
             :variable.scope, NULLIF(:variable.definition, ''),
             'Y', :variable.template);

    else;

      exec sql
        INSERT INTO replvars
          (variable_name, variable_type,
           array_size,
           variable_scope, definition,
           defined, is_template)
        VALUES
          (:variable.name, :variable.type,
             NULLIF(:variable.arraySize, 0),
             :variable.scope, :variable.definition,
             'Y', :variable.template);

    endif;

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc copyDataStructureDefinitions export;
  dcl-pi *n;
    variable likeds(t_variable) const;
  end-pi;

  dcl-s copyDataStructure like(t_variable.name);

  copyDataStructure = toUpperCase(variable.definition);
  copyDataStructure = %scanrpl('LIKEDS':'':copyDataStructure);
  copyDataStructure = %scanrpl('(':'':copyDataStructure);
  copyDataStructure = %scanrpl(')':'':copyDataStructure);
  copyDataStructure = %trim(toUpperCase(copyDataStructure));

  // see if it exists in the current scope
  exec sql
    INSERT INTO replvars
      (variable_name, variable_type, is_qualified, array_size,
       definition, variable_scope, is_template,
       defined)
    SELECT :variable.name, 'datastruct',
           /* DS's declared LIKEDS are qualified for free */
           'Y', NULLIF(:variable.arraySize, 0),
           NULLIF(:variable.definition, ''), :variable.scope,
           :variable.template, COALESCE(defined, 'N')
      FROM replvars
     WHERE session_id = (QSYS2.JOB_NAME)
           AND UPPER(variable_name) = UPPER(:copyDataStructure)
           AND variable_scope = :variable.scope;

  if sqlstt = '02000';

    // if not, try the main scope
    exec sql
      INSERT INTO replvars
        (variable_name, variable_type, is_qualified, array_size,
         definition, variable_scope, is_template,
         defined)
      SELECT :variable.name, 'datastruct',
             /* DS's declared LIKEDS are qualified for free */
             'Y', NULLIF(:variable.arraySize, 0),
             NULLIF(:variable.definition, ''), :variable.scope,
             :variable.template, COALESCE(defined, 'N')
        FROM replvars
       WHERE session_id = (QSYS2.JOB_NAME)
             AND UPPER(variable_name) = UPPER(:copyDataStructure)
             AND variable_scope = 'MAIN';

    if sqlstt = '02000';

      // else, we can't see it.
      exec sql
        INSERT INTO replvars
          (variable_name, variable_type, is_qualified, array_size,
           definition, variable_scope, is_template,
           defined)
        VALUES (:variable.name, 'datastruct',
               /* DS's declared LIKEDS are qualified for free */
               'Y', NULLIF(:variable.arraySize, 0),
               NULLIF(:variable.definition, ''), :variable.scope,
               :variable.template, 'N');

      endif;
    endif;

  // see if the defintion exists in the current scope
  exec sql
    INSERT INTO replvars
      (variable_name, variable_type, parent_data_structure, array_size,
       definition, declaration_order, variable_scope, is_template,
       defined)
    SELECT variable_name, variable_type, :variable.name, array_size,
           definition, declaration_order, :variable.scope,
           :variable.template, defined
      FROM replvars
     WHERE session_id = (QSYS2.JOB_NAME)
           AND UPPER(parent_data_structure) = UPPER(:copyDataStructure)
           AND variable_scope = :variable.scope;

  if sqlstt = '02000';

    // else, try the main scope
    exec sql
      INSERT INTO replvars
        (variable_name, variable_type, parent_data_structure, array_size,
         definition, declaration_order, variable_scope, is_template,
         defined)
      SELECT variable_name, variable_type, :variable.name, array_size,
             definition, declaration_order, :variable.scope,
             :variable.template, defined
        FROM replvars
       WHERE session_id = (QSYS2.JOB_NAME)
             AND UPPER(parent_data_structure) = UPPER(:copyDataStructure)
             AND variable_scope = 'MAIN';

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchStoredVariable export;
  dcl-pi *n likeds(t_variable);
    variableName like(t_variable.name) const;
    scope like(t_variable.scope) const;
  end-pi;

  dcl-ds variable likeds(t_variable);

  variable.id = 0;
  variable.name = variableName;
  variable.arraySize = 0;
  variable.parentName = *blanks;
  variable.parentArraySize = 0;

  if %scan('*IN': toUpperCase(%trim(variableName))) = 1;
    variable.type = '*indicator';
    return variable;
  endif;

  // check the exact name first
  exec sql
    SELECT variable_name,
            CAST(variable_type AS CHAR(10)),
            COALESCE(array_size, 0),
            COALESCE(parent_data_structure, ''),
            0,
            variable_scope,
            COALESCE(definition, ''),
            isTemplate,
            defined,
            variable_id,
            is_used
       INTO :variable
       FROM replvars
      WHERE session_id = (QSYS2.JOB_NAME)
           AND UPPER(variable_name) = UPPER(:variableName)
           AND variable_scope = :scope
           AND parent_data_structure IS NULL
      ORDER BY parent_data_structure
      LIMIT 1;

  if sqlstt = '00000';
    return variable;
  endif;

  // then check for it being part of a DS
  exec sql
     WITH p(parentName, parentQualified, parentSize)
          AS (SELECT variable_name, is_qualified, array_size
                FROM replvars
               WHERE session_id = (QSYS2.JOB_NAME))

    SELECT CAST(CASE WHEN parentQualified = 'Y'
                        THEN TRIM(parent_data_structure)
                             CONCAT '.' CONCAT variable_name
                      ELSE variable_name END AS CHAR(70)),
            CAST(variable_type AS CHAR(10)),
            COALESCE(array_size, 0),
            COALESCE(parent_data_structure, ''),
            COALESCE(parentSize, 0),
            variable_scope,
            COALESCE(definition, ''),
            isTemplate,
            defined,
            variable_id,
            is_used
       INTO :variable
       FROM replvars
            LEFT JOIN p
              ON parent_data_structure = parentName
      WHERE session_id = (QSYS2.JOB_NAME)
           AND (UPPER(variable_name) = UPPER(:variableName)
                OR UPPER(TRIM(parent_data_structure)
                         CONCAT '.'
                         CONCAT TRIM(variable_name))
                   = UPPER(:variableName))
           AND variable_scope = :scope;

  if variable.type = *blanks and scope <> 'MAIN';
    return fetchStoredVariable(variableName: 'MAIN');
  endif;

  return variable;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableNameFromStatement export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) const;
  end-pi;

  dcl-s variableName like(t_variable.name);

  monitor;

    // Find the first =, -=, or += symbol
    // Cut off everything from that point onwards
    variableName =
      %subst(
        %trim(
          code
        ):
        1:
        %min(
          nonZero(%scan('=': %trim(code))):
          nonZero(%scan('-=': %trim(code))):
          nonZero(%scan('+=': %trim(code)))
        ) - 1
      );

      // If we still have blanks,
      // we only want the last term of the string
      if %scan(' ': %trim(variableName)) <> 0;
        variableName =
          %trim(
            %subst(
              %trim(
                variableName
              ):
              %scanr(' ': %trim(variableName))
            )
          );
      endif;

      // Get rid of any array markers
      // TODO
      // We need to support
      // dcl-ds a dim(3) qualified;
      //   b char(1) dim(5);
      // end-ds;
      //dow %scan('(': variableName) > 0;
      //  variableName =
      //    %subst(variableName: 1: %scan('(': variableName) - 1)
      //    + %subst(variableName: %scan(')': variableName) + 1);
      //enddo;

      return variableName;

    on-error;

      return *blanks;

    endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableNameFromReplPrintStatement export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) value;
  end-pi;

  dcl-s variableName like(t_variable.name);

  monitor;

    // cut off the last semicolon
    // cut off the last brace
    // cut off replPrint(

    code = %trim(code);    
    code = %trim(%subst(code: 1: %len(code) - 1));
    code = %trim(%subst(code: 1: %len(code) - 1));
    variableName = %trim(%subst(code: 11));

    return variableName;

    on-error;

      return *blanks;

    endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableNameFromReplEqualsStatement export;
  dcl-pi *n like(t_variable.name);
    code like(t_longLineOfCode) value;
  end-pi;

  dcl-s variableName like(t_variable.name);

  monitor;

    // cut off the last semicolon
    // cut off the last brace
    // cut off replEquals(
    // cut off everything up to and including the colon    

    code = %trim(code);    
    code = %trim(%subst(code: 1: %len(code) - 1));
    code = %trim(%subst(code: 1: %len(code) - 1));
    code = %trim(%subst(code: 12));
    variableName = %trim(%subst(code: %scan(':': code) + 1));

    return variableName;

    on-error;

      return *blanks;

    endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchVariableExpectedValueFromReplEqualsStatement export;
  dcl-pi *n like(t_longLineOfCode);
    code like(t_longLineOfCode) value;
  end-pi;

  monitor;

    // cut off the last semicolon
    // cut off the last brace
    // cut off replEquals(
    // cut off everything after and including the final colon    
    // turn single quotes into double quotes

    code = %trim(code);    
    code = %trim(%subst(code: 1: %len(code) - 1));
    code = %trim(%subst(code: 1: %len(code) - 1));
    code = %trim(%subst(code: 12));
    code = %trim(%subst(code: 1: %scanr(':': code) - 1));

    return code;

    on-error;

      return *blanks;

    endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc nonZero export;
  dcl-pi *n packed(4);
    number packed(4) const;
  end-pi;

  if number = 0;
    return 9999;
  else;
    return number;
  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareListOfDataStructureFields export;
  dcl-pi *n;
    dataStructureName like(t_variable.name) const;
    scope like(t_variable.scope) const;
  end-pi;

  exec sql
    DECLARE dataStructureFields CURSOR FOR
     WITH p(parentName, parentQualified, parentSize)
          AS (SELECT variable_name, is_qualified, array_size
                FROM replvars
               WHERE session_id = (QSYS2.JOB_NAME))

     SELECT DISTINCT
            CAST(CASE WHEN parentQualified = 'Y'
                        THEN TRIM(parent_data_structure)
                             CONCAT '.' CONCAT variable_name
                      ELSE variable_name END AS CHAR(70)),
            CAST(variable_type AS CHAR(10)),
            COALESCE(array_size, 0),
            COALESCE(parentName, ''),
            COALESCE(parentSize, 0),
            variable_scope,
            COALESCE(definition, ''),
            is_template,
            defined,
            variable_id,
            is_used,
            declaration_order
       FROM replvars
            JOIN p
              ON parent_data_structure = parentName
      WHERE session_id = (QSYS2.JOB_NAME)
            AND UPPER(parent_data_structure)
                 = UPPER(:dataStructureName)
            AND variable_scope = :scope
      ORDER BY declaration_order;

  exec sql
    CLOSE dataStructureFields;

  exec sql
    OPEN dataStructureFields;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchedDataStructureFields export;
  dcl-pi *n ind;
    variable likeds(t_variable);
  end-pi;

  dcl-s order packed(5);

  exec sql
    FETCH NEXT FROM dataStructureFields INTO :variable, :order;

  if (sqlstt <> '00000');
    exec sql CLOSE dataStructureFields;
    return *off;
  endif;

  return sqlstt = '00000';

end-proc;

//-----------------------------------------------------------------------

dcl-proc markVariableAsUsed export;
  dcl-pi *n;
    variableId like(t_variable.id) const;
   end-pi;

   exec sql
     UPDATE replvars
     SET is_used = 'Y'
     WHERE variable_id = :variableId;

   dou sqlstt <> '00000';

     exec sql
       UPDATE replvars
       SET is_used = 'Y'
       WHERE session_id = (QSYS2.JOB_NAME)
       AND variable_name IN (
         SELECT parent_data_structure
         FROM replvars
         WHERE session_id = (QSYS2.JOB_NAME)
         AND is_used = 'Y'
       )
       AND is_used <> 'Y';

   enddo;

   dou sqlstt <> '00000';

     exec sql
       UPDATE replvars
       SET is_used = 'Y'
       WHERE session_id = (QSYS2.JOB_NAME)
       AND parent_data_structure IN (
         SELECT variable_name
         FROM replvars
         WHERE session_id = (QSYS2.JOB_NAME)
         AND is_used = 'Y'
       )
       AND is_used <> 'Y';

   enddo;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareListOfVariables export;

  exec sql
    DECLARE listOfVariables CURSOR FOR
     WITH p(parentName, parentQualified, parentSize)
          AS (SELECT variable_name, is_qualified, array_size
                FROM replvars
               WHERE session_id = (QSYS2.JOB_NAME))

     SELECT DISTINCT
            CAST(CASE WHEN COALESCE(parentQualified, 'N') = 'Y'
                        THEN TRIM(parent_data_structure)
                             CONCAT '.' CONCAT variable_name
                      ELSE variable_name END AS CHAR(70)),
            CAST(variable_type AS CHAR(10)),
            COALESCE(array_size, 0),
            COALESCE(parentName, ''),
            COALESCE(parentSize, 0),
            variable_scope,
            COALESCE(definition, ''),
            is_template,
            defined,
            variable_id,
            is_used
       FROM replvars
            LEFT JOIN p
              ON parent_data_structure = parentName
      WHERE session_id = (QSYS2.JOB_NAME)
      AND is_used = 'Y'
      ORDER BY variable_id;

  exec sql
    CLOSE listOfVariables;

  exec sql
    OPEN listOfVariables;

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchListOfVariables export;
  dcl-pi *n ind;
    variable likeds(t_variable);
  end-pi;

  exec sql
    FETCH NEXT FROM listOfVariables INTO :variable;

  if (sqlstt <> '00000');
    exec sql CLOSE listOfVariables;
    return *off;
  endif;

  return (sqlstt = '00000');

end-proc;

//-----------------------------------------------------------------------

dcl-proc fetchProcedureNameFromStatement export;
  dcl-pi *n like(t_variable.scope);
    code like(t_longLineOfCode) const;
  end-pi;

  dcl-s procedureName like(t_longLineOfCode);

  procedureName = %trim(toUpperCase(code));

  procedureName = %trim(%scanrpl('DCL-PROC ': '': procedureName));
  if %scan(' ': procedureName) <> 0;
    procedureName = %subst(procedureName: 1: %scan(' ': procedureName));
    return procedureName;
  endif;
  procedureName = %scanrpl(';': '': procedureName);

  return %trim(procedureName);

end-proc;

//-----------------------------------------------------------------------

dcl-proc procedureDeclarationFound export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
    %scan('DCL-PROC': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc procedureInterfaceStart export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
    %scan('DCL-PI': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc procedureInterfaceEnd export;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
    %scan('END-PI': %trim(toUpperCase(code))) > 0;

end-proc;

//-----------------------------------------------------------------------

dcl-proc toUpperCase export;
  dcl-pi *n varchar(512);
    lowerString varchar(512) const;
  end-pi;
  dcl-s upperString varchar(512);
  exec sql SET :upperString = UPPER(RTRIM(:lowerString));
  return upperString;
end-proc;

//-----------------------------------------------------------------------

