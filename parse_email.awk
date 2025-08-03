# Enhanced script to parse a raw email file to JSON with body formatted as Markdown
BEGIN {
    FS=": "
    OFS=""
    print "{"
    json_fields_count = 0
    in_headers = 1
    in_mime_part = 0
    in_mime_part_headers = 0
    in_mime_part_body = 0
    boundary = ""
    current_content_type = ""
    current_transfer_encoding = ""
    body_content_raw = ""
    temp_file_b64 = "/tmp/awk_b64_temp_" PROCINFO["pid"]
}

in_headers && /^From:/ {
    add_json_field("from", $0, 6)
}
in_headers && /^To:/ {
    add_json_field("to", $0, 4)
}
in_headers && /^Cc:/ {
    add_json_field("cc", $0, 4)
}
in_headers && /^Subject:/ {
    add_json_field("subject", $0, 9)
}
in_headers && /^Date:/ {
    add_json_field("date", $0, 6)
}
in_headers && /^Message-ID:/ {
    add_json_field("message_id", $0, 12)
}
in_headers && /^Content-Type:/ {
    if ($0 ~ /multipart\// && $0 ~ /boundary="([^"]+)"/) {
        match($0, /boundary="([^"]+)"/, m)
        boundary = m[1]
    }
}
in_headers && /^$/ {
    in_headers = 0
    in_mime_part = 1
    in_mime_part_headers = 1
    next
}

$0 ~ ("^--" boundary "--$") {
    if (body_content_raw != "") {
        process_mime_body()
    }
    in_mime_part = 0
    in_mime_part_headers = 0
    in_mime_part_body = 0
    next
}
$0 ~ ("^--" boundary) {
    if (body_content_raw != "") {
        process_mime_body()
    }
    in_mime_part_headers = 1
    in_mime_part_body = 0
    current_content_type = ""
    current_transfer_encoding = ""
    body_content_raw = ""
    next
}

in_mime_part {
    if (in_mime_part_headers) {
        if ($0 == "") {
            in_mime_part_headers = 0
            in_mime_part_body = 1
            next
        }
        if ($0 ~ /^Content-Type:/) {
            match($0, /^Content-Type: (.+)/, m)
            current_content_type = tolower(m[1])
        } else if ($0 ~ /^Content-Transfer-Encoding:/) {
            match($0, /^Content-Transfer-Encoding: (.+)/, m)
            current_transfer_encoding = tolower(m[1])
        }
    } else if (in_mime_part_body) {
        if (body_content_raw == "") {
            body_content_raw = $0
        } else {
            body_content_raw = body_content_raw "\n" $0
        }
    }
}

END {
    if (body_content_raw != "") {
        process_mime_body()
    }
    printf "\n}\n"
}

function add_json_field(key, line_content, chars_to_remove) {
    if (json_fields_count > 0) {
        printf ",\n"
    }
    if (chars_to_remove > 0) {
        printf "  \"%s\": \"%s\"", key, escape_quotes(substr(line_content, chars_to_remove + 1))
    } else {
        printf "  \"%s\": \"%s\"", key, escape_quotes(line_content)
    }
    json_fields_count++
}

function process_mime_body() {
    if (current_content_type ~ /text\/plain/ || current_content_type == "") {
        if (current_transfer_encoding == "base64") {
            printf "%s", body_content_raw > temp_file_b64
            close(temp_file_b64)
            cmd = "base64 -d " temp_file_b64 " 2>/dev/null"
            decoded_content = ""
            while ((cmd | getline line) > 0) {
                decoded_content = (decoded_content == "" ? line : decoded_content "\n" line)
            }
            close(cmd)
            system("rm -f " temp_file_b64)
            if (decoded_content != "") {
                formatted_content = format_as_markdown(decoded_content)
                add_json_field("body", formatted_content, 0)
            } else {
                add_json_field("body", "[Base64 decode failed or external tool issue]\n" escape_quotes(body_content_raw), 0)
            }
        } else {
            formatted_content = format_as_markdown(body_content_raw)
            add_json_field("body", formatted_content, 0)
        }
    }
    body_content_raw = ""
}

function escape_quotes(str) {
    gsub(/\\/, "\\\\", str)
    gsub(/"/, "\\\"", str)
    gsub(/\n/, "\\n", str)
    gsub(/\r/, "\\r", str)
    return str
}

function format_as_markdown(content) {
    # Replace URLs with Markdown links if they aren't already in a link format
    # This is a basic regex for URLs; it's not perfect but covers most cases
    gsub(/<https?:\/\/[^>]+>/, "\\0", content)  # Protect URLs already in <>
    gsub(/https?:\/\/[a-zA-Z0-9\/._-]*[a-zA-Z0-9\/]/, "[Link](\\0)", content)
    # Preserve line breaks (already handled by \n in escape_quotes)
    return content
}