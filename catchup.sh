#!/bin/bash
# Enhanced script to fetch, split, parse, and send emails on-demand
echo "Starting email catch-up at $(date)..."

# Define base directory and paths
BASE_DIR="$HOME/comm.deadlight"
MAILBOX_FILE="$BASE_DIR/mailbox"
TEMP_DIR="$BASE_DIR/temp_email_parts"
EMAILS_DIR="$BASE_DIR/emails"
OUTBOX_DIR="$BASE_DIR/outbox"
SENT_DIR="$BASE_DIR/sent"
FETCH_LOG="$BASE_DIR/fetch_error.log"
PARSE_LOG="$BASE_DIR/parse_error.log"
SEND_LOG="$BASE_DIR/send_error.log"

# Create necessary directories
mkdir -p "$TEMP_DIR" "$EMAILS_DIR" "$OUTBOX_DIR" "$SENT_DIR"

# Read Gmail App Password from secure file
if [ -f "$HOME/.deadlight_credentials" ]; then
    PASSWORD=$(cat "$HOME/.deadlight_credentials")
else
    echo "Error: Credentials file not found at $HOME/.deadlight_credentials"
    exit 1
fi

# Fetch emails with movemail
echo "Attempting to fetch emails from Gmail IMAP..."
movemail --verbose imaps://deadlight.boo:"$PASSWORD"@imap.gmail.com:993/INBOX "$MAILBOX_FILE" 2> "$FETCH_LOG"

# Check if new emails were fetched
if [ -f "$MAILBOX_FILE" ] && [ -s "$MAILBOX_FILE" ]; then
    echo "New emails fetched. Splitting and parsing now..."
    csplit -f "$TEMP_DIR/email_" -b "%04d" -z -s "$MAILBOX_FILE" '/^From /' '{1}' 2>/dev/null
    processed_count=0
    for email_part_file in $(ls -v "$TEMP_DIR"/email_* | grep -v "$TEMP_DIR/email_0000"); do
        if [ -f "$email_part_file" ] && [ -s "$email_part_file" ]; then
            OUTPUT_JSON_FILE="$EMAILS_DIR/email_$(date +%s%N).json"
            gawk -f "$BASE_DIR/parse_email.awk" "$email_part_file" > "$OUTPUT_JSON_FILE" 2>> "$PARSE_LOG"
            if [ $? -eq 0 ] && [ -s "$OUTPUT_JSON_FILE" ]; then
                echo "Parsed: $(basename "$email_part_file") -> $(basename "$OUTPUT_JSON_FILE")"
                processed_count=$((processed_count + 1))
            else
                echo "ERROR parsing $(basename "$email_part_file"). Check $PARSE_LOG."
            fi
        fi
    done
    rm -rf "$TEMP_DIR"/*
    echo "Completed processing. Total emails parsed: $processed_count."
else
    echo "No new emails fetched or mailbox is empty. Check $FETCH_LOG for errors."
fi

# Send pending emails from outbox
echo "Checking for pending emails to send..."
for draft in "$OUTBOX_DIR"/*.json; do
    if [ -f "$draft" ]; then
        recipient=$(gawk '/"to":/ {gsub(/.*"to": "/, ""); gsub(/".*/, ""); print}' "$draft" 2>/dev/null)
        subject=$(gawk '/"subject":/ {gsub(/.*"subject": "/, ""); gsub(/".*/, ""); print}' "$draft" 2>/dev/null)
        body=$(gawk '/"body":/ {gsub(/.*"body": "/, ""); gsub(/".*/, ""); print}' "$draft" 2>/dev/null)
        if [ -n "$recipient" ] && [ -n "$subject" ]; then
            echo "Sending email to $recipient with subject '$subject'..."
            curl --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
                --mail-from 'deadlight.boo@gmail.com' \
                --mail-rcpt "$recipient" \
                --user "deadlight.boo@gmail.com:$PASSWORD" \
                -T <(echo -e "From: deadlight.boo@gmail.com\nTo: $recipient\nSubject: $subject\n\n$body") 2> "$SEND_LOG"
            if [ $? -eq 0 ]; then
                mv "$draft" "$SENT_DIR/sent_$(basename "$draft")_$(date +%s)"
                echo "Sent email to $recipient"
            else
                echo "Failed to send email to $recipient. Check $SEND_LOG"
            fi
        else
            echo "Skipping invalid draft: $draft (missing recipient or subject)"
        fi
    fi
done
echo "Email sending check complete."