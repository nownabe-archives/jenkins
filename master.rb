include_recipe "nownabe_centos7_base"

# Jenkins

jenkins_repo_uri = "http://pkg.jenkins-ci.org/redhat/jenkins.repo"

execute "install jenkins repository" do
  command "curl -o /etc/yum.repos.d/jenkins.repo #{jenkins_repo_uri}"
  not_if "[ -f /etc/yum.repos.d/jenkins.repo ]"
end

execute "install jenkins gpg key" do
  command "rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key"
  not_if "rpm -q gpg-pubkey-d50582e6-4a3feef6"
end

package "java-1.7.0-openjdk"
package "jenkins"

service "jenkins" do
  action [:enable, :start]
end

execute "generate jenkins keys" do
  command "ssh-keygen -t rsa -N '' -f /var/lib/jenkins/.ssh/id_rsa"
  user "jenkins"
  not_if "[ -f /var/lib/jenkins/.ssh/id_rsa ]"
end

# Backup
jenkins_backup_url  = "https://raw.githubusercontent.com/sue445/jenkins-backup-script/master/jenkins-backup.sh"
jenkins_backup_path = "/usr/local/bin/jenkins-backup"
node.reverse_merge!(
  idcf: {
    backup_to_object_storage: {
      access_key: node[:object_storage][:access_key],
      secret_key: node[:object_storage][:secret_key],
      directories: [
        {
          schedule: node[:backup][:schedule],
          path: "/var/lib/jenkins-backup/",
          bucket: node[:backup][:bucket],
          expire: node[:backup][:expire],
          command: "#{jenkins_backup_path} /var/lib/jenkins /var/lib/jenkins-backup/jenkins_`date +%Y%m%d%H%M`.tar.gz"
        }
      ]
    }
  }
)
include_recipe "idcf-backup_to_object_storage"

directory "/var/lib/jenkins-backup"

execute "chown jenkins-backup" do
  command "chown root:root #{jenkins_backup_path}"
  action :nothing
end
execute "chmod jenkins-backup" do
  command "chmod 755 #{jenkins_backup_path}"
  action :nothing
end

execute "download jenkins-backup" do
  command "curl -o #{jenkins_backup_path} #{jenkins_backup_url}"
  not_if "[ -f #{jenkins_backup_path} ]"
  notifies :run, "execute[chown jenkins-backup]", :immediately
  notifies :run, "execute[chmod jenkins-backup]", :immediately
end
