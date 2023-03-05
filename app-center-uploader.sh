#!/bin/bash
####################################################################################################
# Script upload the apk file to Microsoft App Center Console:
# Sample from: https://github.com/microsoft/appcenter-Xamarin.UITest-Demo/blob/main/ac-distribute.sh
# Doc: https://docs.microsoft.com/en-us/appcenter/distribution/uploading
# --------------------------------------------------------------------------------------------------
# !!!Attention!!! To work as well the current script needed credential file with next params:
#   * API_TOKEN
#   * APP_NAME
#   * OWNER_NAME
#   * DISTRIBUTION_GROUP
####################################################################################################

function howTo() {
  echo
  echo "See how to below!"
  echo "Usage, run:"
  echo -e "\t./$(basename ${BASH_SOURCE}) [options]"
  echo
  echo "Supported options:"
  echo -e "\t'-f, --file (required)' - path to apk build file."
  echo -e "\t'-c, --credentials (required)' - path to credentials file with AppCenter token and other private data."
  echo
  echo -e "For example:"
  echo -e "\t./$(basename ${BASH_SOURCE}) -f ./app/build/outputs/apk/release/app-release.apk -c ./credentials.sh"
  echo -e "\t./$(basename ${BASH_SOURCE}) --file ./app/build/outputs/apk/release/app-release.apk --credentials ./credentials.sh"
  echo
}

# Read input params
while :; do
	case ${1} in
		-h|-\?|--help)
		  howTo
			exit 0
			;;
		-f|--file)
		  APK_BUILD_FILE=${2}
    	shift
		  ;;
		-c|--credentials)
		  CREDENTIALS_FILE=${2}
    	shift
		  ;;
		-:)
		  printf "missing argument for ${1}\n" "${2}" >&2
      howTo
      exit 1
      ;;
    --)
    	shift
      break
      ;;
	  -?*)
	    printf "illegal option: ${1}\n" "${2}" >&2
      howTo
      exit 1
      ;;
    *)
      break
	esac
	shift
done

#####################################################################################
# Check input params;
#####################################################################################

if [[ ! -f "${APK_BUILD_FILE}" ]]; then
  echo "Error! Apk file not found, APK_BUILD_FILE: '${APK_BUILD_FILE}'"
  echo "Please set path to apk file to script arguments."
  howTo
  exit 1
fi

if [[ ! -f "${CREDENTIALS_FILE}" ]]; then
  echo "Error! AppCenter credentials file with API_TOKEN not found, CREDENTIALS_FILE: ${CREDENTIALS_FILE}!"
  echo "Please set path to credentials file to script arguments."
  howTo
  exit 1
fi

# shellcheck disable=SC1090
. "${CREDENTIALS_FILE}"

if [[ -z "${API_TOKEN}" ]] || [[ -z "${APP_NAME}" ]] || [[ -z "${OWNER_NAME}" ]] || [[ -z "${DISTRIBUTION_GROUPS}" ]]; then
  echo "Error! Some of credential params is empty: "
  echo "* API_TOKEN: '${API_TOKEN}'"
  echo "* APP_NAME: '${APP_NAME}'"
  echo "* OWNER_NAME: '${OWNER_NAME}'"
  echo "* DISTRIBUTION_GROUPS: '${DISTRIBUTION_GROUPS}'"
  echo "Please set params to credential file."
  howTo
  exit 1
fi

#####################################################################################
# Main code;
#####################################################################################

#APK_BUILD_FILE="./app/build/outputs/apk/debug/app-debug.apk"
CONTENT_TYPE="application/vnd.android.package-archive"
SPLIT_DIR="./build/app-center-split"

# Vars to simplify frequently used syntax
UPLOAD_DOMAIN="https://file.appcenter.ms/upload"
API_URL="https://api.appcenter.ms/v0.1/apps/$OWNER_NAME/$APP_NAME"
AUTH="X-API-Token: $API_TOKEN"
ACCEPT_JSON="Accept: application/json"
CONTENT_TYPE="application/vnd.android.package-archive"

# Body - Step 1/8
echo "Creating release (1/8)"
request_url="$API_URL/uploads/releases"
upload_json=$(curl -s -X POST -H "Content-Type: application/json" -H "$ACCEPT_JSON" -H "$AUTH" "$request_url")
echo "API Response: $upload_json"

if [[ -z "${upload_json}" ]]; then
  echo "Something went wrong! API response is empty!"
  exit 1
fi

releases_id=$(echo $upload_json | jq -r '.id')
package_asset_id=$(echo $upload_json | jq -r '.package_asset_id')
url_encoded_token=$(echo $upload_json | jq -r '.url_encoded_token')

file_name=$(basename $APK_BUILD_FILE)
file_size=$(eval wc -c $APK_BUILD_FILE | awk '{print $1}')

# Step 2/8
echo "Creating metadata (2/8)"
metadata_url="$UPLOAD_DOMAIN/set_metadata/$package_asset_id?file_name=$file_name&file_size=$file_size&token=$url_encoded_token&content_type=$CONTENT_TYPE"

meta_response=$(curl -s -d POST -H "Content-Type: application/json" -H "$ACCEPT_JSON" -H "$AUTH" "$metadata_url")
chunk_size=$(echo $meta_response | jq -r '.chunk_size')

echo $meta_response
echo $chunk_size

mkdir -p $SPLIT_DIR
eval split -b $chunk_size $APK_BUILD_FILE $SPLIT_DIR/split

# Step 3/8
echo "Uploading chunked binary (3/8)"
binary_upload_url="$UPLOAD_DOMAIN/upload_chunk/$package_asset_id?token=$url_encoded_token"

block_number=0
for i in $SPLIT_DIR/*
do
    block_number=$(($block_number + 1))
    echo "start uploading chunk $block_number: $i"
    url="$binary_upload_url&block_number=$block_number"
    size=$(wc -c $i | awk '{print $1}')
    curl -X POST $url --data-binary "@$i" -H "Content-Length: $size" -H "Content-Type: $CONTENT_TYPE"
    printf "\n"
done

# Step 4/8
echo "Finalising upload (4/8)"
finish_url="$UPLOAD_DOMAIN/finished/$package_asset_id?token=$url_encoded_token"
curl -d POST -H "Content-Type: application/json" -H "$ACCEPT_JSON" -H "$AUTH" "$finish_url"
echo

# Step 5/8
echo "Commit release (5/8)"
commit_url="$API_URL/uploads/releases/$releases_id"
curl -H "Content-Type: application/json" -H "$ACCEPT_JSON" -H "$AUTH" \
  --data '{"upload_status": "uploadFinished","id": "$releases_id"}' \
  -X PATCH \
  $commit_url
echo

# Step 6/8
echo "Polling for release id (6/8)"
release_id=null
counter=0
max_poll_attempts=300
echo "max_poll_attempts=$max_poll_attempts"

while [[ $release_id == null && ($counter -lt $max_poll_attempts)]]
do
    poll_result=$(curl -s -H "Content-Type: application/json" -H "$ACCEPT_JSON" -H "$AUTH" $commit_url)
    release_id=$(echo $poll_result | jq -r '.release_distinct_id')
    echo $counter $release_id
    counter=$((counter + 1))
    sleep 3
done

if [[ $release_id == null ]];
then
    echo "Failed to find release from appcenter"
    exit 1
fi

# Step 7/8
echo "Applying destination to release (7/8)"

if [[ ! -z ${DISTRIBUTION_GROUPS} ]]; then
  IFS=',' read -ra TESTER_GROUPS <<< "${DISTRIBUTION_GROUPS}"
  for group in "${TESTER_GROUPS[@]}"; do
    if [[ ! -z "${DISTRIBUTION_GROUPS_DATA}" ]]; then
      DISTRIBUTION_GROUPS_DATA+=","
    fi
    DISTRIBUTION_GROUPS_DATA+="{ \"name\": \"$group\"}"
  done
fi

distribute_url="$API_URL/releases/$release_id"
curl -H "Content-Type: application/json" -H "$ACCEPT_JSON" -H "$AUTH" \
  --data '{"destinations": ['"${DISTRIBUTION_GROUPS_DATA}"'] }' \
  -X PATCH \
  $distribute_url
echo

# Step 8/8
echo "Clean cache (8/8)"
rm -rv "${SPLIT_DIR}"

echo
echo "Downloading file link: https://appcenter.ms/orgs/$OWNER_NAME/apps/$APP_NAME/distribute/releases/$release_id"
echo
