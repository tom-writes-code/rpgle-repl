**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

//-----------------------------------------------------------------------

/include repl_cmpl
/include repl_vars
/include repl_eval
/include repl_pseu
/include repl_ins
/include repl_usr

/include repl_gen

//-----------------------------------------------------------------------

dcl-proc createGeneratedSourceObject export;

  refreshGeneratedSourceObject();

  createSqlAlias();

  setGeneratedSourceObjectControlOptions();

  setGeneratedSourceObjectReferenceSource();

  addPseudoCodeToGeneratedSourceObject();

  replResultEvaluationHelpers();

end-proc;

//-----------------------------------------------------------------------

dcl-proc refreshGeneratedSourceObject export;

  monitor;

    runCommand('CRTSRCPF FILE(&1/&2) RCDLEN(128) MBR(&3) ' +
               'TEXT(&4) MAXMBRS(*NOMAX) SIZE(*NOMAX)':
                c_generatedSourceLibrary:
                c_generatedSourceFile:
                c_generatedSourceMember:
                '''repl.rpg generated source object''');

  on-error;

    monitor;

      runCommand('ADDPFM FILE(&1/&2) MBR(&3)':
                  c_generatedSourceLibrary:
                  c_generatedSourceFile:
                  c_generatedSourceMember);

    on-error;

      runCommand('CLRPFM FILE(&1/&2) MBR(&3)':
                  c_generatedSourceLibrary:
                  c_generatedSourceFile:
                  c_generatedSourceMember);

    endmon;

  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc setGeneratedSourceObjectControlOptions;

  dcl-ds controlStatement likeds(t_controlStatement);
  dcl-s i packed(1);

  controlStatement = fetchSessionControlStatement();

  for i = 1 to c_control_statements;

    if controlStatement.statement(i) <> *blanks;
      insertSingleLineOfGeneratedCode(controlStatement.statement(i));
    endif;

  endfor;

  insertSingleLineOfGeneratedCode(*blanks);

end-proc;

//-----------------------------------------------------------------------

dcl-proc setGeneratedSourceObjectReferenceSource;

  insertSingleLineOfGeneratedCode
    ('/include qrpgleref,repl_hlpr');

end-proc;

//-----------------------------------------------------------------------

dcl-proc addPseudoCodeToGeneratedSourceObject;
  dcl-pi *n;
    includeSource likeds(t_referenceSource) options(*nopass);
    piCurrentScope like(t_variable.scope) options(*nopass);
  end-pi;

  dcl-ds lineOfCode likeds(t_lineOfCode);
  dcl-s triggerType like(t_triggerType);
  dcl-ds variable likeds(t_variable);
  dcl-s parentDataStructure like(t_variable.name) dim(99);
  dcl-s continuousLineOfCode like(t_longLineOfCode);
  dcl-s mainlineCode ind inz(*on);
  dcl-s currentScope like(t_variable.scope);
  dcl-s isProcedureInterface ind inz(*off);
  dcl-s replCode ind inz(*on);
  dcl-ds referenceSource likeds(t_referenceSource);
  dcl-s dsNestingLimit packed(2) inz(1);

  if %parms() >= %parmnum(includeSource);
    replCode = *off;
  endif;

  if replCode;
    insertSingleLineOfGeneratedCode(*blanks);
    prepareFetchLinesOfPseudoCode();
  else;
    prepareFetchLinesOfPseudoCode(includeSource);
  endif;

  if %parms() >= %parmnum(piCurrentScope);
    currentScope = piCurrentScope;
  else;
    currentScope = 'MAIN';
  endif;

  continuousLineOfCode = *blanks;

  dow fetchLineOfPseudoCode(lineOfCode: replCode);

    lineOfCode = stripComments(
      lineOfCode: 
      %scan('exec sql': %lower(%trim(continuousLineOfCode)) + ' ' 
                        + %lower(lineOfCode.code)) > 0
    );

    if replCode
    and mainlineCode
    and codeIsSubProcedureOrSubRoutine(lineOfCode.code);
      mainlineCode = *off;
      setGeneratedSourceObjectReturn();
    endif;

    if replCode;
      insertSingleLineOfGeneratedCode(lineOfCode.code: lineOfCode.line);
    endif;

    // ignore comments
    if codeIsComment(lineOfCode.code)
    or lineOfCode.code = *blanks;
      iter;
    endif;

    // repl goes out the window if we hit fixed format.
    // ignore it and move on.
    if codeIsFixedFormat(lineOfCode.code);
      continuousLineOfCode = *blanks;
      iter;
    endif;

    // weird stuff is going to start happening as soon as
    // we hit an include statement. Strap in!
    if codeIsIncludeStatement(lineOfCode.code);
      referenceSource = separateReferenceSource(lineOfCode.code);
      addPseudoCodeToGeneratedSourceObject(referenceSource:currentScope);
      continuousLineOfCode = *blanks;
      // our recursive call will have ruined us. Pick up where we left off
      // unless we're back to mainline code, in which case we're there.
      if %parms() >= %parmnum(includeSource);
        prepareFetchLinesOfPseudoCode(includeSource: lineOfCode.line);
      endif;
      iter;
    endif;

    // add the latest pseudo-line to what we have.
    continuousLineOfCode = %trim(continuousLineOfCode)
                          + ' ' + lineofCode.code;

    // if there isn't a semi-colon, keep reading.
    if not endOfFreeFormatLineFound(continuousLineOfCode);
      iter;
    endif;

    // check for dcl-c
    if constantDefinitionFound(continuousLineOfCode);
      storeConstantDefinition(
        continuousLineOfCode:
        currentScope
      );
    endif;

    // check for dcl-s
    if variableDefinitionFound(continuousLineOfCode);
      storeVariableDefinition(
        continuousLineOfCode:
        *blanks:
        currentScope
      );
    endif;

    // check for dcl-ds

    // > dcl-ds someDs;
    //     someVar char(1);
    //   end-ds;
    if dataStructureStartFound(continuousLineOfCode)
    and %scan('LIKEDS': toUpperCase(continuousLineOfCode)) = 0;
      dsNestingLimit += 1;
      parentDataStructure(dsNestingLimit)
        = storeDataStructureDefinition(
            continuousLineOfCode:
            currentScope:
            parentDataStructure(dsNestingLimit-1)
          );

    //   dcl-ds someDs qualified;
    //     someVar char(1);
    // > end-ds;
    elseif dataStructureEndFound(continuousLineOfCode);
      parentDataStructure(dsNestingLimit) = *blanks;
      dsNestingLimit -= 1;

    //   dcl-ds someDs qualified;
    // >   someOtherDs likeds(t_someOtherDs);
    //   end-ds;
    elseif %scan('LIKEDS': toUpperCase(continuousLineOfCode)) <> 0
    and not dataStructureStartFound(continuousLineOfCode);
      storeDataStructureDefinition(
        continuousLineOfCode:
        currentScope:
        parentDataStructure(dsNestingLimit)
      );

    // > dcl-ds someDs likeds(t_someOtherDs);
    elseif %scan('LIKEDS': toUpperCase(continuousLineOfCode)) <> 0
    and dataStructureStartFound(continuousLineOfCode);
      dsNestingLimit += 1;
      storeDataStructureDefinition(
        continuousLineOfCode:
        currentScope:
        parentDataStructure(dsNestingLimit - 1)
      );
      dsNestingLimit -= 1;

    //   dcl-ds someDs qualified;
    // >   someVar char(1);
    //   end-ds;
    elseif dsNestingLimit > 1
    and not dataStructureEndFound(continuousLineOfCode);
      
      storeVariableDefinition(
        continuousLineOfCode:
        parentDataStructure(dsNestingLimit):
        currentScope
      );

    endif;

    // check for dcl-proc
    if procedureDeclarationFound(continuousLineOfCode);
      currentScope
        = fetchProcedureNameFromStatement(continuousLineOfCode);
    endif;

    // check for dcl-pi
    if procedureInterfaceStart(continuousLineOfCode)
    and not procedureInterfaceEnd(continuousLineOfCode);
      isProcedureInterface = *on;
    elseif procedureInterfaceEnd(continuousLineOfCode);
      isProcedureInterface = *off;
    elseif isProcedureInterface;
      storeVariableDefinition(
        continuousLineOfCode:
        *blanks:
        currentScope
      );
    endif;

    // look for something we can evaluate
    if freeFormatEvaluationFound(continuousLineOfCode: triggerType);
      if triggerType = c_setValueStatement;
        variable.name
          = fetchVariableNameFromStatement(continuousLineOfCode);
        variable = fetchStoredVariable(variable.name: currentScope);
      endif;
      evaluateLineOfPseudoCode
        (lineOfCode.line: triggerType: variable: currentScope);
    endif;

    // reset the line for the next process
    continuousLineOfCode = *blanks;

  enddo;

  if replCode;

    insertSingleLineOfGeneratedCode(*blanks);

    if mainlineCode;
      setGeneratedSourceObjectReturn();
    endif;

  endif;

end-proc;

//-----------------------------------------------------------------------

dcl-proc setGeneratedSourceObjectReturn;

  insertSingleLineOfGeneratedCode('*inlr = *on;');
  insertSingleLineOfGeneratedCode('return;');
  insertSingleLineOfGeneratedCode(*blanks);

end-proc;

//-----------------------------------------------------------------------

dcl-proc codeIsIncludeStatement;
  dcl-pi *n ind;
    code like(t_longLineOfCode) const;
  end-pi;

  return
     %scan('/INCLUDE': %trim(toUpperCase(code))) = 1
  or %scan('/COPY': %trim(toUpperCase(code))) = 1;

end-proc;

//-----------------------------------------------------------------------

dcl-proc codeIsSubProcedureOrSubRoutine;
  dcl-pi *n ind;
    code like(t_lineOfCode.code) const;
  end-pi;

  return
     %scan('DCL-PROC': %trim(toUpperCase(code))) > 0
  or %scan('BEGSR': %trim(toUpperCase(code))) > 0;

end-proc;

//-----------------------------------------------------------------------


