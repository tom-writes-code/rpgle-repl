-- @version v3.1.0
-- repl_execute: SQL stored procedure for notebook integration
--
-- Run this AFTER building REPLEXEC with makei.

-- Step 1: Register the RPG pipeline runner as a helper procedure.
--         This accepts a snippet name + session ID and runs
--         generate / compile / run. No source text parameter.
CREATE OR REPLACE PROCEDURE repl_run_pipeline (
  IN P_SNIPPET_NAME CHAR(20),
  IN P_SESSION_ID VARCHAR(28)
)
EXTERNAL NAME 'REPLEXEC'
LANGUAGE RPGLE
PARAMETER STYLE GENERAL;

COMMENT ON PROCEDURE repl_run_pipeline IS
  'Internal: run the REPL generate/compile/run pipeline for a snippet';

-- Step 2: The public-facing SQL procedure.
--         Parses source text into REPLSRC lines, calls the RPG pipeline,
--         and returns the result set. No LOB parameter passing to RPG.
CREATE OR REPLACE PROCEDURE repl_execute (
  IN P_SOURCE CLOB(256K),
  IN P_SESSION_ID VARCHAR(28)
)
DYNAMIC RESULT SETS 1
LANGUAGE SQL

BEGIN
  DECLARE v_snippetName CHAR(20);
  DECLARE v_lineNum INT DEFAULT 1;
  DECLARE v_pos INT DEFAULT 1;
  DECLARE v_nextPos INT;
  DECLARE v_line VARCHAR(200);
  DECLARE v_sourceLen INT;
  DECLARE c_LF CHAR(1) DEFAULT x'25';

  SET v_snippetName = LEFT(P_SESSION_ID, 20);
  SET v_sourceLen = LENGTH(P_SOURCE);

  -- Clear previous source for this snippet
  DELETE FROM replsrc WHERE save_name = v_snippetName;

  -- Parse source into lines (split on EBCDIC LF x'25')
  IF v_sourceLen > 0 THEN
    WHILE v_pos <= v_sourceLen DO
      SET v_nextPos = LOCATE(c_LF, P_SOURCE, v_pos);

      IF v_nextPos = 0 THEN
        -- Last line (no trailing newline)
        SET v_line = CAST(SUBSTRING(P_SOURCE, v_pos, v_sourceLen - v_pos + 1) AS VARCHAR(200));
        SET v_pos = v_sourceLen + 1;
      ELSE
        IF v_nextPos > v_pos THEN
          SET v_line = CAST(SUBSTRING(P_SOURCE, v_pos, v_nextPos - v_pos) AS VARCHAR(200));
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

  -- Run the RPG pipeline (generate, compile, run)
  CALL repl_run_pipeline(v_snippetName, P_SESSION_ID);

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
