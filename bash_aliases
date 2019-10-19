# source this file into your Bash or zsh session to make some common
# commands available to you while testing the Slack API.
alias unit="scripts/unit"
alias integration="scripts/integration"
alias integration_no_destroy="KEEP_INTEGRATION_ENVIRONMENT_UP=true scripts/integration"
alias integration_test="docker-compose run --rm integration"
alias remove_functions="docker-compose run --rm serverless remove --stage develop"
alias remove_infra="docker-compose -f docker-compose.deploy.yml run --rm terraform destroy"
alias deploy="scripts/deploy"
alias destroy="remove_functions && remove_infra"
alias logs="docker-compose run --rm serverless logs --stage develop"
