#!/bin/bash
username=$1
password=$2
IMAGE=vitens/ecida/ecida-poc
REGISTRY=https://registry.gitlab.com
TAG=latest
SCOPE=repository:$IMAGE:*
TOKEN=$(curl -s "https://$username:$password@gitlab.com/jwt/auth?service=container_registry&scope=$SCOPE" | jq -r .token)
echo $(curl -s "https://$username:$password@gitlab.com/jwt/auth?service=container_registry&scope=$SCOPE" | jq )
echo $(curl -s -H"Accept: application/vnd.docker.distribution.manifest.v2+json" -H"Authorization: Bearer $TOKEN" "$REGISTRY/v2/_catalog" | jq )
echo $(curl -s -H"Accept: application/vnd.docker.distribution.manifest.v2+json" -H"Authorization: Bearer $TOKEN" "$REGISTRY/v2/$IMAGE/manifests/$TAG" | jq )
CONFIG_DIGEST=$(curl -s -H"Accept: application/vnd.docker.distribution.manifest.v2+json" -H"Authorization: Bearer $TOKEN" "$REGISTRY/v2/$IMAGE/manifests/$TAG" | jq -r .config.digest)
LABELS=$(curl -sL -H"Authorization: Bearer $TOKEN" "$REGISTRY/v2/$IMAGE/blobs/$CONFIG_DIGEST" | jq -r .container_config.Labels)
echo $LABELS
