-- @version v3.1.0
-- REPL_EXECUTE: SQL stored procedure registration
--
-- Run this AFTER building REPLEXEC with makei.
-- Replace RPGLEREPL with your library name if different.

CREATE OR REPLACE PROCEDURE RPGLEREPL.REPL_EXECUTE (
  IN P_SOURCE CLOB(64K),
  IN P_SESSION_ID VARCHAR(28)
)
DYNAMIC RESULT SETS 1
EXTERNAL NAME 'RPGLEREPL/REPLEXEC'
LANGUAGE RPGLE
PARAMETER STYLE GENERAL;

COMMENT ON PROCEDURE RPGLEREPL.REPL_EXECUTE IS
  'Run RPG source through RPGLE-REPL and return results';

-- Usage from vscode-db2i notebooks:
--   CALL RPGLEREPL.REPL_EXECUTE(
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
