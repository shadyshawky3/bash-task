function create_table_func() {
    local tname="$1"
    if [[ -f "$tname" ]]; then
        error_msg "Table already exists."
    else
        read -p "Number of columns: " col_count
        if ! validate_number "$col_count" || [ "$col_count" -le 0 ]; then
            error_msg "Invalid column number."
        else
            touch "$tname"
            touch "${tname}_meta"
            echo -n "" > "${tname}_meta"
            local col_names=""
            local col_types=""
            local pk=""

            for ((i=1; i<=col_count; i++)); do
                read -p "Enter column $i name: " cname
                echo "Select data type:"
                echo "1) string"
                echo "2) int"
                read -p "Your choice: " type_choice

                local ctype=""
                case "$type_choice" in
                    1) ctype="string" ;;
                    2) ctype="int" ;;
                    *) error_msg "Invalid data type choice."; i=$((i-1)); continue ;;
                esac
                col_names+="$cname:"
                col_types+="$ctype:"
                if [[ $i -eq 1 ]]; then
                    pk="$cname"
                fi
            done
            echo "${col_names%:}" >> "${tname}_meta"
            echo "${col_types%:}" >> "${tname}_meta"
            echo "$pk" >> "${tname}_meta"
            success_msg "Table '$tname' created with PK '$pk'."
        fi
    fi
}

function list_tables_func() {
    print_title "Tables in $(basename "$(pwd)")"
    find . -maxdepth 1 -type f ! -name "*_meta" -printf "%f\n" | grep -v "^.$" || echo "No tables."
}

function drop_table_func() {
    local tname="$1"
    if [[ -f "$tname" ]]; then
        rm -f "$tname" "${tname}_meta"
        success_msg "Table '$tname' dropped."
    else
        error_msg "Table not found."
    fi
}

function insert_into_table_func() {
    local tname="$1"
    if [[ ! -f "$tname" ]]; then
        error_msg "Table not found."
    else
        local col_names_line=$(head -1 "${tname}_meta")
        local col_types_line=$(head -2 "${tname}_meta" | tail -1)
        local pk_col=$(head -3 "${tname}_meta" | tail -1)
        IFS=':' read -ra col_names_arr <<< "$col_names_line"
        IFS=':' read -ra col_types_arr <<< "$col_types_line"
        local values=()

        for ((i=0; i<${#col_names_arr[@]}; i++)); do
            local col=${col_names_arr[$i]}
            local type=${col_types_arr[$i]}
            while true; do
                read -p "Enter value for $col ($type): " val
                if [[ "$type" == "int" && ! "$val" =~ ^[0-9]+$ ]]; then
                    error_msg "Value must be an integer."
                    continue
                fi
                if [[ "$col" == "$pk_col" ]]; then
                    local idx=$i
                    if cut -d: -f$((idx+1)) "$tname" | grep -qx "$val"; then
                        error_msg "Duplicate PK."
                        continue
                    fi
                fi
                values+=("$val")
                break
            done
        done
        echo "${values[*]}" | tr ' ' ':' >> "$tname"
        success_msg "Row inserted successfully."
    fi
}

function select_from_table_func() {
    local tname="$1"
    if [[ -f "$tname" ]]; then
        print_title "Content of $tname"
        cat "$tname"
    else
        error_msg "Table not found."
    fi
}

function update_table_func() {
    local tname="$1"
    if [[ ! -f "$tname" ]]; then
        error_msg "Table not found."
    else
        local col_names_line=$(head -1 "${tname}_meta")
        local col_types_line=$(head -2 "${tname}_meta" | tail -1)
        local pk_col=$(head -3 "${tname}_meta" | tail -1)
        IFS=':' read -ra col_names_arr <<< "$col_names_line"
        IFS=':' read -ra col_types_arr <<< "$col_types_line"

        read -p "Enter the PK value of the row to update: " pk_value

        local pk_index_in_awk=-1
        for ((i=0; i<${#col_names_arr[@]}; i++)); do
            if [[ "${col_names_arr[$i]}" == "$pk_col" ]]; then
                pk_index_in_awk=$((i + 1))
                break
            fi
        done

        if [[ "$pk_index_in_awk" -eq -1 ]]; then
            error_msg "Primary key column not found in metadata. This should not happen."
            return
        fi

        if ! awk -F: -v pk_idx="$pk_index_in_awk" -v pk_val="$pk_value" '$pk_idx == pk_val {found=1; exit} END{exit !found}' "$tname"; then
            error_msg "Row with PK '$pk_value' not found."
            return
        fi

        echo "Available columns for update:"
        for ((i=0; i<${#col_names_arr[@]}; i++)); do
            echo "$((i+1)). ${col_names_arr[$i]} (${col_types_arr[$i]})"
        done

        while true; do
            read -p "Enter the number of the column to update (or 0 to cancel): " col_num_to_update
            if ! validate_number "$col_num_to_update" || [ "$col_num_to_update" -lt 0 ] || [ "$col_num_to_update" -gt ${#col_names_arr[@]} ]; then
                error_msg "Invalid column number."
                continue
            elif [ "$col_num_to_update" -eq 0 ]; then
                error_msg "Update cancelled."
                break
            else
                local col_index=$((col_num_to_update - 1))
                local selected_col_name="${col_names_arr[$col_index]}"
                local selected_col_type="${col_types_arr[$col_index]}"

                if [[ "$selected_col_name" == "$pk_col" ]]; then
                    error_msg "Cannot update Primary Key column directly. Please delete and re-insert if you need to change PK."
                    continue
                fi

                while true; do
                    read -p "Enter new value for '$selected_col_name' ($selected_col_type): " new_val
                    if [[ "$selected_col_type" == "int" && ! "$new_val" =~ ^[0-9]+$ ]]; then
                        error_msg "Value for '$selected_col_name' must be an integer."
                        continue
                    fi
                    break
                done

                awk -F: -v pk_idx="$pk_index_in_awk" -v pk_val="$pk_value" -v target_col="$col_num_to_update" -v new_val="$new_val" '
                  BEGIN { OFS = ":" }
                  {
                    if ($pk_idx == pk_val) {
                      $target_col = new_val
                    }
                    print
                  }
                ' "$tname" > "${tname}.tmp" && mv "${tname}.tmp" "$tname"

                success_msg "Row updated successfully."
                break
            fi
        done
    fi
}

function clear_table_func() {
    local tname="$1"
    if [[ -f "$tname" ]]; then
        > "$tname"
        success_msg "Table cleared."
    else
        error_msg "Table not found."
    fi
}

function connect_to_database() {
    local db="$1"
    while true; do
        print_title "Table Menu (DB: $db)"
        echo "1. Create table"
        echo "2. List tables"
        echo "3. Drop table"
        echo "4. Insert into table"
        echo "5. Select from table"
        echo "6. Update table"
        echo "7. Clear table"
        echo "8. Back to Main Menu"

        read -p "Enter your choice: " tchoice
        case $tchoice in
            1)
                read -p "Enter table name: " tname
                create_table_func "$tname"
                ;;
            2)
                list_tables_func
                ;;
            3)
                read -p "Enter table name to drop: " tname
                drop_table_func "$tname"
                ;;
            4)
                read -p "Enter table name: " tname
                insert_into_table_func "$tname"
                ;;
            5)
                read -p "Enter table name: " tname
                select_from_table_func "$tname"
                ;;
            6)
                read -p "Enter table name to update: " tname
                update_table_func "$tname"
                ;;
            7)
                read -p "Enter table name to clear: " tname
                clear_table_func "$tname"
                ;;
            8)
                break
                ;;
            *)
                error_msg "Invalid choice in Table Menu."
                ;;
        esac
    done
}

