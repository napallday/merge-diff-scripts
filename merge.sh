#!/bin/bash

# 检查配置文件是否存在
config_file="./merge/commits.conf"
if [ ! -f "$config_file" ]; then
    echo "Error: Configuration file '$config_file' not found"
    echo "Please create $config_file with the following format:"
    echo "# Format: tag_name commit_or_tag"
    echo "official_old  tag:v1.10.0"
    echo "official_new  tag:v1.11.0"
    echo "debank_old    branch:main"
    echo "debank_new    branch:develop"
    exit 1
fi

# 获取所有远程仓库的分支和标签
echo "Fetching all branches and tags from remotes..."
git fetch official
git fetch origin

# 函数：将tag/branch/commit转换为commit hash
get_commit_hash() {
    local ref=$1
    local hash
    
    echo "Debug: Processing ref: $ref" >&2
    
    # 检查引用类型
    if [[ "$ref" =~ ^tag: ]]; then
        # 处理tag
        local tag=${ref#tag:}
        echo "Debug: Found tag: $tag" >&2
        
        # 先直接尝试解析tag
        hash=$(git rev-parse "$tag" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "Debug: Resolved tag directly: $hash" >&2
            echo "$hash"
            return
        fi
        
        # 尝试解析不同格式的tag引用
        for prefix in "" "refs/tags/" "refs/remotes/official/tags/" "refs/remotes/origin/tags/"; do
            echo "Debug: Trying tag with prefix: $prefix$tag" >&2
            if git show-ref --verify --quiet "${prefix}${tag}"; then
                hash=$(git rev-parse "${prefix}${tag}" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    echo "Debug: Resolved tag with prefix: $hash" >&2
                    echo "$hash"
                    return
                fi
            fi
        done
        
        # 如果tag包含斜杠，尝试去掉remote前缀
        if [[ "$tag" == */* ]]; then
            local remote=$(echo "$tag" | cut -d'/' -f1)
            local tag_name=$(echo "$tag" | cut -d'/' -f2-)
            echo "Debug: Trying tag with remote prefix: $remote and tag name: $tag_name" >&2
            
            if git show-ref --verify --quiet "refs/tags/$tag_name"; then
                hash=$(git rev-parse "refs/tags/$tag_name" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    echo "Debug: Resolved split tag: $hash" >&2
                    echo "$hash"
                    return
                fi
            fi
        fi
        
        echo "Error: Tag '$tag' not found in any format" >&2
        exit 1
    elif [[ "$ref" =~ ^branch: ]]; then
        # 处理branch
        local branch=${ref#branch:}
        echo "Debug: Found branch: $branch" >&2

        # 尝试多种方式解析分支
        if git show-ref --verify --quiet "refs/remotes/$branch"; then
            echo "Debug: Found as remote branch: refs/remotes/$branch" >&2
            hash=$(git rev-parse "refs/remotes/$branch" 2>/dev/null)
        elif git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "Debug: Found as local branch: refs/heads/$branch" >&2
            hash=$(git rev-parse "refs/heads/$branch" 2>/dev/null)
        elif git show-ref --verify --quiet "$branch"; then
            echo "Debug: Found branch directly: $branch" >&2
            hash=$(git rev-parse "$branch" 2>/dev/null)
        else
            echo "Error: Branch '$branch' not found in any format" >&2
            exit 1
        fi

        # 检查是否成功获取哈希
        if [ $? -ne 0 ] || [ -z "$hash" ]; then
            echo "Error: Failed to get commit hash for branch '$branch'" >&2
            exit 1
        fi
    else
        # 处理commit hash
        echo "Debug: Found commit hash: $ref" >&2
        hash=$(git rev-parse "$ref" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Error: Invalid commit hash '$ref'" >&2
            exit 1
        fi
    fi
    
    if [ -z "$hash" ]; then
        echo "Error: Failed to resolve hash for '$ref'" >&2
        exit 1
    fi
    
    echo "Debug: Resolved hash: $hash" >&2
    echo "$hash"
}

# 初始化变量
official_old_ref=""
official_new_ref=""
debank_old_ref=""
debank_new_ref=""
official_old_hash=""
official_new_hash=""
debank_old_hash=""
debank_new_hash=""

# 读取配置文件
while read -r line; do
    # 跳过注释行和空行
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    
    # 读取两列数据
    read -r tag ref <<< "$line"
    
    echo "Debug: Read line - tag: '$tag', ref: '$ref'" >&2
    
    if [[ -n "$tag" && -n "$ref" ]]; then  # 确保必需字段不为空
        # 根据tag设置对应的变量
        case "$tag" in
            "official_old")
                official_old_ref="$ref"
                official_old_hash=$(get_commit_hash "$ref")
                ;;
            "official_new")
                official_new_ref="$ref"
                official_new_hash=$(get_commit_hash "$ref")
                ;;
            "debank_old")
                debank_old_ref="$ref"
                debank_old_hash=$(get_commit_hash "$ref")
                ;;
            "debank_new")
                debank_new_ref="$ref"
                debank_new_hash=$(get_commit_hash "$ref")
                ;;
        esac
    fi
done < "$config_file"

# 验证所需的commit是否都存在
echo "Debug: Checking hashes:" >&2
echo "official_old_hash: $official_old_hash" >&2
echo "official_new_hash: $official_new_hash" >&2
echo "debank_old_hash: $debank_old_hash" >&2
echo "debank_new_hash: $debank_new_hash" >&2

if [ -z "$official_old_hash" ] || [ -z "$official_new_hash" ] || \
   [ -z "$debank_old_hash" ] || [ -z "$debank_new_hash" ]; then
    echo "Error: Missing required commit hashes in $config_file"
    exit 1
fi

# 显示将要比较的commit
echo "Using the following commits:"
echo "Official old: $official_old_hash"
echo "             (from: $official_old_ref)"
echo "Official new: $official_new_hash"
echo "             (from: $official_new_ref)"
echo "Debank old:   $debank_old_hash"
echo "             (from: $debank_old_ref)"
echo "Debank new:   $debank_new_hash"
echo "             (from: $debank_new_ref)"
echo ""

# 创建临时目录存放diff文件
temp_dir="./merge_$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$temp_dir"
echo "Using temporary directory: $temp_dir"

# 创建子目录
mkdir -p "$temp_dir/debank_changes"  # debank分支的变化
mkdir -p "$temp_dir/official_changes"  # official分支的变化
mkdir -p "$temp_dir/comparison"

# 函数：获取两个commit之间的diff
generate_diff() {
    local commit1=$1
    local commit2=$2
    local output_dir=$3
    
    # 获取更改的文件列表
    local files=$(git diff --name-only $commit1 $commit2)
    
    for file in $files; do
        # 创建安全的文件名
        local safe_name=$(echo "$file" | sed 's/\//_/g')
        # 生成diff并保存
        git diff $commit1 $commit2 -- "$file" > "$output_dir/${safe_name}.diff"
    done
}

# 生成debank分支的变化
echo "Generating diff between debank_old and debank_new..."
generate_diff "$debank_old_hash" "$debank_new_hash" "$temp_dir/debank_changes"

# 生成official分支的变化
echo "Generating diff between official_old and official_new..."
generate_diff "$official_old_hash" "$official_new_hash" "$temp_dir/official_changes"

# 比较两个分支的变化
echo "Comparing changes..."
echo "=== Changes Comparison Report ===" > "$temp_dir/comparison_report.txt"
echo "Timestamp: $(date)" >> "$temp_dir/comparison_report.txt"
echo "" >> "$temp_dir/comparison_report.txt"

# 获取所有涉及的文件
all_files=$(ls "$temp_dir/debank_changes" "$temp_dir/official_changes" | sort -u)

# 用于跟踪存在差异的文件
different_files=()
official_only_files=()
debank_only_files=()

for diff_file in $all_files; do
    debank_diff="$temp_dir/debank_changes/$diff_file"
    official_diff="$temp_dir/official_changes/$diff_file"
    
    # 检查文件是否存在于两个变更中
    if [ ! -f "$debank_diff" ]; then
        original_file=$(echo "$diff_file" | sed 's/\.diff$//' | sed 's/_/\//g')
        official_only_files+=("$original_file")
        continue
    fi
    if [ ! -f "$official_diff" ]; then
        original_file=$(echo "$diff_file" | sed 's/\.diff$//' | sed 's/_/\//g')
        debank_only_files+=("$original_file")
        continue
    fi
    
    # 比较两个diff文件
    if diff -q "$debank_diff" "$official_diff" >/dev/null; then
        : # Do nothing, silent match
    else
        # 进一步比较，过滤掉会导致假差异的行
        # 1. 过滤掉index行（包含commit hash的行）
        # 2. 过滤掉@@行（包含行号信息的行）
        # 3. 过滤掉三个连续减号或加号的分隔线
        if diff -q <(grep -v "^index " "$debank_diff" | grep -v "^@@" | grep -v "^---$" | grep -v "^+++$") \
                  <(grep -v "^index " "$official_diff" | grep -v "^@@" | grep -v "^---$" | grep -v "^+++$") >/dev/null; then
            # 只有无关差异，忽略
            :
        else
            # 还原原始文件名用于显示
            original_file=$(echo "$diff_file" | sed 's/\.diff$//' | sed 's/_/\//g')
            different_files+=("$original_file")
            
            # 将实质性差异输出到comparison文件夹下的文件
            comparison_file="$temp_dir/comparison/${diff_file}"
            echo "=== Difference between debank and official changes ===" > "$comparison_file"
            echo "< Debank changes (debank_old -> debank_new)" >> "$comparison_file"
            echo "> Official changes (official_old -> official_new)" >> "$comparison_file"
            
            # 输出过滤后的diff，只显示实际内容差异
            echo "=== Content differences (excluding line numbers and commit hashes) ===" >> "$comparison_file"
            diff <(grep -v "^index " "$debank_diff" | grep -v "^@@" | grep -v "^---$" | grep -v "^+++$") \
                 <(grep -v "^index " "$official_diff" | grep -v "^@@" | grep -v "^---$" | grep -v "^+++$") >> "$comparison_file"
            
            # 同时保留原始diff，方便查看完整差异
            echo "" >> "$comparison_file"
            echo "=== Full diff (including line numbers and commit hashes) ===" >> "$comparison_file"
            diff "$debank_diff" "$official_diff" >> "$comparison_file"
        fi
    fi
done

# 汇总报告 - 只有在有内容时才添加标题和内容
if [ ${#different_files[@]} -gt 0 ]; then
    echo "FILES WITH DIFFERENT CHANGES:" >> "$temp_dir/comparison_report.txt"
    for file in "${different_files[@]}"; do
        echo "- $file" >> "$temp_dir/comparison_report.txt"
    done
    echo "" >> "$temp_dir/comparison_report.txt"
fi

if [ ${#official_only_files[@]} -gt 0 ]; then
    echo "FILES ONLY CHANGED IN OFFICIAL BRANCH:" >> "$temp_dir/comparison_report.txt"
    echo "This might mean the changes from official were not properly merged to debank" >> "$temp_dir/comparison_report.txt"
    for file in "${official_only_files[@]}"; do
        echo "- $file" >> "$temp_dir/comparison_report.txt"
    done
    echo "" >> "$temp_dir/comparison_report.txt"
fi

if [ ${#debank_only_files[@]} -gt 0 ]; then
    echo "FILES ONLY CHANGED IN DEBANK BRANCH:" >> "$temp_dir/comparison_report.txt"
    echo "This might be debank-specific changes" >> "$temp_dir/comparison_report.txt"
    for file in "${debank_only_files[@]}"; do
        echo "- $file" >> "$temp_dir/comparison_report.txt"
    done
    echo "" >> "$temp_dir/comparison_report.txt"
fi

echo "Comparison complete. Report saved to: $temp_dir/comparison_report.txt"
echo "Diff files are stored in:"
echo "- Debank changes (debank_old -> debank_new): $temp_dir/debank_changes/"
echo "- Official changes (official_old -> official_new): $temp_dir/official_changes/"
echo "- Comparison of differences: $temp_dir/comparison/"

# 显示报告内容
echo ""
echo "=== Report Summary ==="
cat "$temp_dir/comparison_report.txt"

# 简洁地显示所有存在差异的文件总数
echo ""
echo "=== Summary Statistics ==="
echo "Files with different changes: ${#different_files[@]}"
echo "Files only in official branch: ${#official_only_files[@]}"
echo "Files only in debank branch: ${#debank_only_files[@]}"
echo "Total files analyzed: ${#all_files[@]}"