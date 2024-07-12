**FREE

ctl-opt datedit(*ymd) option(*nodebugio : *srcstmt)
        fixnbr(*zoned : *inputpacked) noMain;

//-----------------------------------------------------------------------

/include repl_pm
/include repl_pseu
/include repl_usr

/include repl_cmpl

//-----------------------------------------------------------------------

dcl-ds t_compilationErrorDetails qualified template;
  code char(7);
  severity packed(2);
  line packed(4);
  text char(80);
end-ds;

//-----------------------------------------------------------------------

dcl-proc compileGeneratedSourceObject export;
  dcl-pi *n;
    showModuleInstructions ind const;
    piBatchMode ind const options(*omit: *nopass);
    piUserServicePrograms likeds(t_serviceProgram) dim(10) 
      const options(*omit: *nopass: *exact);
  end-pi;

  dcl-s promptIt char(1);
  dcl-ds serviceProgram likeds(t_serviceProgram);
  dcl-s boundServicePrograms varchar(1000);
  dcl-s batchMode ind;
  dcl-ds userServicePrograms likeds(t_serviceProgram) dim(10);
  dcl-s i packed(2);
  dcl-ds thrownError likeds(t_thrownError);

  if %passed(piBatchMode);
    batchMode = piBatchMode;
  else;
    batchMode = *off;
  endif;

  if %parms >= %parmnum(piUserServicePrograms) 
  and %addr(piUserServicePrograms) <> *null;
    userServicePrograms = piUserServicePrograms;
  endif;

  if showModuleInstructions and not batchMode;
    promptIt = '?';
  endif;

  monitor;
    runCommand(promptIt +
               'CRTSQLRPGI OBJ(&1/&2) SRCFILE(&3/&4) SRCMBR(&5) ' +
               'OBJTYPE(*MODULE) DBGVIEW(*SOURCE) DATFMT(*ISO) ' +
               'RPGPPOPT(*LVL2) COMMIT(*NONE)':
                 c_generatedSourceLibrary:
                 c_generatedModule:
                 c_generatedSourceLibrary:
                 c_generatedSourceFile:
                 c_generatedSourceMember);
  on-error;
    printCompilationErrors();
    thrownError.errorCode = c_error_module_not_created;
    throw(thrownError);
  endmon;

  boundServicePrograms = '*LIBL/REPL_HLPR';

  prepareUserBoundServicePrograms();
  dow userBoundServiceProgram(serviceProgram: promptIt: batchMode);

    if serviceProgram.name = *blanks;
      iter;
    endif;

    // If the user provided this, use whatever they provided.
    i = %lookup(serviceProgram.name: userServicePrograms(*).name);
    if i <> 0;
      iter;
    endif;

    boundServicePrograms
      = %trim(boundServicePrograms)
         + ') ('
         + %trim(serviceProgram.library)
         + '/'
         + %trim(serviceProgram.name);

  enddo;

  for i = 1 to 10;
    // Don't do anything with a blank name.
    // These might be off sequence because of what
    //  happened above.
    if userServicePrograms(i).name = *blanks;
      iter;
    endif;

    boundServicePrograms
      = %trim(boundServicePrograms)
         + ') ('
         + %trim(userServicePrograms(i).library)
         + '/'
         + %trim(userServicePrograms(i).name);
  endfor;

  if batchMode;
    promptIt = *blanks;
  endif;

  monitor;
    runCommand(promptIt +
               'CRTPGM PGM(&1/&2) MODULE(&1/&3) BNDSRVPGM(('
                 + %trim(boundServicePrograms) + '))':
                 c_generatedSourceLibrary:
                 c_generatedProgram:
                 c_generatedModule);
    // Success? Then leave!
    return;
  on-error;
    thrownError.errorCode = c_error_program_not_created;
    throw(thrownError);
  endmon;

end-proc;

//-----------------------------------------------------------------------

dcl-proc printCompilationErrors;

  dcl-ds compilationErrorDetails likeds(t_compilationErrorDetails);

  prepareCompilationErrorsList();

  dow replCompilationErrorFound(compilationErrorDetails);

    // less than severity 30 passes for a warning, so skip it
    // non-zero line means it isn't from something our user did
    // ... except, maybe, I guess it might because our source re-uses
    // sequence numbers a lot, but let's just hope for the best on that
    // for now
    if compilationErrorDetails.severity > 20
    and compilationErrorDetails.line <> 0;

      exec sql
        INSERT INTO replrslt
          (line_number, result_number, result_description)
          (SELECT :compilationErrorDetails.line,
                  COALESCE(MAX(result_number), 0)+1,
                  trim(:compilationErrorDetails.text)
                    CONCAT ' ('
                    CONCAT trim(:compilationErrorDetails.code)
                    CONCAT ', SEVERITY '
                    CONCAT trim(:compilationErrorDetails.severity)
                    CONCAT ')'
             FROM replrslt
            WHERE session_id = QSYS2.JOB_NAME
              AND line_number = :compilationErrorDetails.line);

    endif;

  enddo;

on-exit;

  exec sql CLOSE repl_compilationErrors;

end-proc;

//-----------------------------------------------------------------------

dcl-proc prepareCompilationErrorsList;

  exec sql
    DECLARE repl_compilationErrors CURSOR FOR
    WITH                                                                
    start_of_rpg_diagnostic_messages AS (                                   
      SELECT ordinal_position                                           
        FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                          
               JOB_NAME => QSYS2.JOB_NAME,                              
               SPOOLED_FILE_NAME =>'REPL_MOD'))                         
      WHERE spooled_data LIKE                                             
         '%A d d i t i o n a l   D i a g n o s t i c   M e s s a g e s%'
    ),                                                                  
    end_of_rpg_diagnostic_messages AS (                                     
      SELECT ordinal_position                                           
        FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                          
               JOB_NAME => QSYS2.JOB_NAME,                              
               SPOOLED_FILE_NAME =>'REPL_MOD'))                         
      WHERE spooled_data LIKE                                             
         '%* * * * *   E N D   O F   A D D I T I O N A L   D I A G N O S T I C%'
    ),                                                               
    start_of_sql_diagnostic_messages AS (                                   
      SELECT ordinal_position                                           
        FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                          
               JOB_NAME => QSYS2.JOB_NAME,                              
               SPOOLED_FILE_NAME =>'REPL_MOD'))                         
      WHERE spooled_data LIKE                                             
         '%MSG ID  SEV  RECORD  TEXT%'
    ),                                                                  
    end_of_sql_diagnostic_messages AS (                                     
      SELECT ordinal_position                                           
        FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                          
               JOB_NAME => QSYS2.JOB_NAME,                              
               SPOOLED_FILE_NAME =>'REPL_MOD'))                         
      WHERE spooled_data LIKE                                             
         '%Message Summary%'
    ),
    sql_line_translation AS (
      SELECT cast(trim(substring(spooled_data, 3, 4)) AS dec(4, 0)) as sql_record,
             cast(trim(substring(spooled_data, 92, 4)) AS dec(4, 0)) as rpg_line
        FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                    
               JOB_NAME => QSYS2.JOB_NAME,                        
               SPOOLED_FILE_NAME =>'REPL_MOD'))  
       // ignore anything containing not-integers or is just blank 
       WHERE replace(translate(trim(substring(
               spooled_data, 3, 4)), '0', '123456789', '0'), '0', '') = '' 
       AND replace(translate(trim(substring(
               spooled_data, 92, 4)), '0', '123456789', '0'), '0', '') = ''  
       AND trim(substring(spooled_data, 3, 4)) <> ''
       AND trim(substring(spooled_data, 92, 4)) <> ''                   
    )                                                                  
    SELECT                                                              
           cast(substring(spooled_data, 2, 7) as char(7)) as message_id,  
           cast(substring(spooled_data, 10, 2) as dec(2, 0)) as severity, 
           cast(substring(spooled_data, 20, 4) as dec(4, 0)) as line,     
           cast(substring(spooled_data, 28, 80) as char(80)) as error_text
      FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                            
             JOB_NAME => QSYS2.JOB_NAME,                                
             SPOOLED_FILE_NAME =>'REPL_MOD')) messages                  
      JOIN start_of_rpg_diagnostic_messages start_of                        
           ON start_of.ordinal_position + 1 < messages.ordinal_position 
      JOIN end_of_rpg_diagnostic_messages end_of                            
           ON end_of.ordinal_position > messages.ordinal_position
      WHERE cast(substring(spooled_data, 2, 7) as char(7)) <> '' 
    UNION ALL                                                                  
    SELECT                                                                                                                     
           cast(substring(messages_1.spooled_data, 1, 7) as char(7)) as message_id,  
           cast(substring(messages_1.spooled_data, 10, 2) as dec(2, 0)) as severity, 
           sql_line_translation.rpg_line as line,     
           // SQL sometimes splits these out over at least two lines. It's
           // possible there's sometimes a third.
           cast(trim(substring(messages_1.spooled_data, 22, 80))
             concat ' '
             concat trim(coalesce(substring(messages_2.spooled_data, 22, 80), '')) 
             concat ' '
             concat trim(coalesce(substring(messages_3.spooled_data, 22, 80), '')) 
             as char(80)) as error_text
      FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                            
             JOB_NAME => QSYS2.JOB_NAME,                                
             SPOOLED_FILE_NAME =>'REPL_MOD')) messages_1            
      JOIN start_of_sql_diagnostic_messages start_of                        
           ON start_of.ordinal_position < messages_1.ordinal_position 
      JOIN end_of_sql_diagnostic_messages end_of                            
           ON end_of.ordinal_position > messages_1.ordinal_position
      LEFT JOIN TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                            
             JOB_NAME => QSYS2.JOB_NAME,                                
             SPOOLED_FILE_NAME =>'REPL_MOD')) messages_2
           ON messages_2.ordinal_position = messages_1.ordinal_position + 1
           AND cast(substring(messages_2.spooled_data, 1, 7) as char(7)) = '' 
           AND cast(substring(messages_1.spooled_data, 1, 7) as char(7)) <> '' 
           AND messages_2.ordinal_position < end_of.ordinal_position   
      LEFT JOIN TABLE(SYSTOOLS.SPOOLED_FILE_DATA(                            
             JOB_NAME => QSYS2.JOB_NAME,                                
             SPOOLED_FILE_NAME =>'REPL_MOD')) messages_3
           ON messages_3.ordinal_position = messages_2.ordinal_position + 1
           AND cast(substring(messages_3.spooled_data, 1, 7) as char(7)) = '' 
           AND cast(substring(messages_2.spooled_data, 1, 7) as char(7)) = ''   
           AND messages_3.ordinal_position < end_of.ordinal_position   
      LEFT JOIN sql_line_translation 
           ON sql_line_translation.sql_record 
               = cast(substring(messages_1.spooled_data, 16, 4) as dec(4, 0))
      WHERE substring(messages_1.spooled_data, 1, 7) <>  '';

  exec sql
    OPEN repl_compilationErrors;

end-proc;

//-----------------------------------------------------------------------

dcl-proc replCompilationErrorFound;
  dcl-pi *n ind;
    compilationErrorDetails likeds(t_compilationErrorDetails);
  end-pi;

  exec sql
    FETCH NEXT FROM repl_compilationErrors
     INTO :compilationErrorDetails.code,
          :compilationErrorDetails.severity,
          :compilationErrorDetails.line,
          :compilationErrorDetails.text;

  return sqlstt = '00000';   

end-proc;

//-----------------------------------------------------------------------
//-----------------------------------------------------------------------

dcl-proc prepareUserBoundServicePrograms export;

  exec sql
    DECLARE repl_userServicePrograms CURSOR FOR
     SELECT upper(code) FROM replsrc
      WHERE session_id = (QSYS2.JOB_NAME)
            AND (upper(trim(code)) LIKE '/INCLUDE%'
                 OR upper(trim(code)) LIKE '/COPY%');

  exec sql
    CLOSE repl_userServicePrograms;

  exec sql
    OPEN repl_userServicePrograms;

end-proc;

//-----------------------------------------------------------------------

dcl-proc userBoundServiceProgram export;
  dcl-pi *n ind;
    serviceProgram likeds(t_serviceProgram);
    promptNeeded char(1);
    batchMode ind const;
  end-pi;

  dcl-s code like(t_lineOfCode.code);

  exec sql
    FETCH NEXT FROM repl_userServicePrograms INTO :code;

  if sqlstt <> '00000';
    return *off;
  endif;

  // take out the /include or /copy part
  code = %trim(%scanrpl('/INCLUDE': ' ': code));
  code = %trim(%scanrpl('/COPY': ' ': code));

  // if there isn't a slash,
  // or it's after the rpgleref,file#name,
  // then there isn't a library specified
  if %scan('/': code) = 0
  or (%scan('/': code) > %scan(',': code));
    serviceProgram.library = '*LIBL';
  else;
    serviceProgram.library = %subst(
      code:
      1:
      %scan('/': code) - 1);
  endif;

  // Get rid of everything to the left of the comma
  code = %trim(
           %subst(
             code:
             %scan(
               ',':
               code) + 1));

  // Get rid of anything to the right of the reference source
  if %scan(' ': %trim(code)) <> 0;
    code = %subst(
              code:
              1:
              %scan(' ': %trim(code)) - 1);
  endif;

  serviceProgram.name = code;

  if isExistingObject(
    serviceProgram.name:
    '*SRVPGM':
    serviceProgram.library
  );
    return *on;
  endif;

  if %scan('#': serviceProgram.name) <> 0;
    serviceProgram.name = %scanrpl('#': '.': serviceProgram.name);

    if isExistingObject(
      serviceProgram.name:
      '*SRVPGM':
      serviceProgram.library
    );
      return *on;
    endif;
  endif;

  promptNeeded = '?';

  if batchMode;
    serviceProgram.name = *blanks;
  endif;

  return *on;

end-proc;

//-----------------------------------------------------------------------

dcl-proc closeReplCmpl export;

  exec sql CLOSE repl_userServicePrograms;

end-proc;

//-----------------------------------------------------------------------

dcl-proc isExistingObject;
  dcl-pi *n ind;
    object char(10) const;
    type char(7) const;
    library char(10) const;
  end-pi;

  monitor;
    runCommand('CHKOBJ OBJ(&1/&2) OBJTYPE(&3)': library: object: type);
  on-error;
    return *off;
  endmon;

  return *on;

end-proc;

//-----------------------------------------------------------------------

