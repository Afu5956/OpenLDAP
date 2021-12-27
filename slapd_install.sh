#!/bin/bash

set -o pipefail

# "install packages"
SLAPDLDIF="/usr/share/openldap-servers/slapd.ldif"
CURDATE=$(date "+%Y-%m-%d--%H-%M-%S")
if [[ -f ${SLAPDLDIF} ]];then
    # "As a preventive measure, to prevent the installation script from being executed in the wrong scenario, this"
    # "script will use the following steps to back up data such as configuration and users."
    mkdir /home/openldap_backup_"$CURDATE"
    # "backup slapd database"
    # "backup the configuration directory"
    slapcat -n 0 -l backup_conf_"$CURDATE".ldif
    # "backup the data directories"
    slapcat -n 2 -l backup_users_"$CURDATE".ldif
    # "In the initial installation stage, to successfully install and set up the service, you must delete the previous"
    # "settings and the data in the DB when reinstalling. The rude and straightforward way is to use the following"
    #  "command to delete the two specified directories."
    # "/var/lib/ldap" | "/etc/openldap"
    rm -rf /var/lib/ldap
    rm -rf /etc/openldap
    yum reinstall -y openldap openldap-clients openldap-servers openldap-devel vim nss-pam-ldapd
    systemctl enable slapd
    systemctl restart slapd
else
    yum install  -y openldap openldap-clients openldap-servers openldap-devel vim nss-pam-ldapd
    systemctl enable slapd
    systemctl restart slapd
fi

# "ldap admin password"
ROOTPW=$(slappasswd -s Bioxi2021)

# "Check DB_CONFIG exist!"
if [[ -f /var/lib/ldap/DB_CONFIG ]]
then
    echo "DB_CONFIG exist!"
    rm -rf /var/lib/ldap/DB_CONFIG
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown ldap:ldap /var/lib/ldap/DB_CONFIG
else
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown ldap:ldap /var/lib/ldap/DB_CONFIG
fi

# "create base entry ldif"
cat > admin.ldif <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=bio,dc=cluster
-
replace: olcRootDN
olcRootDN: cn=bioroot,dc=bio,dc=cluster
-
replace: olcRootPW
olcRootPW: $ROOTPW

dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by \
dn.base="cn=bioroot,dc=bio,dc=cluster" read by * none
EOF
cat > add_memberof.ldif <<EOF
dn: cn=module{0},cn=config
cn: modulle{0}
objectClass: olcModuleList
objectClass: top
olcModuleload: memberof.la
olcModulePath: /usr/lib64/openldap

dn: olcOverlay={0}memberof,olcDatabase={2}hdb,cn=config
objectClass: olcConfig
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: top
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfUniqueNames
olcMemberOfMemberAD: uniqueMember
olcMemberOfMemberOfAD: memberOf
EOF
cat > refint.ldif <<EOF
# Load refint module
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: refint

# Backend refint overlay
dn: olcOverlay={1}refint,olcDatabase={2}hdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
olcOverlay: {1}refint
olcRefintAttribute: owner
olcRefintAttribute: manager
olcRefintAttribute: uniqueMember
olcRefintAttribute: memberOf
EOF
cat > disbale_anonymous.ldif <<EOF
dn: cn=config
changetype: modify
add: olcDisallows
olcDisallows: bind_anon
-
add: olcRequires
olcRequires: authc

dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcRequires
olcRequires: authc
EOF
cat > acl.ldif <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by dn="cn=bioroot,dc=bio,dc=cluster" write by anonymous auth by \
self write by * none
olcAccess: {2}to by dn="cn=bioroot,dc=bio,dc=cluster" write by * read
EOF
cat > base_dc.ldif <<EOF
dn: dc=bio,dc=cluster
o: company
objectClass: top
objectclass: dcObject
objectclass: organization
EOF
cat > QueryUserInfo.ldif <<EOF
dn: ou=queryadmin,dc=bio,dc=cluster
objectClass: organizationalUnit
ou: biounit
description: Query LDAP user information.
EOF
cat > queryuser.ldif <<EOF
dn: cn=queryuserinfo,ou=queryadmin,dc=bio,dc=cluster
changetype: add
cn: queryuserinfo
sn: queryuserinfo
objectClass: organizationalPerson
objectClass: person
objectClass: top
description: Query LDAP user information.
userPassword:: e1NIQX0zNGEvbG9tMm9USHpHY2JkdnF1TUNHOFg4eWs9
EOF
cat > biounit.ldif <<EOF
dn: ou=biounit,dc=bio,dc=cluster
objectClass: organizationalUnit
ou: biounit
EOF
cat > biogroup.ldif <<EOF
dn: cn=biogroup,ou=biounit,dc=bio,dc=cluster
changetype: add
gidNumber: 3001
cn: biogroup
objectClass: posixGroup
objectClass: top
EOF
cat > biouser.ldif <<EOF
dn: ou=biouser,dc=bio,dc=cluster
objectClass: organizationalUnit
ou: biouser
EOF
cat > testuser_xixi.ldif <<EOF
dn: uid=xixi,ou=biouser,dc=bio,dc=cluster
changetype: add
uid: xixi
uidNumber: 3001
homeDirectory: /home/xixi
gidNumber: 3001
description: xixi@bio.cluster
cn: xixi
sn: xixi
objectClass: posixAccount
objectClass: organizationalPerson
objectClass: person
objectClass: top
loginShell: /bin/bash
userPassword:: e1NIQX1waFV0dmlrOUlZalRGQ0pCUDR6WFZoVCtkQVk9
EOF

CENTOS8ROCKYLINUX=$(uname -r | awk -F"." '{print $1}')
if [[ ${CENTOS8ROCKYLINUX} != "4" ]];then
    # "import schema"
    find /etc/openldap/schema/ -type f -name "*.ldif" -print0 | xargs -0 -I {} ldapadd -Y EXTERNAL -H ldapi:/// -f {}
    # "Base entry information."
    # "modify EXTERNAL"
    ldapmodify -Y EXTERNAL -H ldapi:/// -f admin.ldif
    # "add EXTERNAL"
    for ADDEXTERNAL in add_memberof.ldif refint.ldif disbale_anonymous.ldif
    do
        ldapadd -Q -Y EXTERNAL -H ldapi:/// -f $ADDEXTERNAL
    done
    # "base dc information, user password policies."
    ldapadd -x -D 'cn=bioroot,dc=bio,dc=cluster' -wBioxi2021 -f base_dc.ldif
    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f acl.ldif
    # "add group, user and test user"
    # "Use the LDIF file to import configuration information or modify attribute values separately,"
    # "and you can use the following commands."
    # "example: ldapadd -x -D 'cn=bioroot,dc=bio,dc=cluster' -wBioxi2021 -f QueryUserInfo.ldif"
    for GUINFO in QueryUserInfo.ldif queryuser.ldif biounit.ldif biogroup.ldif biouser.ldif testuser_xixi.ldif
    do
        ldapadd -x -D 'cn=bioroot,dc=bio,dc=cluster' -wBioxi2021 -f $GUINFO
    done
else
    for MODIFYLDIF in acl.ldif refint.ldif admin.ldif add_memberof.ldif;do
    sed -i "s#{2}hdb#{2}mdb#g" $MODIFYLDIF
    done
    # "import schema"
      find /etc/openldap/schema/ -type f -name "*.ldif" -print0 | xargs -0 -I {} ldapadd -Y EXTERNAL -H ldapi:/// -f {}
    # "Base entry information."
    # "modify EXTERNAL"
    ldapmodify -Y EXTERNAL -H ldapi:/// -f admin.ldif
    # add EXTERNAL
    for ADDEXTERNAL in add_memberof.ldif refint.ldif disbale_anonymous.ldif
    do
        ldapadd -Q -Y EXTERNAL -H ldapi:/// -f $ADDEXTERNAL
    done
    # "Base dc information, user password policies."
    ldapadd -x -D 'cn=bioroot,dc=bio,dc=cluster' -wBioxi2021 -f base_dc.ldif
    # "modify EXTERNAL"
    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f acl.ldif
    for GUINFO in QueryUserInfo.ldif queryuser.ldif biounit.ldif biogroup.ldif biouser.ldif testuser_xixi.ldif
    do
        ldapadd -x -D 'cn=bioroot,dc=bio,dc=cluster' -wBioxi2021 -f $GUINFO
    done
fi

# delete ldif
rm -rf admin.ldif add_memberof.ldif refint.ldif disbale_anonymous.ldif acl.ldif base_dc.ldif \
QueryUserInfo.ldif queryuser.ldif biounit.ldif biogroup.ldif biouser.ldif testuser_xixi.ldif
