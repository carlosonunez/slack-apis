#!/usr/bin/bash

docker-compose -f docker-compose.deploy.yml run --rm serverless remove --stage develop && \
docker-compose -f docker-compose.deploy.yml run --rm terraform destroy && \
rm -rf vendor && \
rm -rf secrets
