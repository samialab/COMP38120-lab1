#!/usr/bin/env bash
# Configure deployment point and optional parameters
[ -z "${LOGIN}" ] && { echo "Environment variable LOGIN is not set, defaulting user to sshuser"; LOGIN="sshuser"; }
[ -z "${ADMIN_LOGIN}" ] && { echo "Environment variable ADMIN_LOGIN is not set, defaulting admin-username to admin"; ADMIN_LOGIN="admin"; }
[ -z "${CLUSTER_NAME}" ] && { echo "Environment variable CLUSTER_NAME is not set."; read -p "Enter the Azure HDInsight cluster name: " CLUSTER_NAME; }
read -p "Enter the password to your admin account: " SEC
read -p "Enter number of reducers to run: " NUM_REDUCER

# If you have changed the class name or artifactId then you need to change those variables
CLASS_NAME=BasicInvertedIndex
JAR_NAME="lab1-1.0.jar"
JAR_LOCATION="./target/${JAR_NAME}"

# Validate login
echo "Authenticating your account"
STATE=`curl -u ${ADMIN_LOGIN}:${SEC} -G https://${CLUSTER_NAME}.azurehdinsight.net/templeton/v1/status | jq .status `
if [ -z "${STATE}" -o "${STATE}" = "" -o "${STATE}" != '"ok"' ] ; then
    echo "Authentication failed, exiting"
    exit 1
fi

echo "Packaging your code into a jar..."
mvn clean package

echo "Sending the Jar to your cluster"
scp ${JAR_LOCATION} ${LOGIN}@${CLUSTER_NAME}-ssh.azurehdinsight.net:${JAR_NAME}
# Put the jar in the hadoop distributed file store to be accessible by all nodes
ssh ${LOGIN}@${CLUSTER_NAME}-ssh.azurehdinsight.net hadoop fs -put -f ${JAR_NAME}

echo "Executing the mapreduce job"
JOB_ID=`curl -u ${ADMIN_LOGIN}:${SEC} -d user.name=${LOGIN} -d jar=${JAR_NAME} -d class=${CLASS_NAME} -d arg="-input" -d arg="/input/" -d arg="-output" -d arg="/comp38120/output" -d arg="-numReducers" -d arg=${NUM_REDUCER} https://${CLUSTER_NAME}.azurehdinsight.net/templeton/v1/mapreduce/jar | jq .id`

echo "Job id: ${JOB_ID}"

echo "Check your job progress on https://${CLUSTER_NAME}.azurehdinsight.net/yarnui/hn/cluster"