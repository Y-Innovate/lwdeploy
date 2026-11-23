#!/usr/lpp/IBM/foz/v1r1/bin/bash

export JAVA_HOME=/usr/lpp/java/J21.0_64

USER=LWDDEPL
KEYRING=LWDDEPL
KEYLABEL=LWDDEPL
APPID_LWDDEPL="<application ID of LWDDEPL>"
APPID_DEPLOY="<application ID of the LWD API>"
TENANTID="<tenant ID>"
LOGINURL="https://login.microsoftonline.com/$TENANTID/oauth2/v2.0/token"
JAR_LOCATION="<your clone of jwt_signer>/util/target"

# generate JWT for requesting access token for application with APPID
JWT_ACCESS=`$JAVA_HOME/bin/java -cp $JAR_LOCATION/yinnovate-jwt-signer-util-1.0.0.jar:$JAR_LOCATION/dependency/yinnovate-jwt-signer-1.0.0.jar:$JAR_LOCATION/dependency/nimbus-jose-jwt-9.37.jar yinnovate.JWTSignerUtil $USER "$KEYRING" "$KEYLABEL" "$LOGINURL" $APPID_LWDDEPL`

echo "JWT for requesting Bearer token: $JWT_ACCESS"

# request access token with JWT based on cert
ACCESS_RESPONSE=`curl -X POST $LOGINURL -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$APPID_LWDDEPL" -d "scope=$APPID_DEPLOY/.default" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" -d "client_assertion=$JWT_ACCESS"`

ACCESS_TOKEN=`echo "$ACCESS_RESPONSE" | sed 's/.*"access_token":"\([^"]*\)".*/\1/'`

echo "Access token for invoking the LWD API: $ACCESS_TOKEN"
