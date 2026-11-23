//LWDETST  JOB 'LWD ENTRA TEST',CLASS=A,MSGCLASS=A,NOTIFY=&SYSUID,
//             USER={{DEPLOYUSER}}
//*
//* Tries the sign-in of the result step before the first deployment
//* of iteration 8 (docs/12-iteration-8.md): LWDR916 TEST gets a
//* client assertion from JWTSignerUtil, signed with the certificate
//* on key ring {{DEPLOYUSER}}, trades it for an access token at
//* Entra, and calls POST /jobResults for a run that doesn't exist.
//* It records nothing. It runs under {{DEPLOYUSER}}, as the result
//* step does: you need READ on SURROGAT {{DEPLOYUSER}}.SUBMIT for
//* the test, remove that afterwards.
//* RC 0 = signed in: Entra gave a token, LWW mapped it to the userid
//* and LWD answered 404 (run not found). 8 = see SYSTSPRT.
//*
//TEST     EXEC PGM=IKJEFT1B,PARM='%LWDR916 TEST',REGION=1024M
//SYSEXEC  DD DISP=SHR,DSN={{EXECLIB}}
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DUMMY
//LWDCONF  DD *
URL={{LWDURL}}
PORT={{LWDPORT}}
PATH={{LWDPATH}}
KEYRING={{LWDKEYRING}}
TENANT={{ENTRATENANT}}
SCOPE={{LWDAPISCOPE}}
CLIENTID={{DEPLOYAPPID}}
JAVAHOME={{JAVAHOME}}
JWTJARS={{JWTJARS}}
/*
