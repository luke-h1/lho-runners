#!/bin/bash

# ======================
# This script cancels queued GitHub workflow runs for a repository or organization.
# Useful for clearing the queue when runners are having issues or when you need to reset and start fresh.
# ======================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install jq first.${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl first.${NC}"
    exit 1
fi


usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Cancel queued GitHub workflow runs.

OPTIONS:
    -r, --repo OWNER/REPO       Repository (e.g., luke-h1/repo)
    -o, --org ORG               Organization name (will process all repos)
    -w, --workflow NAME         Only cancel specific workflow by name (optional)
    -d, --dry-run               Show what would be cancelled without actually cancelling
    -t, --token TOKEN           GitHub token (or set GITHUB_TOKEN env var)
    -h, --help                  Show this help message

EXAMPLES:
    # Cancel all queued jobs in a repository
    export GITHUB_TOKEN=your_token
    $0 --repo luke-h1/repo

    # Dry run for an organization
    $0 --org org-name --dry-run

    # Cancel specific workflow
    $0 --repo luke-h1/repo --workflow "CI Pipeline"

EOF
    exit 1
}

REPO=""
ORG=""
WORKFLOW=""
DRY_RUN=false
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -o|--org)
            ORG="$2"
            shift 2
            ;;
        -w|--workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: GitHub token not provided. Set GITHUB_TOKEN env var or use --token${NC}"
    exit 1
fi

if [ -z "$REPO" ] && [ -z "$ORG" ]; then
    echo -e "${RED}Error: Either --repo or --org must be specified${NC}"
    usage
fi

if [ -n "$REPO" ] && [ -n "$ORG" ]; then
    echo -e "${RED}Error: Cannot specify both --repo and --org${NC}"
    usage
fi

cancel_repo_runs() {
    local repo=$1
    echo -e "${BLUE}Processing repository: $repo${NC}"
    
    local page=1
    local cancelled_count=0
    
    while true; do
        local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$repo/actions/runs?status=queued&per_page=100&page=$page")
        
        local runs=$(echo "$response" | jq -r '.workflow_runs[]')
        
        if [ -z "$runs" ] || [ "$runs" == "null" ]; then
            break
        fi
        
        local run_ids=$(echo "$response" | jq -r '.workflow_runs[].id')
        local workflow_names=$(echo "$response" | jq -r '.workflow_runs[].name')
        
        while IFS= read -r run_id && IFS= read -r workflow_name <&3; do
            if [ -n "$WORKFLOW" ] && [ "$workflow_name" != "$WORKFLOW" ]; then
                continue
            fi
            
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY RUN] Would cancel: Run ID $run_id - Workflow: $workflow_name${NC}"
            else
                echo -e "${YELLOW}Cancelling: Run ID $run_id - Workflow: $workflow_name${NC}"
                
                cancel_response=$(curl -s -X POST \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/$repo/actions/runs/$run_id/cancel" \
                    -w "\n%{http_code}")
                
                http_code=$(echo "$cancel_response" | tail -n1)
                
                if [ "$http_code" == "202" ]; then
                    echo -e "${GREEN}✓ Cancelled successfully${NC}"
                    ((cancelled_count++))
                else
                    echo -e "${RED}✗ Failed to cancel (HTTP $http_code)${NC}"
                fi
            fi
        done < <(echo "$run_ids") 3< <(echo "$workflow_names")
        
        local total_count=$(echo "$response" | jq -r '.total_count')
        local current_count=$((page * 100))
        
        if [ $current_count -ge $total_count ]; then
            break
        fi
        
        ((page++))
    done
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "${GREEN}Cancelled $cancelled_count workflow run(s) for $repo${NC}"
    fi
}

get_org_repos() {
    local org=$1
    local page=1
    local repos=()
    
    while true; do
        local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/$org/repos?per_page=100&page=$page")
        
        local repo_names=$(echo "$response" | jq -r '.[].full_name')
        
        if [ -z "$repo_names" ] || [ "$repo_names" == "null" ]; then
            break
        fi
        
        repos+=($repo_names)
        
        local count=$(echo "$response" | jq '. | length')
        if [ "$count" -lt 100 ]; then
            break
        fi
        
        ((page++))
    done
    
    echo "${repos[@]}"
}

echo -e "${GREEN}${NC}"
echo "================================"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No workflows will be cancelled${NC}"
fi

if [ -n "$WORKFLOW" ]; then
    echo -e "${BLUE}Filtering by workflow: $WORKFLOW${NC}"
fi

echo ""

if [ -n "$REPO" ]; then
    cancel_repo_runs "$REPO"
else
    echo -e "${BLUE}Fetching repositories for organization: $ORG${NC}"
    repos=$(get_org_repos "$ORG")
    
    if [ -z "$repos" ]; then
        echo -e "${YELLOW}No repositories found in organization${NC}"
        exit 0
    fi
    
    for repo in $repos; do
        cancel_repo_runs "$repo"
        echo ""
    done
fi

echo ""
echo -e "${GREEN}Done!${NC}" 