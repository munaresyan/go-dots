#!/usr/bin/env bash
cd `dirname $0`

export DOTS_BRANCH=add_aaa
export DOTS_SERVER=127.0.0.1
export SIGNAL_CHANNEL_PORT=4646
export DATA_CHANNEL_PORT=4647

set -x
#docker-compose up -d

docker container restart dots_server-radius_test

mysql -u root --port 3306 < ../../
rm /tmp/dots_success_auth.sock
rm /tmp/dots_invalid_auth.sock

make -C ../../dots_client
make -C ../../dots_client_controller

# access successfully client --------------------------------------------
../../dots_client/dots_client -vv -server $DOTS_SERVER -signalChannelPort $SIGNAL_CHANNEL_PORT -dataChannelPort $DATA_CHANNEL_PORT \
    -certFile ../../certs/ca-cert.pem \
    -clientCertFile ../../certs/client-cert.pem \
    -clientKeyFile ../../certs/client-key.pem \
    -socket /tmp/dots_success_auth.sock &
SUCCESS_CLIENT_PID=$!
sleep 1

# invalid user client ---------------------------------------------------
../../dots_client/dots_client -vv -server $DOTS_SERVER -signalChannelPort $SIGNAL_CHANNEL_PORT -dataChannelPort $DATA_CHANNEL_PORT \
    -certFile ../../certs/ca-cert.pem \
    -clientCertFile ../../certs/invalid_client-cert.pem \
    -clientKeyFile ../../certs/invalid_client-key.pem \
    -socket /tmp/dots_invalid_auth.sock &
INVALID_CLIENT_PID=$!
sleep 1


# access(success) -------------------------------------------------------
../../dots_client_controller/dots_client_controller -vv -request hello -method Post \
    -socket /tmp/dots_success_auth.sock \
    -json ../../dots_client_controller/sampleHello.json

# access(invalid) -------------------------------------------------------
../../dots_client_controller/dots_client_controller -vv -request hello -method Post \
    -socket /tmp/dots_invalid_auth.sock \
    -json ../../dots_client_controller/sampleHello.json


# radius server down ----------------------------------------------------
docker container pause radius-radius_test

../../dots_client_controller/dots_client_controller -vv -request hello -method Post \
    -socket /tmp/dots_success_auth.sock \
    -json ../../dots_client_controller/sampleHello.json

kill $SUCCESS_CLIENT_PID
kill $INVALID_CLIENT_PID

#docker-compose stop
docker container unpause radius-radius_test