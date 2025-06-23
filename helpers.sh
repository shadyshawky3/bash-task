RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function print_title() {
    echo -e "\n${YELLOW}==== $1 ====${NC}"
}

function success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

function error_msg() {
    echo -e "${RED}❌ $1${NC}"
}

function validate_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

