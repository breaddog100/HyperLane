#!/bin/bash

# 节点安装功能
function install_node() {
    sudo apt update && sudo apt upgrade
	sudo apt install -y npm snap libssl-dev pkg-config llvm-dev libclang-dev clang plocate screen

	# 设置 LLVM 目录
	export LIBCLANG_PATH=/usr/lib/llvm-14/lib
	echo 'export LIBCLANG_PATH=/usr/lib/llvm-14/lib' >> ~/.bashrc
	source ~/.bashrc
	
	# 安装 Foundry 并启动 foundryup
	curl -L https://foundry.paradigm.xyz | bash
	source ~/.bashrc
	foundryup
	
	# 安装 Rust 和更新到稳定版
	sudo snap install rustup --classic
	rustup default stable
	
	# 安装 nvm 和 Node.js
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
	nvm install --lts
	
	# 升级npm
	npm install -g npm
	npm update -g
	npm install -g uuid@latest
	
	# 安装 Foundry 工具
	cargo install --git https://github.com/foundry-rs/foundry --profile local --locked forge cast chisel anvil
	
	# 更新 Rust 到稳定版
	rustup update stable
	
	# 安装Hyperlane CLI
	mkdir ~/.npm-global
	npm config set prefix '~/.npm-global'
	export PATH=~/.npm-global/bin:$PATH
	npm install -g @hyperlane-xyz/cli@latest

	git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git
	cd $HOME/hyperlane-monorepo/rust/agents/validator
	cargo build --release --bin validator

	echo "部署完成"
}

# 启动节点
function start_node(){
	read -p "请输入AWS秘钥:" aws_access_key_id
	read -p "请输入AWS秘密的秘钥:" aws_secret_access_key
	read -p "请输入链名:" chian_name
	read -p "请输入AWS区域(如us-west-1):" region
	read -p "请输入AWS KMS名称:" kms_name
	read -p "请输入AWS S3名称:" s3_name
	
	screen -dmS hyp-$chian_name bash -c "
	export AWS_ACCESS_KEY_ID=$aws_access_key_id
	export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
	cd $HOME/hyperlane-monorepo/rust
	./target/release/validator \
	  --db /hyperlane_db_$chian_name \
	  --originChainName $chian_name \
	  --reorgPeriod 1 \
	  --validator.region $region \
	  --checkpointSyncer.region $region \
	  --validator.type aws \
	  --chains.$chian_name.signer.type aws \
	  --chains.$chian_name.signer.region $region \
	  --validator.id alias/$kms_name \
	  --chains.$chian_name.signer.id alias/$kms_name \
	  --checkpointSyncer.type s3 \
	  --checkpointSyncer.bucket $s3_name; exec bash"
}

# 查看日志
function view_logs(){
	# 获取当前运行的screen会话列表
	screens=$(screen -ls | grep -oP '\t\K[^\t]+' | sort)
	
	# 检查是否有screen会话
	if [ -z "$screens" ]; then
	    echo "没有找到正在运行的screen会话。"
	    exit 1
	fi
	
	# 显示screen会话列表供用户选择
	echo "检测到以下screen会话："
	echo "$screens"
	echo ""
	
	# 提示用户输入
	read -p "请输入您想查看的screen会话名称: " choice
	
	# 检查用户输入是否为有效会话
	if [[ $screens == *$choice* ]]; then
	    # 连接到用户选择的screen会话
	    echo "按键盘 Ctra + a + d 退出"; sleep 3
	    screen -r $choice
	else
	    echo "输入错误或会话不存在。"
	    exit 1
	fi
}

# 查看当前已知链
function chains_list(){
	hyperlane chains list
}

# 停止节点
function stop_node(){
	# 获取当前运行的screen会话列表
	screens=$(screen -ls | grep -oP '\t\K[^\t]+' | sort)
	
	# 检查是否有screen会话
	if [ -z "$screens" ]; then
	    echo "没有节点在运行。"
	    exit 1
	fi
	
	# 显示screen会话列表供用户选择
	echo "检测到以下节点："
	echo "$screens"
	echo ""
	
	# 提示用户输入
	read -p "请输入要停止的节点: " choice
	
	# 检查用户输入是否为有效会话
	if [[ $screens == *$choice* ]]; then
	    session_id=$(screen -ls | grep -P "$choice\s+\d+\.\S+" | awk '{print $1}')
	
	    # 停止用户选择的screen会话
	    screen -X -S $session_id quit
	    echo "该节点已停止"
	else
	    echo "输入错误或会话不存在。"
	    exit 1
	fi
}

# 卸载节点
function uninstall_node(){
    screen -ls | grep -Po '\t\d+\.hyp-\t' | grep -Po '\d+' | xargs -r kill
	rm -rf $HOME/hyperlane-monorepo
	echo "卸载完成。"
}


# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===================HyperLane 一键部署脚本==================="
		echo "沟通电报群：https://t.me/lumaogogogo"
		echo "推荐配置：2C4G100G"
    	echo "=====================请选择要执行的操作====================="
	    echo "1. 部署节点 install_node"
	    echo "2. 查看支持链 chains_list"
	    echo "3. 启动节点 start_node"
	    echo "4. 查看日志 view_logs"
	    echo "5. 停止节点 stop_node"
	    echo "6. 卸载节点 uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) install_node ;;
	    2) chains_list ;;
	    3) start_node ;;
	    4) view_logs ;;
	    5) stop_node ;;
	    6) uninstall_node ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

main_menu