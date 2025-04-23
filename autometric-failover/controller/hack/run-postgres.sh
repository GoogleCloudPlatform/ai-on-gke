#!/bin/bash

# Delete the container if it already exists
docker rm -f autometric-postgres

# Run the container
docker run --name autometric-postgres \
    -p 5432:5432 \
    -e POSTGRES_PASSWORD=pass \
    -d postgres
