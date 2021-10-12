#!/usr/bin/env bash
#run:
#chmod +x scripts/init_db.sh

#Run:
#./scripts/init_db.sh
#SKIP_DOCKER=true ./scripts/init_db.sh


#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v mongosh)" ]; then
  echo >&2 "Error: mongosh is not installed."
  exit 1
fi

# Check if a custom user has been set, otherwise default to 'mongo'
DB_USER="${MONGO_USER:=mongo}"
# Check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD="${MONGO_PASSWORD:=password}"
# Check if a custom db has been set, otherwise default to 'newsletter'
DB_NAME="${MONGO_DB:=test_EN2}"
# Check if a custom port has been set, otherwise default to '5432'
DB_PORT="${MONGO_PORT:=27017}"
# Check if a custom host has been set, otherwise default to 'localhost'
DB_HOST="${MONGO_HOST:=localhost}"
# Form a database url, example: "mongodb://localhost:27017/db1"
DATABASE_URL="mongodb://${DB_HOST}:${DB_PORT}/${DB_NAME}"
# export variable
export DATABASE_URL=${DATABASE_URL} 


# Allow to skip Docker if a dockerized Mongo database is already running
if [[ -z "${SKIP_DOCKER}" ]]
then
  # if a mongo container is running, print instructions to kill it and exit
  RUNNING_MONGO_CONTAINER=$(docker ps --filter 'name=mongo' --format '{{.ID}}')
  if [[ -n $RUNNING_MONGO_CONTAINER ]]; then
    echo >&2 "there is a mongodb container already running, kill it with"
    echo >&2 "    docker kill ${RUNNING_MONGO_CONTAINER}"
    exit 1
  fi
  # Launch mongo using Docker
  docker run \
      -e MONGO_USER=${DB_USER} \
      -e MONGO_PASSWORD=${DB_PASSWORD} \
      -e MONGO_DB=${DB_NAME} \
      -p "${DB_PORT}":27017 \
	  --name "MONGO_$(date '+%s')" \
	  -d mongo:latest
      
fi

# Keep pinging Mongo until it's ready to accept commands
until mongosh ${DATABASE_URL} --eval 'quit();'; do
  >&2 echo "Mongo is still unavailable - sleeping"
  sleep 1
done

>&2 echo "Mongo is up and running on port ${DB_PORT} - running migrations now!"

mongosh ${DATABASE_URL}  --eval 'load("../migrations/create_test_collection.js"); quit();';

>&2 echo "Mongo has been migrated, ready to go!"