/* ===========================================================================
   E-mail Notification — SCHEMA CHANGES
   Database: DB_SP_SP
   Source migrations: shared/migrations/db_sp_sp/148, 152

   WHAT THIS DOES
     Creates four new tables. It ALTERS NO EXISTING TABLE — there are no
     ADD/ALTER/DROP COLUMN statements anywhere in this change set.

     In particular TB_M_ETD_EMAIL_CONTENT is untouched, including its unique
     index IX_ETD_EMAIL_CONTENT_KEY (FUNCTION_ID, PLANT_CODE). Its
     EMAIL_TO/CC/BCC columns remain in use as the fallback recipient path, so
     any function with no row in TB_M_EMAIL_RECIPIENT keeps sending exactly one
     e-mail off the master row, exactly as before.

   WHY THE NEW TABLES
     TB_M_TEMPLATE_KEYS      declares which {{variables}} a function's template
                             may use. It is a PROJECTION of the code registry
                             (shared/email/mapperRegistry.js), populated by the
                             companion seed script — do not hand-maintain it.
     TB_M_EMAIL_RECIPIENT    who receives a notification. ONE ROW = ONE E-MAIL:
                             the notifier sends once per matching row, which is
                             what makes destination fan-out possible. Recipients
                             used to live on the template row, which allowed only
                             one list per function+plant.
     ..._ADDRESS             its addresses, one per row (TO / CC / BCC).
     ..._FUNCTION            which functions the row serves (many-to-many).


   TABLE ORIGINS  (verified against the live databases)
   ---------------------------------------------------------------------------
     NEW — created by this change, all in DB_SP_SP:
       TB_M_TEMPLATE_KEYS               declared {{variables}} per function
       TB_M_EMAIL_RECIPIENT             routing row = one e-mail (fan-out unit)
       TB_M_EMAIL_RECIPIENT_ADDRESS     its addresses (TO/CC/BCC), child
       TB_M_EMAIL_RECIPIENT_FUNCTION    functions it serves, child

     EXISTING in DB_SP_SP — read or written, never altered:
       TB_M_ETD_EMAIL_CONTENT   the e-mail TEMPLATE master (subject/body). See
                                the warning below: same NAME as a legacy table,
                                different DATABASE and different SHAPE.
       TB_M_FUNCTION            RBAC function catalogue. `id` is a randomUUID()
                                generated PER ENVIRONMENT -- always join by Name.
       TB_M_PERMISSION          role x function grants
       SP0ROLE                  roles; match on SystemName, not the bootstrap
                                names 'admin'/'superadmin'
       SP0USERPORTAL            portal users; supplies Email for derived
                                recipients (referenced by the app, not by this
                                script)
       TB_M_USER_PROC_ID        procurement code -> Windows id -> user; the
                                lookup behind PROC_CODE_ID (app-side)

     EXISTING in OTHER databases — referenced only in comments here, by the
     application at runtime:
       TB_R_PO_T                DB_SP_SUP   source of DEST_CODE values that
                                            DESTINATION_CD is matched against
       TB_R_ASN                 DB_SP_PRO   named in some key descriptions
       SP1ASN                   DB_SP_SP    named in some key descriptions
       TB_I_H01_25_DESTINATION  DB_SP_INF   destination master, joined for the
                                            readable name in the picker

   WARNING — TB_M_ETD_EMAIL_CONTENT EXISTS TWICE, DIFFERENTLY
     ours (DB_SP_SP)   : FUNCTION_ID, FUNC_DESCRIPTION, PLANT_CODE,
                         EMAIL_TO / EMAIL_CC / EMAIL_BCC, EMAIL_SUBJECT,
                         EMAIL_MESSAGE
     legacy (DB_SP_SUP): SID, EMAIL_CODE, EMAIL_FROM, EMAIL_CC, EMAIL_SUBJECT,
                         EMAIL_MESSAGE, FUNCTION_ID
                         -- no EMAIL_TO, no EMAIL_BCC, no PLANT_CODE
     The two are NOT interchangeable. This script only ever touches the DB_SP_SP
     one. Legacy recipients live in DB_SP_SUP.TB_M_ETD_EMAIL_NOTIFICATION and its
     _EMAILADDRESS / _FUNCTION children, which this change does not read or write.


   DIFF vs THE ORIGINAL (LEGACY) TABLES
   ---------------------------------------------------------------------------
   A. EXISTING TABLES CHANGED BY THIS SCRIPT:  NONE.
      No ADD / ALTER / DROP COLUMN, no index or constraint change, on any table
      that already existed. TB_M_ETD_EMAIL_CONTENT keeps every column and keeps
      IX_ETD_EMAIL_CONTENT_KEY (FUNCTION_ID, PLANT_CODE) exactly as it was --
      that index stays CORRECT because the TEMPLATE is still one row per
      function+plant. Only RECIPIENTS became many, and they moved to a new table.
      Prove it after running:
        SELECT name, is_unique FROM sys.indexes
         WHERE object_id = OBJECT_ID(N'dbo.TB_M_ETD_EMAIL_CONTENT');

   B. THE NEW TABLES vs THE LEGACY ONES THEY MIRROR
      Legacy lives in DB_SP_SUP and is NOT touched, read or migrated by this
      script. These tables reproduce it COLUMN FOR COLUMN so a later merge with
      real legacy data is a straight mapping rather than a translation.

      legacy DB_SP_SUP.TB_M_ETD_EMAIL_NOTIFICATION  ->  new DB_SP_SP.TB_M_EMAIL_RECIPIENT
        SID uniqueidentifier          ->  SID char(36)          name KEPT, type per DB_SP_SP
        GROUP_CD varchar(20)          ->  GROUP_CD nvarchar(20)         KEPT (unused here)
        DESTINATION_CD varchar(7)     ->  DESTINATION_CD nvarchar(20)   KEPT, widened
        DEPOT_CD varchar(3)           ->  DEPOT_CD nvarchar(3)          KEPT (unused here)
        USERNAME varchar(50)          ->  USERNAME nvarchar(50)         KEPT (unused here)
        PROC_OPERATOR_ID char(2)      ->  PROC_OPERATOR_ID nvarchar(50) KEPT, widened to match
                                          DB_SP_SP.TB_M_USER_PROC_ID.PROC_CODE_ID
        EMAIL_ADDRESS varchar(MAX)    ->  EMAIL_ADDRESS nvarchar(MAX)   KEPT (see note below)
        FUNCTION_ID varchar(MAX)      ->  FUNCTION_ID nvarchar(MAX)     KEPT (see note below)
        (none)                        ->  PLANT_CODE nvarchar(50)   ADDED, legacy has no
                                                                    plant dimension
        (none)                        ->  IS_ACTIVE bit             ADDED, park a row instead
                                                                    of deleting it
        (none)                        ->  REMARK nvarchar(255)      ADDED

      legacy ..._EMAILADDRESS  ->  new TB_M_EMAIL_RECIPIENT_ADDRESS
        SID                           ->  SID char(36)
        EMAIL_NOTIFICATION_SID        ->  EMAIL_NOTIFICATION_SID char(36)   name KEPT
        EMAIL_ADDRESS varchar(MAX)    ->  EMAIL_ADDRESS nvarchar(255)       name KEPT
        (none)                        ->  KIND 'TO'|'CC'|'BCC'  ADDED. Legacy had no
                                          per-address kind: its TO came from this child and
                                          its CC from a single column on the CONTENT row.

      legacy ..._FUNCTION  ->  new TB_M_EMAIL_RECIPIENT_FUNCTION
        SID                           ->  SID char(36)
        EMAIL_NOTIFICATION_SID        ->  EMAIL_NOTIFICATION_SID char(36)   name KEPT
        FUNCTION_ID varchar(20)       ->  FUNCTION_ID char(36), a REAL FK to
                                          DB_SP_SP.TB_M_FUNCTION.id (char(36) there)

      NOTHING FROM LEGACY IS DROPPED OR RENAMED. Where the two differ:
        * TYPE, not name: legacy uses uniqueidentifier and varchar; DB_SP_SP has
          ZERO uniqueidentifier columns and stores uuids as char(36), so SID and
          the FKs follow the target database. nvarchar over varchar is a
          widening, safe in both directions for ASCII data.
        * The parent's EMAIL_ADDRESS and FUNCTION_ID are REDUNDANT with the child
          tables -- exactly as they are in legacy, which kept both after its
          2024-02-02 single-to-multi migration. This application reads and writes
          ONLY the children; the two parent columns exist for parity and stay
          NULL here. If anything ever populates them, decide which side wins
          first, or the two will disagree.
        * Legacy declares NO primary keys and NO foreign keys on this family --
          integrity was application-only. Ours adds PKs, FKs, cascading deletes
          and a UNIQUE constraint per child (legacy allowed duplicate addresses
          and duplicate function links).
        * IS_ACTIVE, PLANT_CODE, REMARK and KIND are additions with no legacy
          counterpart.

   C. TEMPLATE MASTERS: SAME NAME, DIFFERENT TABLE
      legacy DB_SP_SUP.TB_M_ETD_EMAIL_CONTENT   ours DB_SP_SP.TB_M_ETD_EMAIL_CONTENT
        SID uniqueidentifier                      ID int
        EMAIL_CODE varchar(15)                    (none)    -- we key on FUNCTION_ID + PLANT_CODE
        EMAIL_FROM varchar(100)                   (none)    -- from the MAIL_FROM env var
        FUNCTION_ID varchar(20)                   FUNCTION_ID nvarchar(50)
        (none)                                    FUNC_DESCRIPTION nvarchar(255)
        (none)                                    PLANT_CODE nvarchar(50)
        (none)                                    EMAIL_TO nvarchar(500)
        EMAIL_CC varchar(350)                     EMAIL_CC nvarchar(500)
        (none)                                    EMAIL_BCC nvarchar(500)
        EMAIL_SUBJECT varchar(100)                EMAIL_SUBJECT nvarchar(500)
        EMAIL_MESSAGE varchar(MAX)                EMAIL_MESSAGE nvarchar(MAX)
      Do not point this script at the DB_SP_SUP table: the shapes are not
      compatible, and legacy templates use [BRACKET] placeholders while ours use
      Mustache {{variables}} validated against TB_M_TEMPLATE_KEYS.

   SAFETY
     Every statement is guarded by an existence check, so the script is
     re-runnable. Run the schema script FIRST, then the seed script.
   =========================================================================== */

USE [DB_SP_SP];
GO

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   1. TB_M_TEMPLATE_KEYS  —  NEW TABLE, DB_SP_SP  (migration 148)

   FUNCTION_ID holds the EXISTING DB_SP_SP.TB_M_FUNCTION.id. That id is a
   randomUUID() generated PER
   ENVIRONMENT, so it is stored here but everything resolves it BY NAME at
   runtime — never copy ids between environments.

   ALLOW_HTML marks a key whose value may contain markup, so a template may use
   the unescaped {{{form}}} for it. IS_ACTIVE=0 RETIRES a key without deleting
   it: a saved template may still reference the name, and a hard delete would
   make that row impossible to save.
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.TB_M_TEMPLATE_KEYS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_TEMPLATE_KEYS (
        ID            int IDENTITY(1,1)  NOT NULL,
        FUNCTION_ID   nvarchar(50)       NOT NULL,
        KEY_NAME      nvarchar(100)      NOT NULL,
        DESCRIPTION   nvarchar(255)      NULL,
        SAMPLE_VALUE  nvarchar(255)      NULL,
        ALLOW_HTML    bit                NOT NULL CONSTRAINT DF_TEMPLATE_KEYS_ALLOW_HTML DEFAULT ((0)),
        IS_ACTIVE     bit                NOT NULL CONSTRAINT DF_TEMPLATE_KEYS_IS_ACTIVE  DEFAULT ((1)),
        CREATED_BY    nvarchar(255)      NULL,
        CREATED_DT    datetimeoffset     NULL,
        CHANGED_BY    nvarchar(255)      NULL,
        CHANGED_DT    datetimeoffset     NULL,
        CONSTRAINT PK_TB_M_TEMPLATE_KEYS PRIMARY KEY (ID)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TEMPLATE_KEYS_KEY'
               AND object_id = OBJECT_ID(N'dbo.TB_M_TEMPLATE_KEYS'))
BEGIN
    -- One declaration per key per function.
    CREATE UNIQUE INDEX IX_TEMPLATE_KEYS_KEY
        ON dbo.TB_M_TEMPLATE_KEYS (FUNCTION_ID, KEY_NAME);
END
GO


/* ---------------------------------------------------------------------------
   2. TB_M_EMAIL_RECIPIENT  —  NEW TABLE, DB_SP_SP  (migration 152)
      The fan-out unit: one row = one e-mail.

   PLANT_CODE      '*' (or NULL) = every plant. Same wildcard the template
                   master uses; it can never collide with a real vendor code.
   DESTINATION_CD  NULL = the CATCH-ALL row. Precedence at send time is:
                     record HAS a destination  -> ONLY rows with that exact code.
                                                  No match means NO E-MAIL; the
                                                  catch-all is not a safety net.
                     record has NO destination -> ONLY catch-all rows.
                   So a new destination code needs a row here before it will ever
                   receive mail. Values come from DB_SP_SUP.TB_R_PO_T.DEST_CODE (a padded
                   char), hence every comparison trims and ignores case.
   PROC_CODE_ID    optional DERIVED recipients: resolved at send time through
                   DB_SP_SP.TB_M_USER_PROC_ID.PROC_CODE_ID -> USER_ID_WINDOWS
                   -> DB_SP_SP.SP0USERPORTAL.UserName -> Email. Self-maintaining when staff
                   change roles. Soft reference on purpose — one code may map to
                   several people, so no FK is possible.
   IS_ACTIVE       park a row without deleting it (and losing its children to
                   the cascade).
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_EMAIL_RECIPIENT (
        -- Legacy's key NAME and role. The TYPE is char(36), not legacy's
        -- `uniqueidentifier`: DB_SP_SP contains ZERO uniqueidentifier columns and
        -- stores every uuid as char(36), TB_M_FUNCTION.id included. Legacy naming
        -- wins; the target database's storage convention wins on type.
        SID               char(36)       NOT NULL CONSTRAINT DF_EMAIL_RECIPIENT_SID DEFAULT (NEWID()),

        -- ── legacy columns, present for parity; this app does not read them ──
        GROUP_CD          nvarchar(20)   NULL,
        DEPOT_CD          nvarchar(3)    NULL,
        USERNAME          nvarchar(50)   NULL,
        -- Legacy's pre-normalization lists. REDUNDANT with the child tables and
        -- never read or written here -- the children are the only source of
        -- truth. Do not start using these without deciding which side wins.
        EMAIL_ADDRESS     nvarchar(MAX)  NULL,
        FUNCTION_ID       nvarchar(MAX)  NULL,

        -- ── ours ────────────────────────────────────────────────────────────
        PLANT_CODE        nvarchar(50)   NULL,
        DESTINATION_CD    nvarchar(20)   NULL,
        -- Legacy NAME (legacy type is char(2)); widened to match
        -- DB_SP_SP.TB_M_USER_PROC_ID.PROC_CODE_ID, which it resolves against.
        PROC_OPERATOR_ID  nvarchar(50)   NULL,
        IS_ACTIVE         bit            NOT NULL CONSTRAINT DF_EMAIL_RECIPIENT_IS_ACTIVE DEFAULT ((1)),
        REMARK            nvarchar(255)  NULL,
        CREATED_BY        nvarchar(100)  NULL,
        CREATED_DT        datetimeoffset NULL,
        CHANGED_BY        nvarchar(100)  NULL,
        CHANGED_DT        datetimeoffset NULL,
        CONSTRAINT PK_TB_M_EMAIL_RECIPIENT PRIMARY KEY (SID)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EMAIL_RECIPIENT_PLANT_DEST'
               AND object_id = OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT'))
BEGIN
    -- The resolver's path: narrow by plant, then match destination.
    CREATE INDEX IX_EMAIL_RECIPIENT_PLANT_DEST
        ON dbo.TB_M_EMAIL_RECIPIENT (PLANT_CODE, DESTINATION_CD);
END
GO


/* ---------------------------------------------------------------------------
   3. TB_M_EMAIL_RECIPIENT_ADDRESS  —  NEW TABLE, DB_SP_SP  (migration 152)
      Child of TB_M_EMAIL_RECIPIENT.

   One row per address rather than a comma list, so each can be validated,
   deduped and removed on its own. KIND is 'TO' | 'CC' | 'BCC'; it is a plain
   nvarchar, not a CHECK/ENUM, because the value set is enforced in the API and
   an ENUM renders as a constraint that is painful to alter later.

   A row that resolves to no TO address is skipped at send time, so the API
   rejects saving one — that turns a silent non-delivery into a save error.
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT_ADDRESS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_EMAIL_RECIPIENT_ADDRESS (
        SID                     char(36)       NOT NULL CONSTRAINT DF_EMAIL_RECIPIENT_ADDRESS_SID DEFAULT (NEWID()),
        -- Legacy's FK column name.
        EMAIL_NOTIFICATION_SID  char(36)       NOT NULL,
        -- Legacy's column name for the address itself.
        EMAIL_ADDRESS           nvarchar(255)  NOT NULL,
        -- 'TO' | 'CC' | 'BCC'. OUR ADDITION: legacy had no per-address kind --
        -- its TO came from this child and its CC from a single column on the
        -- CONTENT row. Plain nvarchar, not a CHECK/ENUM, because the value set is
        -- enforced in the API and an ENUM is painful to alter later.
        KIND                    nvarchar(3)    NOT NULL CONSTRAINT DF_EMAIL_RECIPIENT_ADDRESS_KIND DEFAULT (N'TO'),
        CREATED_BY              nvarchar(100)  NULL,
        CREATED_DT              datetimeoffset NULL,
        CONSTRAINT PK_TB_M_EMAIL_RECIPIENT_ADDRESS PRIMARY KEY (SID),
        CONSTRAINT FK_EMAIL_RECIPIENT_ADDRESS_PARENT FOREIGN KEY (EMAIL_NOTIFICATION_SID)
            REFERENCES dbo.TB_M_EMAIL_RECIPIENT (SID) ON UPDATE CASCADE ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EMAIL_RECIPIENT_ADDRESS_UNIQUE'
               AND object_id = OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT_ADDRESS'))
BEGIN
    -- The same person as both TO and CC is legitimate; twice as TO is a slip.
    CREATE UNIQUE INDEX IX_EMAIL_RECIPIENT_ADDRESS_UNIQUE
        ON dbo.TB_M_EMAIL_RECIPIENT_ADDRESS (EMAIL_NOTIFICATION_SID, EMAIL_ADDRESS, KIND);
END
GO


/* ---------------------------------------------------------------------------
   4. TB_M_EMAIL_RECIPIENT_FUNCTION  —  NEW TABLE, DB_SP_SP  (migration 152)
      Child of TB_M_EMAIL_RECIPIENT; FK to the EXISTING DB_SP_SP.TB_M_FUNCTION.

   Many-to-many: one recipient row can serve several functions, which is why
   this is a child table and not a column on the parent.

   FUNCTION_ID is a real FK to the EXISTING DB_SP_SP.TB_M_FUNCTION.id, but that
   id is a per-environment
   uuid — code always resolves a function BY NAME and uses the id only as the
   join key. Never copy these ids between environments.
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT_FUNCTION', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_EMAIL_RECIPIENT_FUNCTION (
        SID                     char(36)       NOT NULL CONSTRAINT DF_EMAIL_RECIPIENT_FUNCTION_SID DEFAULT (NEWID()),
        EMAIL_NOTIFICATION_SID  char(36)       NOT NULL,
        -- char(36) because it FKs to the EXISTING DB_SP_SP.TB_M_FUNCTION.id,
        -- which is char(36). That id is a randomUUID() generated PER
        -- ENVIRONMENT -- always resolve a function BY NAME, never copy ids.
        FUNCTION_ID             char(36)       NOT NULL,
        CREATED_BY              nvarchar(100)  NULL,
        CREATED_DT              datetimeoffset NULL,
        CONSTRAINT PK_TB_M_EMAIL_RECIPIENT_FUNCTION PRIMARY KEY (SID),
        CONSTRAINT FK_EMAIL_RECIPIENT_FUNCTION_PARENT FOREIGN KEY (EMAIL_NOTIFICATION_SID)
            REFERENCES dbo.TB_M_EMAIL_RECIPIENT (SID) ON UPDATE CASCADE ON DELETE CASCADE,
        CONSTRAINT FK_EMAIL_RECIPIENT_FUNCTION_FN FOREIGN KEY (FUNCTION_ID)
            REFERENCES dbo.TB_M_FUNCTION (id) ON UPDATE CASCADE ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EMAIL_RECIPIENT_FUNCTION_UNIQUE'
               AND object_id = OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT_FUNCTION'))
BEGIN
    CREATE UNIQUE INDEX IX_EMAIL_RECIPIENT_FUNCTION_UNIQUE
        ON dbo.TB_M_EMAIL_RECIPIENT_FUNCTION (EMAIL_NOTIFICATION_SID, FUNCTION_ID);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EMAIL_RECIPIENT_FUNCTION_FN'
               AND object_id = OBJECT_ID(N'dbo.TB_M_EMAIL_RECIPIENT_FUNCTION'))
BEGIN
    -- The resolver enters from the function side ("which rows serve X?").
    CREATE INDEX IX_EMAIL_RECIPIENT_FUNCTION_FN
        ON dbo.TB_M_EMAIL_RECIPIENT_FUNCTION (FUNCTION_ID);
END
GO


/* ---------------------------------------------------------------------------
   VERIFY
   --------------------------------------------------------------------------- */
SELECT t.name AS [table], COUNT(c.column_id) AS columns
  FROM sys.tables t
  JOIN sys.columns c ON c.object_id = t.object_id
 WHERE t.name IN ('TB_M_TEMPLATE_KEYS', 'TB_M_EMAIL_RECIPIENT',
                  'TB_M_EMAIL_RECIPIENT_ADDRESS', 'TB_M_EMAIL_RECIPIENT_FUNCTION')
 GROUP BY t.name
 ORDER BY t.name;
GO

-- MEASURED on a database rebuilt from scratch:
--   TB_M_EMAIL_RECIPIENT 15, _ADDRESS 6, _FUNCTION 5, TB_M_TEMPLATE_KEYS 11.
-- The recipient parent is 15 because it carries the full legacy column set
-- (GROUP_CD, DEPOT_CD, USERNAME and legacy's two pre-normalization lists) on top
-- of our own PLANT_CODE / IS_ACTIVE / REMARK. See the DIFF section above.
-- Next: run email-notification-seed.sql.


/* ===========================================================================
   ROLLBACK (children first — the FKs would block dropping the parent)
   ---------------------------------------------------------------------------
   DROP TABLE IF EXISTS dbo.TB_M_EMAIL_RECIPIENT_FUNCTION;
   DROP TABLE IF EXISTS dbo.TB_M_EMAIL_RECIPIENT_ADDRESS;
   DROP TABLE IF EXISTS dbo.TB_M_EMAIL_RECIPIENT;
   DROP TABLE IF EXISTS dbo.TB_M_TEMPLATE_KEYS;
   =========================================================================== */
