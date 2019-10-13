# source this file into your Bash or zsh session to make some common
# commands available to you while testing the Slack API.
alias unit="scripts/unit"
alias integration="scripts/integration"
alias remove_functions="docker-compose run --rm serverless remove"
alias remove_infra="docker-compose -f docker-compose.deploy.yml run --rm terraform destroy"
