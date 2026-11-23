/* REXX ------------------------------------------------------------ */
/* LWDR941: step OUTGET of JCL/LWDTICK, the output collector (S3).   */
/* For each run that LWDM940 listed, finds the job with SDSF (ST     */
/* panel, by its unique job name) and copies its spool data sets,    */
/* with their DD, step and procedure step names, to OUTDATA for      */
/* LWDM945. The original output stays in JES. The userid needs SDSF  */
/* authority to the ST panel and READ on the jobs' JESSPOOL profiles */
/* (JCL/RACF). A job it can't see counts as not found.               */
/*                                                                   */
/* In:  DD OUTLIST (LWDM940), RECFM=FB,LRECL=80                      */
/*      col 1-9 RUNID, 11-18 job name, 20-27 JES job ID or blank,    */
/*      29-37 most lines to copy for the run (OUTLINES)              */
/* Out: DD OUTDATA, RECFM=VB,LRECL=304, records by their first byte: */
/*      J runid(9) status(1) jobid(8) retcode(20)   one per run      */
/*        status C copied, B still running, N not found,             */
/*               X SDSF error (see SYSTSPRT)                         */
/*      F ddname(8) stepname(8) procstep(8)   one per data set       */
/*      L text: the line, trailing blanks and ASA control removed,   */
/*        at most 255 characters                                     */
/*      E truncated(1): end of the data set; Y: lines left out       */
/* RC 0 = done, 8 = OUTLIST, OUTDATA or SDSF could not be used       */
/*                                                                   */
/* Updates:                                                          */
/*                                                                   */
/* Date     Who What                                                 */
/* -------- --- ---------------------------------------------------- */
/* yy/mm/dd ii  description                                          */
/* ----------------------------------------------------------------- */
"EXECIO * DISKR OUTLIST (STEM in. FINIS"
if rc <> 0 then do
  say 'LWDR941 READ OUTLIST RC' rc
  exit 8
end

if isfcalls('ON') <> 0 then do
  say 'LWDR941 SDSF REXX INTERFACE NOT AVAILABLE'
  exit 8
end

out. = ''
outn = 0
do i = 1 to in.0
  parse var in.i runid 10 . 11 jobname 19 . 20 jobid 28 . 29 maxl 38 .
  jobname = strip(jobname)
  jobid = strip(jobid)
  maxl = strip(maxl) + 0
  call collect
end

call flush
"EXECIO 0 DISKW OUTDATA (FINIS"
call isfcalls 'OFF'
say 'LWDR941 RUNS READ:' in.0
exit 0

/* ----------------------------------------------------------------- */
/* collect: one run: find the job, then copy its data sets           */
/* ----------------------------------------------------------------- */
collect:
  isfprefix = jobname
  isfowner = '*'
  Address SDSF "ISFEXEC ST"
  if rc > 4 then do
    say 'LWDR941' jobname 'ISFEXEC ST RC' rc isfmsg
    call put 'J'runid'X'left(jobid, 8)left('', 20)
    return
  end

  /* The job name is unique per run. The JES job ID only decides     */
  /* between two jobs of that name: a job that ran on another node   */
  /* (EXECNODE) has another job ID here than the one it recorded.    */
  row = 0
  do r = 1 to JNAME.0
    if JNAME.r <> jobname then iterate
    if row = 0 | JOBID.r = jobid then row = r
  end

  if row = 0 then do
    say 'LWDR941' jobname jobid 'NOT FOUND'
    call put 'J'runid'N'left(jobid, 8)left('', 20)
    return
  end

  q = QUEUE.row
  if left(q, 4) = 'EXEC' | left(q, 5) = 'INPUT' | ,
     left(q, 4) = 'CONV' | left(q, 5) = 'SETUP' then do
    say 'LWDR941' jobname JOBID.row 'STILL IN' q
    call put 'J'runid'B'left(JOBID.row, 8)left('', 20)
    return
  end

  Address SDSF "ISFACT ST TOKEN('"TOKEN.row"') PARM(NP ?) (PREFIX D_"
  if rc > 4 then do
    say 'LWDR941' jobname 'ISFACT ? RC' rc isfmsg
    call put 'J'runid'X'left(JOBID.row, 8)left('', 20)
    return
  end

  call put 'J'runid'C'left(JOBID.row, 8)left(RETCODE.row, 20)
  say 'LWDR941' jobname JOBID.row RETCODE.row D_DDNAME.0 'DATA SETS'

  rest = maxl
  do d = 1 to D_DDNAME.0
    call put 'F'left(D_DDNAME.d, 8)left(D_STEPN.d, 8)left(D_PROCS.d, 8)
    if rest <= 0 then
      call put 'EY'
    else
      call copyds d
  end
  return

/* ----------------------------------------------------------------- */
/* copyds: the lines of data set d, at most rest of them             */
/* ----------------------------------------------------------------- */
copyds:
  arg d
  Address SDSF "ISFACT ST TOKEN('"D_TOKEN.d"') PARM(NP SA)"
  if rc > 4 | isfddname.0 < 1 then do
    say 'LWDR941' jobname D_DDNAME.d 'ISFACT SA RC' rc isfmsg
    call put 'EY'
    return
  end

  dd = isfddname.1
  asa = 0
  if listdsi(dd 'FILE') <= 4 then
    asa = (pos('A', SYSRECFM) > 0)

  trunc = 'N'
  eof = 0
  do while \eof & rest > 0
    n = min(1000, rest)
    "EXECIO" n "DISKR" dd "(STEM ln."
    if rc = 2 then eof = 1
    else if rc <> 0 then do
      say 'LWDR941' jobname D_DDNAME.d 'EXECIO RC' rc
      eof = 1
      trunc = 'Y'
    end
    do k = 1 to ln.0
      t = ln.k
      if asa then t = substr(t, 2)
      t = strip(t, 'T')
      if length(t) > 255 then t = left(t, 255)
      call put 'L't
    end
    rest = rest - ln.0
  end

  if \eof then do
    /* Stopped at the most lines: is there one more?                 */
    "EXECIO 1 DISKR" dd "(STEM ln."
    if rc = 0 & ln.0 > 0 then trunc = 'Y'
  end

  "EXECIO 0 DISKR" dd "(FINIS"
  "FREE FILE("dd")"
  call put 'E'trunc
  return

/* ----------------------------------------------------------------- */
/* put: one OUTDATA record; flush: write the ones collected so far   */
/* ----------------------------------------------------------------- */
put:
  outn = outn + 1
  out.outn = arg(1)
  if outn >= 2000 then call flush
  return

flush:
  if outn = 0 then return
  "EXECIO" outn "DISKW OUTDATA (STEM out."
  if rc <> 0 then do
    say 'LWDR941 WRITE OUTDATA RC' rc
    exit 8
  end
  outn = 0
  return
