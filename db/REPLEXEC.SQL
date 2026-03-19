-- @version v3.1.0
-- repl_execute: SQL stored procedure for notebook integration
--
-- This is self-contained. No external procedure registration needed.
-- The RPG program REPLEXEC is called via QCMDEXC.

CREATE OR REPLACE PROCEDURE repl_execute (
  IN P_SOURCE CLOB(256K) CCSID 1208,
  IN P_SESSION_ID VARCHAR(28)
)
DYNAMIC RESULT SETS 1
LANGUAGE SQL
SET OPTION COMMIT = *NONE

BEGIN
  DECLARE v_snippetName CHAR(20) CCSID 37;
  DECLARE v_lineNum INT DEFAULT 1;
  DECLARE v_pos INT DEFAULT 1;
  DECLARE v_nextPos INT;
  DECLARE v_line VARCHAR(200) CCSID 37;
  DECLARE v_sourceLen INT;
  DECLARE v_cmd VARCHAR(200) CCSID 37;
  DECLARE v_source CLOB(256K) CCSID 37;
  DECLARE c_LF CHAR(1) CCSID 37 DEFAULT x'25';

  -- Convert UTF-8 input to EBCDIC for table operations
  SET v_source = CAST(P_SOURCE AS CLOB(256K) CCSID 37);
  SET v_snippetName = LEFT(CAST(P_SESSION_ID AS VARCHAR(28) CCSID 37), 20);
  SET v_sourceLen = LENGTH(v_source);

  -- Clear previous source for this snippet
  DELETE FROM replsrc WHERE save_name = v_snippetName;

  -- Parse source into lines (split on EBCDIC LF x'25')
  IF v_sourceLen > 0 THEN
    WHILE v_pos <= v_sourceLen DO
      SET v_nextPos = LOCATE(c_LF, v_source, v_pos);

      IF v_nextPos = 0 THEN
        -- Last line (no trailing newline)
        SET v_line = CAST(SUBSTRING(v_source, v_pos,
                     v_sourceLen - v_pos + 1) AS VARCHAR(200));
        SET v_pos = v_sourceLen + 1;
      ELSE
        IF v_nextPos > v_pos THEN
          SET v_line = CAST(SUBSTRING(v_source, v_pos,
                       v_nextPos - v_pos) AS VARCHAR(200));
        ELSE
          SET v_line = '';
        END IF;
        SET v_pos = v_nextPos + 1;
      END IF;

      -- Strip trailing CR if present (handles CRLF)
      IF LENGTH(v_line) > 0
        AND SUBSTRING(v_line, LENGTH(v_line), 1) = x'0D' THEN
        SET v_line = LEFT(v_line, LENGTH(v_line) - 1);
      END IF;

      INSERT INTO replsrc
        (session_id, line_number, code, save_name, owner, source_type)
      VALUES
        ('', v_lineNum, v_line, v_snippetName,
         CURRENT_USER, 'mainline');

      SET v_lineNum = v_lineNum + 1;
    END WHILE;
  END IF;

  -- Call RPG pipeline runner via QCMDEXC (no procedure registration needed)
  SET v_cmd = 'CALL PGM(REPLEXEC) PARM('''
    || REPLACE(v_snippetName, '''', '''''') || ''')';
  CALL QSYS2.QCMDEXC(v_cmd);

  -- Tag results with external session ID
  UPDATE replrslt SET external_session_id = P_SESSION_ID
  WHERE session_id = (QSYS2.JOB_NAME)
    AND (external_session_id IS NULL OR external_session_id = '');

  -- Return results
  BEGIN
    DECLARE c_results CURSOR WITH RETURN FOR
      SELECT line_number, result_number, result_description,
             loop_count, result_type
      FROM replrslt
      WHERE external_session_id = P_SESSION_ID
      ORDER BY line_number, result_number;

    OPEN c_results;
  END;

  -- Clean up source
  DELETE FROM replsrc WHERE save_name = v_snippetName;
END;

COMMENT ON PROCEDURE repl_execute IS
  'Run RPG source through RPGLE-REPL and return results';

-- Usage from vscode-db2i notebooks:
--   CALL repl_execute(
--     'dcl-s greeting char(20);
--      greeting = ''Hello from RPG!'';
--      replPrint(greeting);',
--     'NB-session-123'
--   );
--
-- Returns a result set with columns:
--   LINE_NUMBER      DEC(4,0)       - source line number
--   RESULT_NUMBER    DEC(4,0)       - sequential result for this line
--   RESULT_DESCRIPTION VARCHAR(1000) - the result text
--   LOOP_COUNT       DEC(5,0)       - loop iteration count
--   RESULT_TYPE      CHAR(32)       - EVALUATION, TEST-SUCCESS, TEST-FAILURE, etc.
