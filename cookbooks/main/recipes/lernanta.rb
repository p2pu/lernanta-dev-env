#Virtualenv setup

script "Setup bashrc" do
  interpreter "bash"
  code <<-EOH
      echo '\nsource ~/.lernanta\n workon lernanta\n cd /opt/lernanta' >> /home/p2pu/.bashrc
      echo '\nsource ~/.lernanta' >> /home/p2pu/.profile
      echo '\nsudo su p2pu' >> /home/vagrant/.bashrc
    EOH
end

template "/home/p2pu/.lernanta" do
  source "lernanta"
  owner "p2pu"
  group "p2pu"
  mode 0644
end

# We need this .gitignore file so so that the lernanta directory stays in the git repo.
# Git cannot have just empty folders in git so we need this file.
# We need the folder setup for when vagrant sets up shared folders on boot
# We delete the file here so that the directory is empty - git needs an empty
# directory to clone into.
file "/opt/lernanta/.gitignore" do
  action :delete
end

git "/opt/lernanta" do
  repository "https://github.com/p2pu/lernanta.git"
  reference "master"
  revision "HEAD"
  action :sync
end

bash "Switch git branch" do
  # user "p2pu"
  # group "p2pu"
  returns [0, 1, 128]
  cwd "/opt/lernanta"
  code "git checkout -b master"
end

# When using vagrant, there shared settings in Vagrantfile override this
directory "/opt/lernanta" do
  mode 0775
  action :create
  owner "p2pu"
  group "p2pu"
  recursive true
end

bash "Create database" do
  returns [0, 1]
  code "mysqladmin -u root -p#{node[:mysql][:server_root_password]} create #{node[:lernanta_database][:NAME]}"
end

# virtualenv "lernanta" do
#   owner "p2pu"
#   group "p2pu"
#   options "--system-site-packages"
#   action :create
# end

# Setting the user and group does not change to that user's environment
# This may be fixed into the future
# Using the sudo -l -c method
# See http://tickets.opscode.com/browse/CHEF-2288
bash "Make virtual env for lernanta" do
  # user "p2pu"
  # group "p2pu"
  returns [1]
  code <<-EOH
    sudo su -l -c 'mkvirtualenv lernanta --system-site-packages' p2pu
  EOH
end

bash "Install Pip Dependencies" do
  # user "p2pu"
  # group "p2pu"
  retries 10
  timeout 50000
  code <<-EOH
    sudo su -l -c 'workon lernanta && pip install -r /opt/lernanta/lernanta/requirements/dev.txt' p2pu
  EOH
end

# Generate a secret key
secret_key = ''
allowed = 'abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(-_=+)'
50.times { secret_key += allowed[rand(allowed.length)].to_s }
node[:secret_key] = secret_key

template "/opt/lernanta/lernanta/settings_local.py" do
  source "settings_local.py"
  mode 0644
  user "p2pu"
  group "p2pu"
  variables({:lernanta_database => node[:lernanta_database],
              :secret_key => node[:secret_key] })
end

template "/opt/lernanta/lernanta/settings.py" do
  source "settings.py"
  mode 0644
  user "p2pu"
  group "p2pu"
end

bash "Make Database" do
  # user "p2pu"
  # group "p2pu"
  code <<-EOH
    sudo su -l -c 'workon lernanta && python /opt/lernanta/lernanta/manage.py syncdb --noinput' p2pu
  EOH
end

bash "Generate Static HTML" do
  # user "p2pu"
  # group "p2pu"
  code <<-EOH
    sudo su -l -c 'workon lernanta && python /opt/lernanta/lernanta/manage.py collectstatic --noinput' p2pu
  EOH
end

bash "Run Server" do
  # user "p2pu"
  # group "p2pu"
  code <<-EOH
    sudo su -l -c 'workon lernanta && python /opt/lernanta/lernanta/manage.py runserver 0.0.0.0:8000 >> /opt/lernanta/lernanta/runserver.log 2>&1 &' p2pu
  EOH
end
