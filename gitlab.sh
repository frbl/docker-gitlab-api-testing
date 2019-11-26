#!/bin/bash
username=$1
password=$2
IMAGE=vitens/ecida/ecida-poc
REGISTRY=https://registry.gitlab.com
TAG=latest
SCOPE=repository:$IMAGE:*

# Docker stuff
#TOKEN=$(curl -s "https://$username:$password@gitlab.com/jwt/auth?service=container_registry&scope=$SCOPE" | jq -r .token)
#CONFIG_DIGEST=$(curl -s -H"Accept: application/vnd.docker.distribution.manifest.v2+json" -H"Authorization: Bearer $TOKEN" "$REGISTRY/v2/$IMAGE/manifests/$TAG" | jq -r .config.digest)
#LABELS=$(curl -sL -H"Authorization: Bearer $TOKEN" "$REGISTRY/v2/$IMAGE/blobs/$CONFIG_DIGEST" | jq -r .container_config.Labels)
#echo $LABELS

# Gitlab stuff
echo $(curl -sL -H "PRIVATE-TOKEN: $password" https://gitlab.com/api/v4/groups/vitens/projects\?include_subgroups=true | jq '.[] | select(.namespace.full_path == "vitens/ecida") | .name')
NAMESPACE_ID=$(curl -sL -H "PRIVATE-TOKEN: $password" https://gitlab.com/api/v4/namespaces | jq '.[] | select(.name=="components") | .id')
TEMPLATE_PROJECT_ID=$(curl -sL -H "PRIVATE-TOKEN: $password" https://gitlab.com/api/v4/groups/vitens/projects\?include_subgroups=true | jq '.[] | select(.namespace.full_path=="vitens/ecida/templates")| select(.name=="base") | .id')
GROUP_LEVEL_TEMPLATE_GROUP_ID=6577332
PROJECT_ID=$(curl -sL -H "PRIVATE-TOKEN: $password" -X POST "https://gitlab.com/api/v4/projects?name=foobartest8&namespace_id=$NAMESPACE_ID&template_project_id=$TEMPLATE_PROJECT_ID&use_custom_template=true&group_with_project_templates_id=$GROUP_LEVEL_TEMPLATE_GROUP_ID" | jq .id)


echo "Triggering build for $PROJECT_ID"
spin()
{
  spinner="/|\\-/|\\-"
  while :
  do
    for i in `seq 0 7`
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 1
    done
  done
}

# Start the Spinner:
spin &
SPIN_PID=$!
# Kill the spinner on any signal, including our own exit.
trap "kill -9 $SPIN_PID" `seq 0 15`

# Wait until the import is done
while true; do
  CONTENT=$(curl -X GET -sL -H "PRIVATE-TOKEN: $password" "https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/Dockerfile/raw?ref=master" | sed -e 's/# TAG-LABELS/LABEL test=test123/g')
  if [ "$CONTENT" != '{"message":"404 Commit Not Found"}' ]; then
    kill -9 $SPIN_PID
    break
  fi
done


# Trigger the pipeline
#TRIGGER_TOKEN=$(curl -sL -X POST -H "PRIVATE-TOKEN: $password" --form description="ECiDA trigger" "https://gitlab.com/api/v4/projects/$PROJECT_ID/triggers" | jq .token)
#TRIGGER_TOKEN=$(sed -e 's/^"//' -e 's/"$//' <<<"$TRIGGER_TOKEN")

#$(curl -sL -H "PRIVATE-TOKEN: $password" -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/trigger/pipeline?token=$TRIGGER_TOKEN&ref=master")

# Note that the -n is very important here. Without it it will send a newline at the end, which gives a 400
echo "{\"branch\": \"master\", \"author_email\": \"frank.blaauw@gmail.com\", \"author_name\": \"Frank Blaauw\", \"content\": \"$CONTENT\", \"commit_message\": \"Added metadata\"}" | awk '{printf "%s\\n", $0}' | sed -e 's/\\n$//g' > data.json

## NOT WORKING YET!
#curl -X PUT -sL -H "PRIVATE-TOKEN: $password" -H "Content-Type: application/json" --data "{\"branch\": \"master\", \"author_email\": \"frank.blaauw@gmail.com\", \"author_name\": \"Frank Blaauw\", \"content\": \"$CONTENT\", \"commit_message\": \"Added metadata\"}" https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/Dockerfile
curl -X PUT -sL -H "PRIVATE-TOKEN: $password" -H "Content-Type: application/json" --data @data.json https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/Dockerfile

echo ""
echo "Deleting $PROJECT_ID on enter"

read var1

curl -H "PRIVATE-TOKEN: $password" -X DELETE "https://gitlab.com/api/v4/projects/$PROJECT_ID"
