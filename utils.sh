# Helper function to get config values safely (trims whitespace and quotes)
get_config_val() {
    local key="$1"
    local raw_val
    raw_val=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$SCRIPT_DIR/hotspot.conf" | cut -d'=' -f2- || true)
    
    # Trim leading whitespace
    while [[ "$raw_val" =~ ^[[:space:]] ]]; do
        raw_val="${raw_val#?}"
    done
    # Trim trailing whitespace
    while [[ "$raw_val" =~ [[:space:]]$ ]]; do
        raw_val="${raw_val%?}"
    done
    
    # Strip leading/trailing quotes
    raw_val="${raw_val#\"}"
    raw_val="${raw_val#\'}"
    raw_val="${raw_val%\"}"
    raw_val="${raw_val%\'}"
    
    echo "$raw_val"
}