#!/bin/bash

# Script to copy models from Hugging Face cache to Downloads directory
# with proper naming for MLXChatExample

CACHE_DIR="$HOME/.cache/huggingface/hub"
DEST_DIR="$HOME/Downloads/huggingface/models"

echo "🔍 Looking for MLX models in cache..."

# Find all model directories in the cache
for model_dir in "$CACHE_DIR"/models--*; do
    if [ -d "$model_dir" ]; then
        # Extract org and model name from the directory name
        # Format: models--{org}--{model-name}
        dir_name=$(basename "$model_dir")
        
        # Remove the "models--" prefix and split by "--"
        model_info=${dir_name#models--}
        org=$(echo "$model_info" | cut -d'-' -f1-2)
        model_name=${model_info#$org--}
        
        # Check if this looks like an MLX model
        if [[ "$org" == "mlx-community" ]] || [[ "$model_name" == *"4bit"* ]] || [[ "$model_name" == *"8bit"* ]]; then
            echo ""
            echo "📦 Found model: $org/$model_name"
            
            # Find the snapshot directory
            snapshot_dir=$(find "$model_dir/snapshots" -maxdepth 1 -type d | tail -n 1)
            
            if [ -d "$snapshot_dir" ] && [ "$snapshot_dir" != "$model_dir/snapshots" ]; then
                # Create destination directory
                dest_path="$DEST_DIR/$org/$model_name"
                mkdir -p "$dest_path"
                
                echo "   Copying from: $snapshot_dir"
                echo "   Copying to: $dest_path"
                
                # Copy files, resolving symlinks
                cp -LR "$snapshot_dir"/* "$dest_path" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo "   ✅ Successfully copied!"
                else
                    echo "   ⚠️  Some files may have failed to copy"
                fi
            else
                echo "   ❌ No snapshot found"
            fi
        fi
    fi
done

echo ""
echo "🎉 Done! Models have been copied to $DEST_DIR"
echo ""
echo "The following models are now available in MLXChatExample:"
find "$DEST_DIR" -mindepth 2 -maxdepth 2 -type d | while read -r model_path; do
    org=$(basename "$(dirname "$model_path")")
    model=$(basename "$model_path")
    echo "   - $org/$model"
done