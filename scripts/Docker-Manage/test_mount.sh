#!/bin/bash
RED='\033[0;31m'      
GREEN='\033[0;32m'    
YELLOW='\033[0;33m'   
BLUE='\033[0;34m'     
NC='\033[0m'          

echo -e "\n${BLUE}Docker 绑定挂载 (Bind Mounts) 状态:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------${NC}"
printf "%-25s %-45s %-45s\n" "容器名称" "宿主机路径 (Source)" "容器路径 (Destination)"
echo -e "${YELLOW}--------------------------------------------------------------------------${NC}"

docker ps -a --format '{{.Names}}' | while read -r container; do
    docker inspect --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}::{{.Destination}}{{println}}{{end}}{{end}}' "$container" 2>/dev/null | while read -r mount; do
        if [[ -n "$mount" ]]; then
            source_path="${mount%%::*}"
            dest_path="${mount##*::}"
            printf "${GREEN}%-25s %-45s %-45s${NC}\n" "$container" "$source_path" "$dest_path"
        fi
    done
done
