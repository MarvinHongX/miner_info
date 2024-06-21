#!/bin/bash

SERVER_LIST="servers.txt"

if [[ ! -f "$SERVER_LIST" ]]; then
    echo "서버 목록 파일 '$SERVER_LIST'을 찾을 수 없습니다."
    exit 1
fi

totalPower=0.0
totalWorkerBalance=0.0

echo "+---------------------------------------------------+"
printf "| %-8s | %-17s | %-18s |\n" "Server" "Adjusted Power" "Worker Balance"
echo "|===================================================|"


while IFS= read -r SERVER_INFO; do
    SERVER_HOST=$(echo "$SERVER_INFO" | cut -d' ' -f1)
    SERVER_USER=$(echo "$SERVER_INFO" | cut -d' ' -f2)
    SERVER_PORT=$(echo "$SERVER_INFO" | cut -d' ' -f3)
    SERVER_NAME=$(echo "$SERVER_INFO" | cut -d' ' -f4)

    ssh -n -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
        "cat ~/.bashrc | grep '^export' > ~/bash.sh; cat ~/.bashrc | grep 'cargo' >> ~/bash.sh"

    ssh_command=". ~/bash.sh > /dev/null 2>&1; lotus-miner info | grep -Ei 'power|worker balance'"

    # Capture both power and worker balance
    #output=$(ssh -n -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "$ssh_command")
    output=$(ssh -o LogLevel=ERROR -n -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "$ssh_command" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "서버 '$SERVER_NAME'에서 정보를 가져오는 중 오류가 발생했습니다."
        continue
    fi

    # Extract the power value    
    power=$(echo "$output" | grep -i "power")
    power_value=$(echo "$power" | grep -oP '\d+(\.\d+)?(?=\s*Pi)')
    if [[ -z "$power_value" ]]; then
        echo "서버 '$SERVER_NAME'에서 정보를 가져오는 데 실패했습니다: $power"
        continue
    fi

    # Extract the worker balance
    worker_balance=$(echo "$output" | grep -i "worker balance")
    if [[ ! "$worker_balance" =~ [0-9]+\.[0-9]+ ]]; then
        echo "서버 '$SERVER_NAME'에서 Worker Balance를 가져오는 데 실패했습니다: $worker_balance"
        continue
    fi
    worker_balance_value=$(echo "$worker_balance" | grep -oP '\d+(\.\d+)?')

    # Add to the total power
    totalPower=$(echo "$totalPower + $power_value" | bc)
    totalWorkerBalance=$(echo "$totalWorkerBalance + $worker_balance_value" | bc)


    # Output results
    printf "| %-8s | %14.2f Pi | %14.2f FIL |\n" "$SERVER_NAME" "$power_value" "$worker_balance_value"

done < "$SERVER_LIST"

echo "|===================================================|"
printf "| %-8s | %14.2f Pi | %14.2f FIL |\n" "Total" "$totalPower" "$totalWorkerBalance"
echo "+---------------------------------------------------+"
