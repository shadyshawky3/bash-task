function create_database() {
    local db="$1"
    if [[ -d "$db" ]]; then
        error_msg "Database already exists."
    else
        mkdir "$db"
        success_msg "Database '$db' created."
    fi
}

function list_databases() {
    print_title "Databases"
    ls -F | grep / || echo "No databases."
}

function drop_database() {
    local db="$1"
    if [[ -d "$db" ]]; then
        rm -r "$db"
        success_msg "Database '$db' dropped."
    else
        error_msg "Database not found."
    fi
}

