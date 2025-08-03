#!/bin/bash
# Enhanced script to fetch, split, parse, and push emails to blog.deadlight Worker
echo "Starting email catch-up at $(date)..."

# Define base directory and paths
BASE_DIR="$HOME/comm.deadlight"
MAILBOX_FILE="$BASE_DIR/mailbox"
TEMP_DIR="$BASE_DIR/temp_email_parts"
EMAILS_DIR="$BASE_DIR/emails"
FETCH_LOG="$BASE_DIR/fetch_error.log"
PARSE_LOG="$BASE_DIR/parse_error.log"

# Create necessary directories
mkdir -p "$TEMP_DIR" "$EMAILS_DIR"

# Read Gmail App Password from secure file
if [ -f "$HOME/.deadlight_credentials" ]; then
    PASSWORD=$(cat "$HOME/.deadlight_credentials")
else
    echo "Error: Credentials file not found at $HOME/.deadlight_credentials"
    exit 1
fi

# Read API Key for Worker endpoint (set this in a secure file or env variable)
if [ -f "$HOME/.deadlight_api_key" ]; then
    API_KEY=$(cat "$HOME/.deadlight_api_key")
else
    echo "Error: API Key file not found at $HOME/.deadlight_api_key"
    echo "Please create this file with your API key for the /admin/fetch-emails endpoint."
    exit 1
fi

# Worker endpoint for pushing emails (adjust to production URL later)
WORKER_ENDPOINT="http://localhost:8787/admin/fetch-emails"

# Fetch emails with movemail
echo "Attempting to fetch emails from Gmail IMAP..."
movemail --verbose imaps://deadlight.boo:"$PASSWORD"@imap.gmail.com:993/INBOX "$MAILBOX_FILE" 2> "$FETCH_LOG"

# Check if new emails were fetched
if [ -f "$MAILBOX_FILE" ] && [ -s "$MAILBOX_FILE" ]; then
    echo "New emails fetched. Splitting and parsing now..."
    csplit -f "$TEMP_DIR/email_" -b "%04d" -z -s "$MAILBOX_FILE" '/^From /' '{1}' 2>/dev/null
    processed_count=0
    # Create a JSON array to store emails for pushing to Worker
    emails_json="{\"emails\": ["
    first_email=true
    for email_part_file in $(ls -v "$TEMP_DIR"/email_* | grep -v "$TEMP_DIR/email_0000"); do
        if [ -f "$email_part_file" ] && [ -s "$email_part_file" ]; then
            OUTPUT_JSON_FILE="$EMAILS_DIR/email_$(date +%s%N).json"
            gawk -f "$BASE_DIR/parse_email.awk" "$email_part_file" > "$OUTPUT_JSON_FILE" 2>> "$PARSE_LOG"
            if [ $? -eq 0 ] && [ -s "$OUTPUT_JSON_FILE" ]; then
                echo "Parsed: $(basename "$email_part_file") -> $(basename "$OUTPUT_JSON_FILE")"
                # Append parsed JSON to emails_json array
                if [ "$first_email" = true ]; then
                    emails_json="$emails_json $(cat "$OUTPUT_JSON_FILE")"
                    first_email=false
                else
                    emails_json="$emails_json, $(cat "$OUTPUT_JSON_FILE")"
                fi
                processed_count=$((processed_count + 1))
            else
                echo "ERROR parsing $(basename "$email_part_file"). Check $PARSE_LOG."
            fi
        fi
    done
    emails_json="$emails_json ]}"
    rm -rf "$TEMP_DIR"/*
    echo "Completed processing. Total emails parsed: $processed_count."
    
    # If emails were processed, push them to the Worker endpoint
    if [ "$processed_count" -gt 0 ]; then
        echo "Pushing parsed emails to Worker endpoint: $WORKER_ENDPOINT"
        # Save JSON to a temporary file to use with curl
        temp_json_file="/tmp/emails_push.json"
        echo "$emails_json" > "$temp_json_file"
        # Use curl to POST the JSON array to the endpoint
        curl -X POST "$WORKER_ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $API_KEY" \
            -d "@$temp_json_file" \
            2> /tmp/curl_push_error.log
        if [ $? -eq 0 ]; then
            echo "Successfully pushed $processed_count email(s) to Worker endpoint."
            rm -f "$temp_json_file"
        else
            echo "Failed to push emails to Worker endpoint. Check /tmp/curl_push_error.log for details."
            cat /tmp/curl_push_error.log
        fi
    else
        echo "No new emails to push to Worker endpoint."
    fi
else
    echo "No new emails fetched or mailbox is empty. Check $FETCH_LOG for errors."
fi