Configure Your Workspace Once for All~
==============================================


Getting Started
---------------
```
git clone https://github.com/iwzbi/envconfig.git
cd envconfig
pip install -r requirements.txt
ansible-playbook -i inventory.ini configme.yaml
```
Then `source ~/.zshrc` or `docker exec -it $CONTAINER /bin/zsh` if you are working in docker
