/* REXX ------------------------------------------------------------ */
/* LWDR961: step MAILGET of JCL/LWDMAIL, the daily refresh of the    */
/* email addresses (S4 step 5, M8, docs/11-iteration-7.md). For each */
/* userid that LWDM960 listed, reads the WAEMAIL field of its RACF   */
/* WORKATTR segment with IRRXUTIL. The userid needs READ on FACILITY */
/* IRR.RADMIN.LISTUSER and IRR.LISTUSER, and on FIELD               */
/* USER.WORKATTR.WAEMAIL (JCL/RACF).                                 */
/*                                                                   */
/* In:  DD USERLIST (LWDM960), RECFM=FB,LRECL=80, col 1-8 userid     */
/* Out: DD USERMAIL, RECFM=FB,LRECL=300, for LWDM960:                */
/*      col 1-8 userid, col 10 status, col 12-265 the address        */
/*      status F found; N the user has none; X IRRXUTIL failed: the  */
/*      address in DB2 stays as it is                                */
/* RC 0 = done, 8 = USERLIST or USERMAIL could not be used, or every */
/*        userid failed (most likely missing authority)              */
/*                                                                   */
/* Updates:                                                          */
/*                                                                   */
/* Date     Who What                                                 */
/* -------- --- ---------------------------------------------------- */
/* yy/mm/dd ii  description                                          */
/* ----------------------------------------------------------------- */
"EXECIO * DISKR USERLIST (STEM in. FINIS"
if rc <> 0 then do
  say 'LWDR961 READ USERLIST RC' rc
  exit 8
end

out. = ''
found = 0
none = 0
failed = 0
do i = 1 to in.0
  userid = strip(left(in.i, 8))
  if userid = '' then iterate
  call lookup
  out.i = left(userid, 8) status left(email, 254)
end
out.0 = in.0

"EXECIO" out.0 "DISKW USERMAIL (STEM out. FINIS"
if rc <> 0 then do
  say 'LWDR961 WRITE USERMAIL RC' rc
  exit 8
end

say 'LWDR961 USERIDS READ:   ' in.0
say 'LWDR961 WITH AN ADDRESS:' found
say 'LWDR961 WITHOUT ONE:    ' none
say 'LWDR961 FAILED:         ' failed
if in.0 > 0 & failed = in.0 then do
  say 'LWDR961 EVERY USERID FAILED: CHECK THE AUTHORITY OF' userid()
  exit 8
end
exit 0

/* ----------------------------------------------------------------- */
/* lookup: status and email of one userid                            */
/* ----------------------------------------------------------------- */
lookup:
  drop RACF.
  email = ''
  myrc = IRRXUTIL('EXTRACT', 'USER', userid, 'RACF', '')
  parse var myrc rc1 rc2 rc3 rc4 rc5
  if rc1 <> 0 then do
    say 'LWDR961' userid 'IRRXUTIL RC' myrc
    status = 'X'
    failed = failed + 1
    return
  end

  /* No WORKATTR segment, or no WAEMAIL in it: no address            */
  if symbol('RACF.WORKATTR.WAEMAIL.1') = 'VAR' then
    email = strip(RACF.WORKATTR.WAEMAIL.1)
  if email = '' then do
    status = 'N'
    none = none + 1
  end
  else do
    status = 'F'
    found = found + 1
  end
  return
