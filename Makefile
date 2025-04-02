# Makefile for Merge Comparison Tool

# 默认目标：运行merge脚本
.PHONY: all
all: merge

# 确保脚本有执行权限并运行脚本
.PHONY: merge
merge:
	@echo "Running merge comparison..."
	@chmod +x merge.sh
	@./merge.sh

# 检查配置文件
.PHONY: check_config
check_config:
	@if [ ! -f "./commits.conf" ]; then \
		echo "Error: Configuration file 'commits.conf' not found"; \
		echo "Please create commits.conf with the following format:"; \
		echo "official_old  tag:v1.10.0"; \
		echo "official_new  tag:v1.11.0"; \
		echo "debank_old    branch:main"; \
		echo "debank_new    branch:develop"; \
		echo "working_directory /path/to/git/repository"; \
		exit 1; \
	fi

# 清理生成的目录
.PHONY: clean
clean:
	@echo "Cleaning up generated directories..."
	@rm -rf merge_*
	@echo "Cleanup complete."

# 显示帮助信息
.PHONY: help
help:
	@echo "Merge Comparison Tool Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make         - Run the merge comparison"
	@echo "  make clean   - Remove all generated directories"
	@echo "  make help    - Display this help message"
	@echo ""
	@echo "Configuration:"
	@echo "  Edit commits.conf to set the comparison points and working directory" 