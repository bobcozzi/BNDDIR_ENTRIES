


BEGIN
  -- This compound statement creates Z_BNDDIRE in QTEMP.
  -- It is used to allow the SQL "compiler" to see the file
  -- at "compile time", avoiding an error message.
  -- It is created in QTEMP.
       DECLARE CONTINUE HANDLER FOR SQLException
       BEGIN   END;  -- Empty block works like MONMSG CPF0000
        call QSYS2.QCMDEXC( 'DSPBNDDIR QSYS/QC2LE '  concat
                       ' OUTPUT(*outfile) ' concat
                       ' OUTFILE(QTEMP/Z_BNDDIRE) ' concat
                       ' OUTMBR(*FIRST *REPLACE) ');
END;

CREATE OR REPLACE FUNCTION sqltools.BNDDIR_ENTRIES(
                               library_name   VARCHAR(10) default '*LIBL',
                               BNDDIR         VARCHAR(10)
            )

   RETURNS TABLE (
       BNDDIR       VARCHAR(10),
       BNDDIRLIB    VARCHAR(10),
       OBJNAME      VARCHAR(10),    -- Entry name
       OBJLIB       VARCHAR(10),    -- Entry Library
       OBJTYPE      VARCHAR(10),    -- Entry Type (*SRVPGM *MODULE)
       ACTIVATION   VARCHAR(10),    -- Activation (*IMMED *DEFER)
       ADDED_DATETIME   TIMESTAMP(0)
    )

    LANGUAGE SQL
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NOT FENCED
    SPECIFIC Z_BNDDIRE

    -- Date Format ISO is required for dates prior to 1940.
    set option COMMIT=*NONE,DATFMT=*ISO,TIMFMT=*HMS

R: BEGIN
    DECLARE CMD      VARCHAR(256) NOT NULL DEFAULT '';
    DECLARE CMDLOG varchar(256) not null default '';

    DECLARE BDLIB  VARCHAR(10) not null default '*LIBL';
    DECLARE BDNAME VARCHAR(10);
    DECLARE OUTFILE_NAME VARCHAR(21) NOT NULL DEFAULT 'QTEMP/Z_BNDDIRE';

    if (BNDDIR is not null and length(bnddir) > 0) then
      set R.bdName = upper(BNDDIR);
    end if;

    if (LIBRARY_NAME is not null and length(LIBRARY_NAME) > 0) then
      set R.BDLIB = upper(LIBRARY_NAME);
    end if;

    set R.BDLIB = rtrim(R.bdLib);
    set R.BDNAME = rtrim(R.bdName);

      -- Get a temp name in case we are joining other BNDDIR_ENTRIES results.
    values extract(microseconds from current_timestamp ) INTO R.OUTFILE_NAME;
    set R.OUTFILE_NAME = 'QTEMP/QBD' concat
                         LEFT(strip(R.OUTFILE_NAME,L,' '),7);

    set R.CMD = 'DSPBNDDIR ' concat R.bdLib concat '/'
                           concat R.bdName concat
                ' OUTPUT(*outfile) ' concat
                 'OUTFILE( 'concat rTrim(R.OUTFILE_NAME) concat ')';

     call QSYS2.QCMDEXC( R.CMD, length(R.CMD) );

     set R.CMD = 'OVRDBF FILE(Z_BNDDIRE) OVRSCOPE(*JOB) ' concat
                       'TOFILE(' concat rTrim(R.OUTFILE_NAME) concat ')';
     call QSYS2.QCMDEXC( R.CMD, length(R.CMD) );

forEach: FOR Q38 as COZZI_GETBNDDIRE CURSOR FOR
      SELECT  BNDRNM,BNDRLB,BNOBNM,BNOLNM, BNOBTP, BNOACT,
              CASE WHEN BNODAT = ' ' or
                        HEX(BNODAT) = '000000000000' THEN NULL
                   ELSE
                   timestamp_format(BNODAT CONCAT BNOTIM,'YYMMDDHH24MISS')
              END as ADD_DTS
        FROM Z_BNDDIRE
      DO     -- Send the resulting column's data back as a "row"
       PIPE(BNDRNM,BNDRLB,BNOBNM,BNOLNM, BNOBTP, BNOACT,ADD_DTS);
   end for forEach;

     set R.CMD = 'DLTOVR FILE(Z_BNDDIRE) LVL(*JOB)';
     call QSYS2.QCMDEXC( R.CMD, length(R.CMD) );

    BEGIN   -- Delete the workfile in QTEMP
       DECLARE CONTINUE HANDLER FOR SQLException
       BEGIN   END;  -- Empty block works like MONMSG CPF0000
       set R.CMD = 'DLTF ' concat rTrim(R.OUTFILE_NAME);
       call QSYS2.QCMDEXC( R.CMD, length(R.CMD) );
    END;
     return;
 end R;


LABEL on specific routine sqltools.Z_BNDDIRE  IS
'List the entries stored in a Binding Directory';

COMMENT ON SPECIFIC FUNCTION sqltools.Z_BNDDIRE
 IS 'Returns a list of binding directory entries for the specified
 binding directory.';


COMMENT ON PARAMETER SPECIFIC FUNCTION sqltools.Z_BNDDIRE
(
LIBRARY_NAME IS 'The name of the library where the binding directory is
located. The following special values may be specified instead of a specific
library name:<ul><li><u>*LIBL</u></li><li>*CURLIB</li><li>*USRLIBL</li></ul>',

BNDDIR IS 'The name of the binding directory whose entires are to be returned.'
);
