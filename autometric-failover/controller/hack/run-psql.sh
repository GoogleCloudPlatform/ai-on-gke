#!/bin/bash

docker run -it --rm --network host postgres psql -h localhost -U postgres