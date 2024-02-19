#!/bin/bash

CUR_USER="$(whoami)"

function select_project() {
  echo "==========================="
  echo " SELECT PROJECT"
  echo "==========================="
  PS3="> "
  select sitename in $(find ~/sites/* -maxdepth 0 -type d -exec basename {} \;); do
    test -n "$sitename" && break;
    echo ">>> Invalid Selection";
  done
}

PS3="Choose action: "

select action in "Start site" "Stop Site" "Create Site" "Delete Site & Files" "Restart Site" "Fix Permissions" "Add SSH Key" "Container Shell" "Fail2ban Status" "Unban IP" "Whitelist IP" "Prune Docker Images" "MariaDB Upgrade" "Change Site Domain" "DB Search Replace" "Quit"
do
    case $action in
        "Start site")
          echo -e "\e[36mStarting site...\e[0m"
          select_project
          docker compose -f "/home/$CUR_USER/sites/$sitename/docker-compose.yml" up -d
          echo -e "\e[32mSite started 👍\e[0m"
          break;;
        "Stop Site")
          echo -e "\e[36mStopping site...\e[0m"
          select_project
          docker compose -f "/home/$CUR_USER/sites/$sitename/docker-compose.yml" stop
          echo -e "\e[32mSite stopped 👍\e[0m"
          break;;
        "Restart Site")
          echo -e "\e[36mRestarting site...\e[0m"
          select_project
          docker compose -f "/home/$CUR_USER/sites/$sitename/docker-compose.yml" restart
          echo -e "\e[32mSite restarted 👍\e[0m"
          break;;
        "Create Site")
          echo -e "\e[36mCreating site...\e[0m"
          curl -s https://raw.githubusercontent.com/BOOST-Creative/docker-server-setup-caddy/main/newsite.sh > ~/.newsite.sh && chmod +x ~/.newsite.sh && ~/.newsite.sh
          break;;
        "Delete Site & Files")
          echo -e "\e[36mDeleting site (seriously, this will completely delete everything)...\e[0m"
          read -r -p "Enter site name or abbreviation (no spaces) TO COMPLETELY DELETE: " sitename
          docker compose -f "/home/$CUR_USER/sites/$sitename/docker-compose.yml" stop
          docker compose -f "/home/$CUR_USER/sites/$sitename/docker-compose.yml" rm
          sudo rm -r "/home/$CUR_USER/sites/$sitename"
          break;;
        "Fix Permissions")
          echo -e "\e[36mFixing permissions...\e[0m"
          select_project
          sudo chown -R nobody: "/home/$CUR_USER/sites/$sitename/wordpress"
          sudo find "/home/$CUR_USER/sites/$sitename" -type d -exec chmod 755 {} +
          sudo find "/home/$CUR_USER/sites/$sitename/wordpress" -type f -exec chmod 644 {} +
          echo -e "\e[32mPermissions updated 👍\e[0m"
          break;;
        "Add SSH Key")
          read -r -p "Please paste your public SSH key: " sshkey
          echo "$sshkey" >> /home/"$CUR_USER"/.ssh/authorized_keys
          echo -e "\e[32mSSH key added 👍\e[0m"
          break;;
        "Container Shell")
          select_project
          echo -e "\e[36mConnecting shell for $sitename...\e[0m"
          docker exec -it "$sitename" ash
          break;;
        "Fail2ban Status")
          docker exec fail2ban sh -c "fail2ban-client status | sed -n 's/,//g;s/.*Jail list://p' | xargs -n1 fail2ban-client status"
          break;;
        "Unban IP")
          read -r -p "Enter IP Address: " unbanip
          JAILS=$(docker exec fail2ban sh -c "fail2ban-client status | grep 'Jail list'" | sed -E 's/^[^:]+:[ \t]+//' | sed 's/,//g')
          for JAIL in $JAILS
          do
            docker exec fail2ban sh -c "fail2ban-client set $JAIL unbanip $unbanip"
          done
          echo -e "\e[32m$unbanip has been unbanned. If needs to be whitelisted, make sure you do that as well 👍\e[0m"
          break;;
        "Whitelist IP")
          read -r -p "Enter IP Address: " whitelistip
          sudo sed -i "s|ignoreip =.*|& $whitelistip|" ~/server/fail2ban/data/jail.d/jail.local
          docker exec fail2ban sh -c "fail2ban-client reload"
          echo -e "\e[32m$whitelistip has been whitelisted. If it's currently banned, make sure you unban it as well 👍\e[0m"
          break;;
        "Prune Docker Images")
          docker image prune -a
          break;;
        "MariaDB Upgrade")
          docker exec mariadb sh -c 'mysql_upgrade -uroot -p"$MYSQL_ROOT_PASSWORD"'
          break;;
        "Change Site Domain")
          select_project
          echo -e "Current domain(s): \e[36m$(yq '.services.wordpress.labels.caddy' "/home/$CUR_USER/sites/$sitename/docker-compose.yml")\e[0m"
          # change domain
          read -r -p "Enter new domain(s) (separate w/ spaces): " newdomain
          yq -i ".services.wordpress.labels.caddy = \"$newdomain\"" "/home/$CUR_USER/sites/$sitename/docker-compose.yml"
          # set or delete insecure tls
          read -r -p "Self signed certificate (y/n)? " insecuretls
          if [[ $insecuretls =~ ^[Yy]$ ]]; then
            yq -i '.services.wordpress.labels."caddy.tls" = "internal"' "/home/$CUR_USER/sites/$sitename/docker-compose.yml"
          else
            yq -i 'del(.services.wordpress.labels."caddy.tls")' "/home/$CUR_USER/sites/$sitename/docker-compose.yml"
          fi
          docker compose -f "/home/$CUR_USER/sites/$sitename/docker-compose.yml" up -d
          echo -e "\e[32mDomain updated 👍\e[0m"
          break;;
        "DB Search Replace")
          select_project
          read -r -p "Enter search string: " searchstring
          read -r -p "Enter replace string: " replacestring
          docker exec "$sitename" sh -c "cd /usr/src/wordpress && wp search-replace '$searchstring' '$replacestring' --all-tables"
          break;;
        "Quit")
          echo "Goodbye 👍"
          break;;
        *)
          echo "huh?";;
    esac
  rm ./.boost.sh
done