/* REXX ------------------------------------------------------------ */
/* LWDR916: the result step, the last step of every deployment job   */
/* (S2). LWDM920 puts it there three times, under JCL IF tests, so   */
/* it learns the outcome from its arguments:                         */
/*   %LWDR916 runid result   runid 9 digits; result A a step         */
/*                           abended, O within the job's highest RC, */
/*                           H above it                              */
/*   %LWDR916 TEST           only sign in, to try the setup          */
/* It signs in to LWD's REST API as the userid of the job with an    */
/* access token from Entra ID (client credentials), and sends the    */
/* result to POST /jobResults. LWW checks the Entra token itself, in */
/* whichever region the call lands, and maps the Entra application   */
/* to the deploy userid (docs/12-iteration-8.md). LWD records the    */
/* result and has the CICS submit task submit the next job. No DB2   */
/* in this step, so the deploy userid needs no DB2 access in batch.  */
/* The token request carries a client assertion: a JWT signed with   */
/* the private key of the deploy userid's certificate, on its own    */
/* RACF key ring, by JWTSignerUtil (Java, jwt_signer), run through   */
/* z/OS UNIX with BPXWUNIX. Key ring and label are both named after  */
/* the userid. No secret is stored anywhere; the key stays in RACF.  */
/* Uses the z/OS client web enablement toolkit (HWTHTTP).            */
/*                                                                   */
/* In:  DD LWDCONF, one keyword=value per record, from the settings  */
/*      (LWDM920):                                                   */
/*      URL      https://host, or http://host when AT-TLS adds TLS   */
/*      PORT     port of LWW                                         */
/*      PATH     path prefix of the API, /lwdeploy/API/v1            */
/*      KEYRING  key ring with the CAs of LWW's and Entra's          */
/*               certificates (setting LWDRING)                      */
/*      TENANT   Entra tenant ID                                     */
/*      SCOPE    scope of LWD's API: <application ID>/.default       */
/*      CLIENTID Entra application of the deploy userid (DEPLAPP)    */
/*      JAVAHOME Java 21 or later                                    */
/*      JWTJARS  directory with the jars of JWTSignerUtil            */
/* Out: SYSTSPRT. The client assertion and the token are never shown.*/
/* RC 0 = recorded (TEST: signed in)                                 */
/*    4 = a late result, recorded on the run only; or the run was    */
/*        recorded already                                           */
/*    8 = not recorded: see SYSTSPRT. The run stays submitted until  */
/*        the scheduler marks it stuck (JOBMINS); then retry (D4)    */
/*                                                                   */
/* Updates:                                                          */
/*                                                                   */
/* Date     Who What                                                 */
/* -------- --- ---------------------------------------------------- */
/* yy/mm/dd ii  description                                          */
/* ----------------------------------------------------------------- */
parse upper arg runid jres .
/* Not RESULT: REXX sets that variable on every CALL */

ENTRA_HOST = 'login.microsoftonline.com'
/* Run 999999999 doesn't exist: TEST expects 404 with 04 01 for it   */
TEST_RUN = 999999999

test = (runid = 'TEST')
if \test then do
  if \datatype(runid, 'W') | length(runid) <> 9 | ,
     wordpos(jres, 'O H A') = 0 then do
    say 'LWDR916 USAGE: %LWDR916 RUNID(9 DIGITS) O|H|A, OR TEST'
    exit 8
  end
end

call readConf
if confbad then exit 8

user = strip(userid())
call jobInfo
if test then
  say 'LWDR916 TEST' user jobname jobid 'TO' conf.URL':'conf.PORT ,
      'CLIENT' conf.CLIENTID
else
  say 'LWDR916 RUN' runid 'RESULT' jres 'JOB' jobname jobid ,
      'USER' user

call hwtcalls 'on'
ReturnCode = -1
DiagArea. = ''
address hwthttp "hwtconst ReturnCode DiagArea."
if rc <> 0 | ReturnCode <> 0 then do
  say 'LWDR916 HWTCONST RC' rc ReturnCode ,
      'THE WEB ENABLEMENT TOOLKIT IS NOT AVAILABLE'
  exit 8
end

exitrc = 8
token = entraToken()
if token <> '' then do
  if connect(conf.URL, conf.PORT) then do
    if test then
      exitrc = testResult(token)
    else
      exitrc = sendResult(token)
    call disconnect
  end
end
token = ''

exit exitrc

/* ----------------------------------------------------------------- */
/* readConf: DD LWDCONF into conf.<keyword>; confbad 1 when it fails */
/* ----------------------------------------------------------------- */
readConf:
  confbad = 0
  conf. = ''
  "EXECIO * DISKR LWDCONF (STEM cf. FINIS"
  if rc <> 0 then do
    say 'LWDR916 READ LWDCONF RC' rc
    confbad = 1
    return
  end
  do i = 1 to cf.0
    parse var cf.i key '=' val
    key = translate(strip(key))
    if key <> '' then conf.key = strip(val)
  end
  keys = 'URL PORT PATH KEYRING TENANT SCOPE CLIENTID JAVAHOME JWTJARS'
  do k = 1 to words(keys)
    key = word(keys, k)
    if conf.key = '' then do
      say 'LWDR916 LWDCONF HAS NO' key
      confbad = 1
    end
  end
  conf.PATH = strip(conf.PATH, 'T', '/')
  conf.JWTJARS = strip(conf.JWTJARS, 'T', '/')
  conf.JAVAHOME = strip(conf.JAVAHOME, 'T', '/')
  /* They go into a shell command and a form: no quotes, blanks or   */
  /* other characters that would need escaping there                 */
  alnum = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' || ,
          '0123456789'
  do k = 1 to 5
    key = word('TENANT CLIENTID SCOPE JAVAHOME JWTJARS', k)
    allowed = alnum'-._'
    if key = 'SCOPE' then allowed = allowed':/'
    if key = 'JAVAHOME' | key = 'JWTJARS' then allowed = allowed'/'
    if verify(conf.key, allowed) > 0 then do
      say 'LWDR916 LWDCONF:' key 'HAS A CHARACTER THAT IS NOT ALLOWED'
      confbad = 1
    end
  end
  return

/* ----------------------------------------------------------------- */
/* jobInfo: job name from the TIOT, JES job ID from the SSIB         */
/* ----------------------------------------------------------------- */
jobInfo:
  tcb  = c2d(storage(21C, 4))
  tiot = c2d(storage(d2x(tcb + 12), 4))
  jobname = strip(storage(d2x(tiot), 8))
  jscb = c2d(storage(d2x(tcb + 180), 4))
  ssib = c2d(storage(d2x(jscb + 316), 4))
  jobid = strip(storage(d2x(ssib + 12), 8))
  return

/* ----------------------------------------------------------------- */
/* entraToken: an access token for LWD's API from Entra, with a      */
/* client assertion; '' when there is none. Up to 3 tries, after     */
/* waiting 2 and then 5 seconds, when Entra can't be reached or      */
/* answers 429 or 5xx. The assertion stays valid for 5 minutes, so   */
/* the tries share it.                                               */
/* ----------------------------------------------------------------- */
entraToken:
  tokenPath = '/'conf.TENANT'/oauth2/v2.0/token'
  jwt = clientAssertion('https://'ENTRA_HOST || tokenPath)
  if jwt = '' then return ''
  form = 'client_id='conf.CLIENTID || ,
         '&scope='urlEncode(conf.SCOPE) || ,
         '&grant_type=client_credentials' || ,
         '&client_assertion_type=' || ,
         urlEncode('urn:ietf:params:oauth:client-assertion-type:' || ,
                   'jwt-bearer') || ,
         '&client_assertion='jwt
  jwt = ''
  waits = '2 5'
  tok = ''
  do try = 1 to 3
    status = 0
    if connect('https://'ENTRA_HOST, 443) then do
      status = post(tokenPath, form, '', ,
                    'application/x-www-form-urlencoded')
      call disconnect
    end
    if status = 200 then do
      tok = jsonValue(ResponseBody, 'access_token')
      ResponseBody = ''
      if tok = '' then
        say 'LWDR916 ENTRA: NO ACCESS TOKEN IN THE RESPONSE'
      else if try > 1 then
        say 'LWDR916 ENTRA: TOKEN AT TRY' try
      leave
    end
    if status = 0 then
      say 'LWDR916 ENTRA: NO ANSWER AT TRY' try
    else do
      say 'LWDR916 ENTRA: HTTP' status 'AT TRY' try ,
          jsonValue(ResponseBody, 'error')
      edesc = jsonValue(ResponseBody, 'error_description')
      say 'LWDR916 ENTRA:' left(edesc, min(length(edesc), 240))
    end
    ResponseBody = ''
    if \(status = 0 | status = 429 | status >= 500) | try = 3 then
      leave
    call pause word(waits, try)
  end
  form = ''
  return tok

/* ----------------------------------------------------------------- */
/* clientAssertion: a JWT for audience aud, signed with the private  */
/* key of this userid's certificate, from JWTSignerUtil; '' when     */
/* there is none. Java runs in a z/OS UNIX process of its own, which */
/* doesn't inherit this step's environment: BPXWUNIX gets it.        */
/* stdout.encoding: Java writes the JWT in EBCDIC, as REXX reads it. */
/* ----------------------------------------------------------------- */
clientAssertion:
  parse arg aud
  jcmd = "'"conf.JAVAHOME"/bin/java' -Dstdout.encoding=IBM-1047" ,
         "-cp '"conf.JWTJARS"/*' yinnovate.JWTSignerUtil" ,
         user user user "'"aud"'" conf.CLIENTID
  jin.0 = 0
  jout.0 = 0
  jerr.0 = 0
  jenv.0 = 3
  jenv.1 = 'JAVA_HOME='conf.JAVAHOME
  jenv.2 = 'PATH=/bin:'conf.JAVAHOME'/bin'
  jenv.3 = 'HOME=/tmp'
  brc = bpxwunix(jcmd, 'jin.', 'jout.', 'jerr.', 'jenv.')
  /* The JWT is the last line that isn't empty                      */
  jwt = ''
  do i = jout.0 to 1 by -1 while jwt = ''
    jwt = strip(jout.i)
    jout.i = ''
  end
  b64url = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' || ,
           '0123456789-_'
  parse var jwt jh '.' jp '.' js
  isjwt = jh <> '' & jp <> '' & js <> '' & pos('.', js) = 0 & ,
          verify(jwt, b64url'.') = 0
  jh = ''; jp = ''; js = ''
  if brc = 0 & isjwt then return jwt
  jwt = ''
  say 'LWDR916 JWTSIGNERUTIL: EXIT STATUS' brc 'FOR' user ,
      'KEY RING' user 'LABEL' user
  if brc = 0 then
    say 'LWDR916 JWTSIGNERUTIL: ITS OUTPUT IS NOT A JWT'
  if brc = 127 then
    say 'LWDR916 JWTSIGNERUTIL: NO JAVA IN' conf.JAVAHOME'/bin'
  do i = 1 to min(jerr.0, 20)
    say 'LWDR916 JAVA:' left(jerr.i, min(length(jerr.i), 200))
  end
  return ''

/* ----------------------------------------------------------------- */
/* urlEncode: s for a form, %-encoded with the ASCII code of each    */
/* character other than A-Z a-z 0-9 - . _ ~. Only : and / can come   */
/* in here (readConf and the constants).                             */
/* ----------------------------------------------------------------- */
urlEncode: procedure
  parse arg s
  safe = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' || ,
         '0123456789-._~'
  out = ''
  do i = 1 to length(s)
    c = substr(s, i, 1)
    select
      when pos(c, safe) > 0 then out = out || c
      when c = ':' then out = out'%3A'
      when c = '/' then out = out'%2F'
      otherwise out = out || c
    end
  end
  return out

/* ----------------------------------------------------------------- */
/* connect: a connection to url (https://host or http://host) and    */
/* port; 1 when it is there                                          */
/* ----------------------------------------------------------------- */
connect:
  parse arg curl, cport
  ConnectionHandle = ''
  HandleType = HWTH_HANDLETYPE_CONNECTION
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthinit ReturnCode HandleType ConnectionHandle" ,
                  "DiagArea."
  if \ok('HWTHINIT CONNECTION') then return 0

  if \setOpt('ConnectionHandle', 'HWTH_OPT_URI', curl) then return 0
  if \setOpt('ConnectionHandle', 'HWTH_OPT_PORT', cport) then
    return 0
  if \setOpt('ConnectionHandle', 'HWTH_OPT_SNDTIMEOUTVAL', 60) then
    return 0
  if \setOpt('ConnectionHandle', 'HWTH_OPT_RCVTIMEOUTVAL', 60) then
    return 0
  if translate(left(curl, 6)) = 'HTTPS:' then do
    if \setOpt('ConnectionHandle', 'HWTH_OPT_USE_SSL', ,
               HWTH_SSL_USE) then return 0
    if \setOpt('ConnectionHandle', 'HWTH_OPT_SSLVERSION', ,
               HWTH_SSLVERSION_TLSv12) then return 0
    if \setOpt('ConnectionHandle', 'HWTH_OPT_SSLKEYTYPE', ,
               HWTH_SSLKEYTYPE_KEYRINGNAME) then return 0
    if \setOpt('ConnectionHandle', 'HWTH_OPT_SSLKEY', ,
               conf.KEYRING) then return 0
  end

  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthconn ReturnCode ConnectionHandle DiagArea."
  if \ok('HWTHCONN' curl':'cport) then return 0
  return 1

/* ----------------------------------------------------------------- */
/* disconnect: end the connection and free it                        */
/* ----------------------------------------------------------------- */
disconnect:
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthdisc ReturnCode ConnectionHandle DiagArea."
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthterm ReturnCode ConnectionHandle HWTH_NOFORCE" ,
                  "DiagArea."
  return

/* ----------------------------------------------------------------- */
/* pause: wait secs seconds; with z/OS UNIX sleep, which the OMVS    */
/* segment of the userid allows, or else by watching the clock       */
/* ----------------------------------------------------------------- */
pause:
  parse arg secs
  if syscalls('ON') <= 4 then do
    address syscall 'sleep' secs
    return
  end
  call time 'R'
  do while time('E') < secs
  end
  return

/* ----------------------------------------------------------------- */
/* sendResult: POST /jobResults; returns the step's RC               */
/* ----------------------------------------------------------------- */
sendResult:
  parse arg bearer
  rnum = runid + 0
  body = '{"runID":'rnum',"jobName":"'jobname'",' || ,
         '"jesJobID":"'jobid'","jobResult":"'jres'"}'
  status = post(conf.PATH'/jobResults', body, bearer, ,
                'application/json')
  bearer = ''

  ret = jsonValue(ResponseBody, 'retCode')
  rsn = jsonValue(ResponseBody, 'reasonCode')
  msg = jsonValue(ResponseBody, 'infoMessage')
  say 'LWDR916 POST /jobResults: HTTP' status ret rsn msg
  call refused status

  select
    when status = 200 then do
      say 'LWDR916 RUN' jsonValue(ResponseBody, 'runStatus') ,
          'DEPLOYMENT' jsonValue(ResponseBody, 'deplStatus') ,
          'NEXT RUN' jsonValue(ResponseBody, 'nextRunID')
      if rsn = '00' then return 0
      return 4
    end
    when status = 409 & rsn = '53' then return 4
    otherwise return 8
  end

/* ----------------------------------------------------------------- */
/* testResult: TEST, POST /jobResults for run TEST_RUN, which        */
/* doesn't exist. 404 with 04 01 means LWW took the Entra token,     */
/* mapped it to a userid allowed to run the transaction of           */
/* /jobResults, and LWD looked for the run. Nothing is recorded.     */
/* ----------------------------------------------------------------- */
testResult:
  parse arg bearer
  body = '{"runID":'TEST_RUN',"jobName":"'jobname'",' || ,
         '"jesJobID":"'jobid'","jobResult":"O"}'
  status = post(conf.PATH'/jobResults', body, bearer, ,
                'application/json')
  bearer = ''
  ret = jsonValue(ResponseBody, 'retCode')
  rsn = jsonValue(ResponseBody, 'reasonCode')
  say 'LWDR916 TEST POST /jobResults FOR RUN' TEST_RUN': HTTP' ,
      status ret rsn
  if status = 404 & ret = '04' & rsn = '01' then do
    say 'LWDR916 TEST: SIGNED IN WITH ENTRA; RUN NOT FOUND, AS EXPECTED'
    return 0
  end
  call refused status
  return 8

/* ----------------------------------------------------------------- */
/* refused: what a 401 or 403 from LWW most likely means             */
/* ----------------------------------------------------------------- */
refused:
  parse arg rstatus
  if rstatus = 401 then
    say 'LWDR916 LWW REFUSED THE ENTRA TOKEN: IS APPLICATION' ,
        conf.CLIENTID 'MAPPED TO' user 'IN LWW?'
  if rstatus = 403 then
    say 'LWDR916 NOT ALLOWED: MAY' user 'RUN THE TRANSACTION OF' ,
        '/jobResults?'
  return

/* ----------------------------------------------------------------- */
/* post: POST body (EBCDIC) of type ctype to path, with bearer when  */
/* it isn't ''; returns the HTTP status, or 0 when the request       */
/* failed. The body of the response, in EBCDIC, is in ResponseBody.  */
/* ----------------------------------------------------------------- */
post:
  parse arg rpath, rbody, rbearer, ctype
  RequestBody = ''
  ResponseBody = ''
  HttpStatusCode = 0
  RequestHandle = ''
  HandleType = HWTH_HANDLETYPE_HTTPREQUEST
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthinit ReturnCode HandleType RequestHandle" ,
                  "DiagArea."
  if \ok('HWTHINIT REQUEST') then return 0

  done = 0
  do 1
    if \setOpt('RequestHandle', 'HWTH_OPT_REQUESTMETHOD', ,
               HWTH_HTTP_REQUEST_POST) then leave
    if \setOpt('RequestHandle', 'HWTH_OPT_URI', rpath) then leave

    SListHandle = ''
    if \addHeader('HWTH_SLST_NEW', 'Content-Type:' ctype) then leave
    if \addHeader('HWTH_SLST_APPEND', 'Accept: application/json') ,
      then leave
    if rbearer <> '' then
      if \addHeader('HWTH_SLST_APPEND', ,
                    'Authorization: Bearer' rbearer) then leave
    rbearer = ''
    if \setOpt('RequestHandle', 'HWTH_OPT_HTTPHEADERS', SListHandle) ,
      then leave

    if \setOpt('RequestHandle', 'HWTH_OPT_TRANSLATE_REQBODY', ,
               HWTH_XLATE_REQBODY_E2A) then leave
    if \setOpt('RequestHandle', 'HWTH_OPT_TRANSLATE_RESPBODY', ,
               HWTH_XLATE_RESPBODY_A2E) then leave
    /* The body has its own variable, named in the call: the toolkit */
    /* reads it when it sends the request, not here, so it must stay */
    /* as it is until HWTHRQST. setOpt clears optValue at once.      */
    RequestBody = rbody
    rbody = ''
    ReturnCode = -1
    DiagArea. = ''
    address hwthttp "hwthset ReturnCode RequestHandle" ,
                    "HWTH_OPT_REQUESTBODY RequestBody DiagArea."
    if \ok('HWTHSET REQUESTBODY') then leave

    /* The toolkit puts the response body in the variable named here */
    ReturnCode = -1
    DiagArea. = ''
    address hwthttp "hwthset ReturnCode RequestHandle" ,
                    "HWTH_OPT_RESPONSEBODY_USERDATA ResponseBody" ,
                    "DiagArea."
    if \ok('HWTHSET RESPONSEBODY_USERDATA') then leave

    ReturnCode = -1
    DiagArea. = ''
    HttpReasonCode = ''
    address hwthttp "hwthrqst ReturnCode ConnectionHandle" ,
                    "RequestHandle HttpStatusCode HttpReasonCode" ,
                    "DiagArea."
    if \ok('HWTHRQST' rpath) then leave
    done = 1
  end
  /* It holds the client assertion on the request to Entra           */
  RequestBody = ''

  if SListHandle <> '' then do
    ReturnCode = -1
    DiagArea. = ''
    SList = ''
    address hwthttp "hwthslst ReturnCode RequestHandle HWTH_SLST_FREE" ,
                    "SListHandle SList DiagArea."
  end
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthterm ReturnCode RequestHandle HWTH_NOFORCE" ,
                  "DiagArea."

  if \done then return 0
  return HttpStatusCode + 0

/* ----------------------------------------------------------------- */
/* addHeader: a new list of headers, or one more on it               */
/* ----------------------------------------------------------------- */
addHeader:
  parse arg slstFunction, SList
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthslst ReturnCode RequestHandle" slstFunction ,
                  "SListHandle SList DiagArea."
  SList = ''
  return ok('HWTHSLST')

/* ----------------------------------------------------------------- */
/* setOpt: option optName (the name of an HWTH constant) of the      */
/* handle in variable handleName gets optValue                       */
/* ----------------------------------------------------------------- */
setOpt:
  parse arg handleName, optName, optValue
  ReturnCode = -1
  DiagArea. = ''
  address hwthttp "hwthset ReturnCode" handleName optName ,
                  "optValue DiagArea."
  optValue = ''
  return ok('HWTHSET' substr(optName, 10))

/* ----------------------------------------------------------------- */
/* ok: 1 when the last toolkit call worked, else the reason on       */
/* SYSTSPRT and 0                                                    */
/* ----------------------------------------------------------------- */
ok:
  parse arg what
  if rc = 0 & ReturnCode = HWTH_OK then return 1
  say 'LWDR916' what 'FAILED: RC' rc 'RETURNCODE' ReturnCode ,
      'SERVICE' DiagArea.HWTH_ServiceNum ,
      'REASON' DiagArea.HWTH_ReasonCode
  say 'LWDR916' strip(DiagArea.HWTH_ReasonDesc)
  return 0

/* ----------------------------------------------------------------- */
/* jsonValue: the value of key in the flat JSON object json, as      */
/* text, without quotes; '' when it isn't there. The responses of    */
/* LWD and Entra are flat and their texts contain no quotes, so this */
/* is enough here.                                                   */
/* ----------------------------------------------------------------- */
jsonValue: procedure
  parse arg json, key
  p = pos('"'key'"', json)
  if p = 0 then return ''
  rest = strip(substr(json, p + length(key) + 2), 'L')
  if left(rest, 1) <> ':' then return ''
  rest = strip(substr(rest, 2), 'L')
  if left(rest, 1) = '"' then do
    parse var rest '"' val '"' .
    return val
  end
  parse var rest val ',' .
  val = strip(translate(val, ' ', '}'))
  if val = 'null' then return ''
  return val
