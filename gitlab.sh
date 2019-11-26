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


initializeRepository() {
  preConditions=$(echo "$1" | tr '\n' ' ' | tr '"' "'")
  postConditions=$(echo "$2" | tr '\n' ' ' | tr '"' "'")
  imageName="$3"

  NAMESPACE_ID=$(curl -sL -H "PRIVATE-TOKEN: $password" https://gitlab.com/api/v4/namespaces | jq '.[] | select(.name=="components") | .id')
  TEMPLATE_PROJECT_ID=$(curl -sL -H "PRIVATE-TOKEN: $password" https://gitlab.com/api/v4/groups/vitens/projects\?include_subgroups=true | jq '.[] | select(.namespace.full_path=="vitens/ecida/templates")| select(.name=="base") | .id')
  GROUP_LEVEL_TEMPLATE_GROUP_ID=6577332
  PROJECT_ID=$(curl -sL -H "PRIVATE-TOKEN: $password" -X POST "https://gitlab.com/api/v4/projects?name=$imageName&namespace_id=$NAMESPACE_ID&template_project_id=$TEMPLATE_PROJECT_ID&use_custom_template=true&group_with_project_templates_id=$GROUP_LEVEL_TEMPLATE_GROUP_ID" | jq .id)
  echo "\n\nTriggering build for $PROJECT_ID ($imageName)"

  # Wait until the import is done
  while true; do
    temp_content=$(curl -X GET -sL -H "PRIVATE-TOKEN: $password" "https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/Dockerfile/raw?ref=master")
    if [ "$temp_content" != '{"message":"404 Commit Not Found"}' ]; then
      break
    else
      echo 'Waiting...'
    fi
  done

  content=$(echo $temp_content | awk '{printf "%s\\n", $0}')
  temp_conten=$content

  content=$(echo $temp_content | sed -e "s/# TAG-LABELS/\\\nLABEL nl.vitens.preconditions=\"$preConditions\" \\\nLABEL nl.vitens.postconditions=\"$postConditions\"/g")

  # Trigger the pipeline
  #TRIGGER_TOKEN=$(curl -sL -X POST -H "PRIVATE-TOKEN: $password" --form description="ECiDA trigger" "https://gitlab.com/api/v4/projects/$PROJECT_ID/triggers" | jq .token)
  #TRIGGER_TOKEN=$(sed -e 's/^"//' -e 's/"$//' <<<"$TRIGGER_TOKEN")

  #$(curl -sL -H "PRIVATE-TOKEN: $password" -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/trigger/pipeline?token=$TRIGGER_TOKEN&ref=master")

  # Note that the -n is very important here. Without it it will send a newline at the end, which gives a 400
  echo "{\"branch\": \"master\", \"author_email\": \"frank.blaauw@gmail.com\", \"author_name\": \"Frank Blaauw\", \"content\": \"$content\", \"commit_message\": \"Added metadata\"}" >data.json

  ## NOT WORKING YET!
  #curl -X PUT -sL -H "PRIVATE-TOKEN: $password" -H "Content-Type: application/json" --data "{\"branch\": \"master\", \"author_email\": \"frank.blaauw@gmail.com\", \"author_name\": \"Frank Blaauw\", \"content\": \"$content\", \"commit_message\": \"Added metadata\"}" https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/Dockerfile
  curl -X PUT -sL -H "PRIVATE-TOKEN: $password" -H "Content-Type: application/json" --data @data.json https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/Dockerfile
}

read -r -d '' preConditions <<EOM
[
  {
    "condition": "is-RawPiData",
    "operation": "=:=",
    "value": "true"
  },
  {
    "condition": "is-state",
    "operation": "=:=",
    "value": "true"
  }
]
EOM

read -r -d '' postConditions <<EOM
[
  {
    "condition": "is-RawPiData",
    "operation": "=:=",
    "value": "false"
  },
  {
    "condition": "is-WaterDataPIV1",
    "operation": "=:=",
    "value": "true"
  }
]
EOM
initializeRepository "$preConditions" "$postConditions" "WaterDataPI"
proj_1_id=$PROJECT_ID

read -r -d '' preConditions <<EOM
[
  {
    "condition": "is-WaterDataPIV1",
    "operation": "=:=",
    "value": "true"
  },
  {
    "condition": "is-state",
    "operation": "=:=",
    "value": "true"
  }
]
EOM

read -r -d '' postConditions <<EOM
[
  {
    "condition": "is-WaterDataPIV1",
    "operation": "=:=",
    "value": "false"
  },
  {
    "condition": "is-NachtwachtProcessingV1",
    "operation": "=:=",
    "value": "true"
  }
]
EOM
initializeRepository "$preConditions" "$postConditions" "NachtwachtProcessing"
proj_2_id=$PROJECT_ID

read -r -d '' preConditions <<EOM
[
  {
    "condition": "is-NachtwachtProcessingV1",
    "operation": "=:=",
    "value": "true"
  },
  {
    "condition": "is-state",
    "operation": "=:=",
    "value": "true"
  }
]
EOM

read -r -d '' postConditions <<EOM
[
  {
    "condition": "is-NachtwachtProcessingV1",
    "operation": "=:=",
    "value": "false"
  },
  {
    "condition": "is-NachtwachtHTMLProcessingV1",
    "operation": "=:=",
    "value": "true"
  }
]
EOM
initializeRepository "$preConditions" "$postConditions" "NachtwachtHTMLProcessing"
proj_3_id=$PROJECT_ID

# Retrieve all components
echo "\n\nAll projects in the repo"
echo $(curl -sL -H "PRIVATE-TOKEN: $password" https://gitlab.com/api/v4/groups/vitens/projects\?include_subgroups=true | jq '.[] | select(.namespace.full_path == "vitens/ecida/components") | .name')

echo "Deleting projects on enter"

read var1


curl -H "PRIVATE-TOKEN: $password" -X DELETE "https://gitlab.com/api/v4/projects/$proj_1_id"
curl -H "PRIVATE-TOKEN: $password" -X DELETE "https://gitlab.com/api/v4/projects/$proj_2_id"
curl -H "PRIVATE-TOKEN: $password" -X DELETE "https://gitlab.com/api/v4/projects/$proj_3_id"
