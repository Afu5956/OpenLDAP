# slapd_install.sh
This script is tested based on the CentOS7 X86_64 version. Although CentOS8 is also supported, you must manually edit
the repo source to enable the Plus repo. Would you please make sure that the Plus repo is enabled when installing in
the CentOS8 system!

In addition, if the slapd service exists in the system, this script will perform a backup first. And the default
"openldap_backup_"$CURDATE"" directory is created in the /home directory, where "CURDATE" is a certain time value, and
the defined content is "CURDATE=$(date "+%Y-%m-%d--%H -%M-%S")".

Regarding the LDAP ROOT password, you can modify the variable "ROOTPW" for assignment.

Regarding schema, all schemas are installed by default. You can delete as needed, and it depends on your choice.


Default configuration
# DN and DN admin
default DN: dc=cm,dc=cluster

default DN admin: cn=bioroot,dc=cm,dc=cluster

default DN admin password: Bioxi2021

# Anonymous query is disabled by default. The client and server communicate to query users and use specified users to query LDAP DB user information.
query user: cn=queryuserinfo,ou=queryadmin,dc=cm,dc=cluster

query user password: QueryInfo@2021
