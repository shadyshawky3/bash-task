#!/bin/bash

# إذا حدث أي خطأ في أي أمر، سيتم إيقاف السكربت فوراً.
set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source "$script_dir/helpers.sh"
source "$script_dir/db_operations.sh"
source "$script_dir/table_operations.sh"

mkdir -p DB
cd DB || { error_msg "Failed to enter database directory."; exit 1; }

while true; do
    print_title "Main Menu"
    echo "1. Create database"
    echo "2. List databases"
    echo "3. Drop database"
    echo "4. Connect to database"
    echo "5. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            read -p "Enter database name: " db_name
            create_database "$db_name"
            ;;
        2)
            list_databases
            ;;
        3)
            read -p "Enter database name to drop: " db_name
            drop_database "$db_name"
            ;;
        4)
            read -p "Enter database name to connect: " db_name
            if [[ -d "$db_name" ]]; then
                cd "$db_name" || { error_msg "Failed to connect to database '$db_name'."; continue; }
                connect_to_database "$db_name"
                cd ..
            else
                error_msg "Database not found."
            fi
            ;;
        5)
            echo "Goodbye!"; break ;;
        *)
            error_msg "Invalid choice in Main Menu."
            ;;
    esac
done

