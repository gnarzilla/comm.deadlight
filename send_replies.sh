#!/bin/bash
# Script to fetch and send pending email replies from blog.deadlight Worker
echo "Starting reply sending process at $(date)..."

# Define base directory and paths
BASE_DIR="$HOME/comm.deadlight"
LOG_FILE="$BASE_DIR/send_replies.log"
ERROR_LOG="$BASE_DIR/send_replies_error.log"

# Create log directory if it doesn't exist
mkdir -p "$BASE_DIR"

# Read API Key for Worker endpoint
if [ -f "$HOME/.deadlight_api_key" ]; then
    API_KEY=$(cat "$HOME/.deadlight_api_key")
    echo "API Key read successfully from $HOME/.deadlight_api_key (length: ${#API_KEY} characters)"
    echo "$(date): API Key read successfully (length: ${#API_KEY} characters)" >> "$LOG_FILE"
else
    echo "Error: API Key file not found at $HOME/.deadlight_api_key"
    echo "$(date): Error: API Key file not found at $HOME/.deadlight_api_key" >> "$ERROR_LOG"
    exit 1
fi

# Check for required tools
echo "Checking for required tools..."
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Please install jq for JSON parsing."
    echo "$(date): Error: jq not found" >> "$ERROR_LOG"
    exit 1
else
    echo "jq found at $(which jq)"
    echo "$(date): jq found at $(which jq)" >> "$LOG_FILE"
fi

if ! command -v msmtp &> /dev/null; then
    echo "Error: msmtp not found. Please install msmtp to send emails."
    echo "$(date): Error: msmtp not found" >> "$ERROR_LOG"
    exit 1
else
    echo "msmtp found at $(which msmtp)"
    echo "$(date): msmtp found at $(which msmtp)" >> "$LOG_FILE"
fi

# Worker endpoint for pending replies
WORKER_ENDPOINT="http://localhost:8787/admin/pending-replies"

# Fetch pending replies
echo "Fetching pending replies from $WORKER_ENDPOINT..."
temp_json_file="/tmp/pending_replies.json"
curl_response=$(curl -s -w "%{http_code}" -X GET "$WORKER_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -o "$temp_json_file" \
    2> "$ERROR_LOG")

if [ $? -eq 0 ] && [ -s "$temp_json_file" ]; then
    http_code=$(echo "$curl_response" | tail -n 1)
    echo "HTTP Response Code: $http_code"
    echo "$(date): HTTP Response Code: $http_code for $WORKER_ENDPOINT" >> "$LOG_FILE"
    
    if [ "$http_code" -eq 200 ]; then
        # Check if success is true and replies array exists
        success=$(jq -r '.success' "$temp_json_file" 2>> "$ERROR_LOG")
        if [ "$success" != "true" ]; then
            echo "Error: Failed to fetch replies. Response: $(cat "$temp_json_file")"
            echo "$(date): Failed to fetch replies. Response: $(cat "$temp_json_file")" >> "$ERROR_LOG"
            rm -f "$temp_json_file"
            exit 1
        fi
        
        replies_count=$(jq -r '.replies | length' "$temp_json_file" 2>> "$ERROR_LOG")
        echo "Found $replies_count pending replies to send."
        echo "$(date): Found $replies_count pending replies." >> "$LOG_FILE"
        
        if [ "$replies_count" -gt 0 ]; then
            echo "Processing $replies_count replies for sending..."
            echo "$(date): Processing $replies_count replies for sending." >> "$LOG_FILE"
            i=0
            while [ $i -lt $replies_count ]; do
                echo "Extracting data for reply index $i..."
                echo "$(date): Extracting data for reply index $i" >> "$LOG_FILE"
                
                reply_id=$(jq -r ".replies[$i].id" "$temp_json_file" 2>> "$ERROR_LOG")
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to extract reply_id for index $i"
                    echo "$(date): Error: Failed to extract reply_id for index $i" >> "$ERROR_LOG"
                    i=$((i + 1))
                    continue
                fi
                
                to=$(jq -r ".replies[$i].to" "$temp_json_file" 2>> "$ERROR_LOG")
                from=$(jq -r ".replies[$i].from" "$temp_json_file" 2>> "$ERROR_LOG")
                subject=$(jq -r ".replies[$i].subject" "$temp_json_file" 2>> "$ERROR_LOG")
                body=$(jq -r ".replies[$i].body" "$temp_json_file" 2>> "$ERROR_LOG")
                
                echo "Sending reply ID $reply_id to $to..."
                echo "$(date): Sending reply ID $reply_id to $to" >> "$LOG_FILE"
                
                # Use msmtp to send the email
                email_content="From: $from\nTo: $to\nSubject: $subject\n\n$body"
                echo "Attempting to send email with msmtp for reply ID $reply_id..."
                echo "$(date): Attempting to send email with msmtp for reply ID $reply_id" >> "$LOG_FILE"
                echo -e "$email_content" | msmtp "$to" 2>> "$ERROR_LOG"
                send_status=$?
                
                if [ $send_status -eq 0 ]; then
                    echo "Successfully sent reply ID $reply_id to $to."
                    echo "$(date): Successfully sent reply ID $reply_id to $to" >> "$LOG_FILE"
                    
                    # Mark reply as sent
                    echo "Marking reply ID $reply_id as sent..."
                    echo "$(date): Marking reply ID $reply_id as sent" >> "$LOG_FILE"
                    temp_mark_response="/tmp/mark_response_$reply_id.json"
                    mark_http_code=$(curl -s -w "%{http_code}" -X POST "$WORKER_ENDPOINT" \
                        -H "Content-Type: application/json" \
                        -H "X-API-Key: $API_KEY" \
                        -d "{\"id\": \"$reply_id\"}" \
                        -o "$temp_mark_response" \
                        2>> "$ERROR_LOG")
                    
                    if [ "$mark_http_code" -eq 200 ]; then
                        echo "Marked reply ID $reply_id as sent."
                        echo "$(date): Marked reply ID $reply_id as sent" >> "$LOG_FILE"
                        rm -f "$temp_mark_response" 2>/dev/null
                    else
                        echo "Failed to mark reply ID $reply_id as sent. HTTP Code: $mark_http_code"
                        echo "$(date): Failed to mark reply ID $reply_id as sent. HTTP Code: $mark_http_code. Response: $(cat "$temp_mark_response" 2>/dev/null)" >> "$ERROR_LOG"
                        rm -f "$temp_mark_response" 2>/dev/null
                    fi
                else
                    echo "Failed to send reply ID $reply_id to $to. Exit code: $send_status. Check $ERROR_LOG for details."
                    echo "$(date): Failed to send reply ID $reply_id to $to. msmtp exit code: $send_status" >> "$ERROR_LOG"
                fi
                i=$((i + 1))
            done
        else
            echo "No pending replies to send."
            echo "$(date): No pending replies to send" >> "$LOG_FILE"
        fi
        rm -f "$temp_json_file" 2>/dev/null
    else
        echo "Failed to fetch pending replies. HTTP Code: $http_code. Check response in $temp_json_file and $ERROR_LOG."
        echo "$(date): Failed to fetch pending replies. HTTP Code: $http_code" >> "$ERROR_LOG"
        cat "$ERROR_LOG"
        cat "$temp_json_file" >> "$ERROR_LOG" 2>/dev/null
        rm -f "$temp_json_file" 2>/dev/null
    fi
else
    echo "Failed to fetch pending replies. curl command failed. Check $ERROR_LOG for details."
    cat "$ERROR_LOG"
    echo "$(date): curl command failed to fetch from $WORKER_ENDPOINT" >> "$ERROR_LOG"
    exit 1
fi