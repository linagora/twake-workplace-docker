SET client_encoding = 'UTF8';
SET client_min_messages = warning;
\set ON_ERROR_STOP

BEGIN;
-- default domain policy
INSERT INTO domain_access_policy(id, creation_date, modification_date) 
	VALUES (1, now(), now());
INSERT INTO domain_access_rule(id, domain_access_rule_type, domain_id, domain_access_policy_id, rule_index) 
	VALUES (1, 0, null, 1,0);
INSERT INTO domain_policy(id, uuid, label, domain_access_policy_id, creation_date, modification_date)
	VALUES (1, 'DefaultDomainPolicy', 'DefaultDomainPolicy', 1, now(), now());

-- Root domain (application domain)
INSERT INTO domain_abstract(id, type , uuid, label, enable, template, description, default_role, default_locale, purge_step, default_mail_locale, creation_date, modification_date, user_provider_id, domain_policy_id, parent_id, auth_show_order) 
	VALUES (1, 0, 'LinShareRootDomain', 'LinShareRootDomain', true, false, 'The root application domain', 3, 'en','IN_USE', 'en', now(), now(), null, 1, null, 0);

-- Default mime policy
INSERT INTO mime_policy(id, domain_id, uuid, name, mode, displayable, creation_date, modification_date, unknown_type_allowed) 
	VALUES(1, 1, '3d6d8800-e0f7-11e3-8ec0-080027c0eef0', 'Default Mime Policy', 0, 0, now(), now(), false);
UPDATE domain_abstract SET mime_policy_id=1;

-- login is e-mail address 'root@localhost.localdomain' and password is 'adminlinshare'
-- password generated from https://www.browserling.com/tools/bcrypt
INSERT INTO account(id, Mail, account_type, ls_uuid, creation_date, modification_date, role_id, mail_locale, external_mail_locale, cmis_locale, enable, password, destroyed, domain_id, purge_step, First_name, Last_name, Can_upload, Comment, Restricted, CAN_CREATE_GUEST, authentication_failure_count, default_can_view_contact_list_members)
	VALUES (1, 'root@localhost.localdomain', 6, 'root@localhost.localdomain', now(),now(), 3, 'en','en','en', true, '{bcrypt}$2a$10$LQSvbfb2ZsCrWzPp5lj2weSZCz2fWRDBOW4k3k0UxxtdFIEquzTA6', 0, 1, 'IN_USE', 'Super', 'Administrator', true, '', false, false, 0, false);

-- system account :
INSERT INTO account(id, mail, account_type, ls_uuid, creation_date, modification_date, role_id, mail_locale, external_mail_locale, cmis_locale, enable, destroyed, domain_id, purge_step, can_upload, restricted, can_create_guest, authentication_failure_count, default_can_view_contact_list_members)
	VALUES (2, 'system', 7, 'system', now(),now(), 3, 'en', 'en','en',true, 0, 1, 'IN_USE', false, false, false, 0, false);
-- system account for upload-request:
INSERT INTO account(id, mail, account_type, ls_uuid, creation_date, modification_date, role_id, mail_locale, external_mail_locale, cmis_locale, enable, destroyed, domain_id, purge_step, can_upload, restricted, can_create_guest, authentication_failure_count, default_can_view_contact_list_members)
	VALUES (3,'system-account-uploadrequest', 7, 'system-account-uploadrequest', now(),now(), 6, 'en','en','en', true, 0, 1, 'IN_USE', false, false, false, 0, false);

-- System account for anonymous share
INSERT INTO account(id, mail, account_type, ls_uuid, creation_date, modification_date, role_id, mail_locale, external_mail_locale, cmis_locale, enable, destroyed, domain_id, purge_step, can_upload, restricted, can_create_guest, authentication_failure_count, default_can_view_contact_list_members)
	VALUES (4,'system-anonymous-share-account', 7, 'system-anonymous-share-account', now(),now(), 8, 'en','en','en', true, 0, 1, 'IN_USE', false, false, false, 0, false);

-- system
-- OBM user ldap pattern.
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    description,
    auth_command,
    search_user_command,
    system,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes,
    search_page_size,
    search_size_limit,
    completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date)
VALUES (
    1,
    'cd26e59d-6d4c-41b4-a0eb-610fd42e1beb',
    'USER_LDAP_PATTERN',
    'default-pattern-obm',
    'This is pattern the default pattern for the ldap obm structure.',
    'ldap.search(domain, "(&(objectClass=obmUser)(mail=*)(givenName=*)(sn=*)(|(mail="+login+")(uid="+login+")))");',
    'ldap.search(domain, "(&(objectClass=obmUser)(mail="+mail+")(givenName="+first_name+")(sn="+last_name+"))");',
    true,
    'ldap.search(domain, "(&(objectClass=obmUser)(mail=*)(givenName=*)(sn=*)(|(&(sn=" + first_name + ")(givenName=" + last_name + "))(&(sn=" + last_name + ")(givenName=" + first_name + "))))");',
    'ldap.search(domain, "(&(objectClass=obmUser)(mail=*)(givenName=*)(sn=*)(|(mail=" + pattern + ")(sn=" + pattern + ")(givenName=" + pattern + ")))");',
    100,
    100,
    10,
    10,
    now(),
    now()
);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (1, 'user_mail', 'mail', false, true, true, 1, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (2, 'user_firstname', 'givenName', false, true, true, 1, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (3, 'user_lastname', 'sn', false, true, true, 1, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (4, 'user_uid', 'uid', false, true, true, 1, false);

-- Active Directory domain pattern.
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    description,
    auth_command,
    search_user_command,
    system,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes,
    search_page_size,
    search_size_limit,
    completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date)
VALUES (
    2,
    'af7ceb1e-9268-4b20-af80-21fa4bd5222c',
    'USER_LDAP_PATTERN',
    'default-pattern-AD',
    'This is pattern the default pattern for the Active Directory structure.',
    'ldap.search(domain, "(&(objectClass=user)(mail=*)(givenName=*)(sn=*)(|(mail="+login+")(sAMAccountName="+login+")))");',
    'ldap.search(domain, "(&(objectClass=user)(mail="+mail+")(givenName="+first_name+")(sn="+last_name+"))");',
    true,
    'ldap.search(domain, "(&(objectClass=user)(mail=*)(givenName=*)(sn=*)(|(&(sn=" + first_name + ")(givenName=" + last_name + "))(&(sn=" + last_name + ")(givenName=" + first_name + "))))");',
    'ldap.search(domain, "(&(objectClass=user)(mail=*)(givenName=*)(sn=*)(|(mail=" + pattern + ")(sn=" + pattern + ")(givenName=" + pattern + ")))");',
    100,
    100,
    10,
    10,
    now(),
    now()
);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (5, 'user_mail', 'mail', false, true, true, 2, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (6, 'user_firstname', 'givenName', false, true, true, 2, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (7, 'user_lastname', 'sn', false, true, true, 2, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (8, 'user_uid', 'sAMAccountName', false, true, true, 2, false);

-- OpenLdap ldap pattern.
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    description,
    auth_command,
    search_user_command,
    system,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes,
    search_page_size,
    search_size_limit,
    completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date)
VALUES (
    3,
    '868400c0-c12e-456a-8c3c-19e985290586',
    'USER_LDAP_PATTERN',
    'default-pattern-openldap',
    'This is pattern the default pattern for the OpenLdap structure.',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail=*)(givenName=*)(sn=*)(|(mail="+login+")(uid="+login+")))");',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail="+mail+")(givenName="+first_name+")(sn="+last_name+"))");',
    true,
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail=*)(givenName=*)(sn=*)(|(&(sn=" + first_name + ")(givenName=" + last_name + "))(&(sn=" + last_name + ")(givenName=" + first_name + "))))");',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail=*)(givenName=*)(sn=*)(|(mail=" + pattern + ")(sn=" + pattern + ")(givenName=" + pattern + ")))");',
    100,
    100,
    10,
    10,
    now(),
    now()
);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (9, 'user_mail', 'mail', false, true, true, 3, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (10, 'user_firstname', 'givenName', false, true, true, 3, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (11, 'user_lastname', 'sn', false, true, true, 3, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (12, 'user_uid', 'uid', false, true, true, 3, false);

-- Group ldap pattern
INSERT INTO ldap_pattern(
	id,
	uuid,
	pattern_type,
	label,
	system,
	description,
	auth_command,
	search_user_command,
	search_page_size,
	search_size_limit,
	auto_complete_command_on_first_and_last_name,
	auto_complete_command_on_all_attributes, completion_page_size,
	completion_size_limit,
	creation_date,
	modification_date,
	search_all_groups_query,
	search_group_query,
	group_prefix)
	VALUES(
	4,
	'dfaa3523-51b0-423f-bb6d-95d6ecbfcd4c',
	'GROUP_LDAP_PATTERN',
	'Ldap groups',
	true,
	'default-group-pattern',
	NULL,
	NULL,
	100,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NOW(),
	NOW(),
	'ldap.search(baseDn, "(&(objectClass=groupOfNames)(cn=workgroup-*))");',
	'ldap.search(baseDn, "(&(objectClass=groupOfNames)(cn=workgroup-" + pattern + "))");',
	'workgroup-');


-- ldap attributes
INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(13, 'mail', 'member_mail', false, true, true, false, 4);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(14, 'givenName', 'member_firstname', false, true, true, false, 4);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(15, 'cn', 'group_name_attr', false, true, true, true, 4);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(16, 'member', 'extended_group_member_attr', false, true, true, true, 4);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(17, 'sn', 'member_lastname', false, true, true, false, 4);

-- WORK_SPACE ldap pattern
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    system,
    description,
    auth_command,
    search_user_command,
    search_page_size,
    search_size_limit,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes, completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date,
    search_all_groups_query,
    search_group_query,
    group_prefix)
    VALUES(
    6,
    'c59078f1-2366-4360-baa0-6c089202e9a6',
    'WORK_SPACE_LDAP_PATTERN',
    'Default Ldap workSpace filter',
    true,
    'default-workSpace-filter',
    NULL,
    NULL,
    100,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NOW(),
    NOW(),
    'ldap.search(baseDn, "(&(objectClass=groupOfNames)(cn=workspace-*))");',
    'ldap.search(baseDn, "(&(objectClass=groupOfNames)(cn=workspace-" + pattern + "))");',
    'workspace-');

-- ldap attributes
INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(22, 'mail', 'member_mail', false, true, true, false, 6);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(23, 'givenName', 'member_firstname', false, true, true, false, 6);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(24, 'cn', 'group_name_attr', false, true, true, true, 6);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(25, 'member', 'extended_group_member_attr', false, true, true, true, 6);

INSERT INTO ldap_attribute
(id, attribute, field, sync, system, enable, completion, ldap_pattern_id)
VALUES(26, 'sn', 'member_lastname', false, true, true, false, 6);


-- Demo ldap pattern.
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    description,
    auth_command,
    search_user_command,
    system,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes,
    search_page_size,
    search_size_limit,
    completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date)
VALUES (
    5,
    'a4620dfc-dc46-11e8-a098-2355f9d6585a',
    'USER_LDAP_PATTERN',
    'default-pattern-demo',
    'This is pattern the default pattern for the OpenLdap demo structure.',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(employeeType=Internal)(mail=*)(givenName=*)(sn=*)(|(mail="+login+")(uid="+login+")))");',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(employeeType=Internal)(mail="+mail+")(givenName="+first_name+")(sn="+last_name+"))");',
    true,
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(employeeType=Internal)(mail=*)(givenName=*)(sn=*)(|(&(sn=" + first_name + ")(givenName=" + last_name + "))(&(sn=" + last_name + ")(givenName=" + first_name + "))))");',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(employeeType=Internal)(mail=*)(givenName=*)(sn=*)(|(mail=" + pattern + ")(sn=" + pattern + ")(givenName=" + pattern + ")))");',
    100,
    100,
    10,
    10,
    now(),
    now()
);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (18, 'user_mail', 'mail', false, true, true, 5, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (19, 'user_firstname', 'givenName', false, true, true, 5, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (20, 'user_lastname', 'sn', false, true, true, 5, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (21, 'user_uid', 'uid', false, true, true, 5, false);

-- OpenLdap ldap filter to search users by group memberShip.
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    description,
    auth_command,
    search_user_command,
    system,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes,
    search_page_size,
    search_size_limit,
    completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date)
VALUES (
    7,
    'd277f339-bc60-437d-8f66-515cba43df37',
    'USER_LDAP_PATTERN',
    'default-openldap-filtered-by-group-membership',
    'This is default openldap filtered by group membership.',
    'var group_dn = "cn=regular-users,ou=Groups,dc=linshare,dc=org";
    // initial query; looking for users
    var users = ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail=*)(givenName=*)(sn=*)(|(mail="+login+")(uid="+login+")))");
    logger.trace("users: {}", users);
    // second query to get all members (dn) of a group
    var dn_group_members = ldap.attribute(group_dn, "member");
    logger.trace("dn_group_members: {}", dn_group_members);
    // this array will contains all members without the baseDn
    var group_members = new java.util.ArrayList();
    for (var i = 0; i < dn_group_members.length; i++) {
        group_members.add(dn_group_members[i].replace("," + domain,""));
    };
    logger.trace("group_members: {}", group_members);
    // this array will contain the result of a left join between users and group_members
    var output =  new java.util.ArrayList();
    for (var i = 0; i < users.length; i++) {
        if (group_members.contains(users[i])) {
            output.add(users[i]);
        }
    }
    logger.debug("users (filtered): {}", output);
    // we must "return" the result.
    output;',
    'var group_dn = "cn=regular-users,ou=Groups,dc=linshare,dc=org";
    // initial query; looking for users
    var users = ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail="+mail+")(givenName="+first_name+")(sn="+last_name+"))");
    logger.trace("users: {}", users);
    // second query to get all members (dn) of a group
    var dn_group_members = ldap.attribute(group_dn, "member");
    logger.trace("dn_group_members: {}", dn_group_members);
    // this array will contains all members without the baseDn
    var group_members = new java.util.ArrayList();
    for (var i = 0; i < dn_group_members.length; i++) {
        group_members.add(dn_group_members[i].replace("," + domain,""));
    };
    logger.trace("group_members: {}", group_members);
    // this array will contain the result of a left join between users and group_members
    var output =  new java.util.ArrayList();
    for (var i = 0; i < users.length; i++) {
        if (group_members.contains(users[i])) {
            output.add(users[i]);
        }
    }
    logger.debug("users (filtered): {}", output);
    // we must "return" the result.
    output;',
    true,
    'var group_dn = "cn=regular-users,ou=Groups,dc=linshare,dc=org";
    // initial query; looking for users
    var users = ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail=*)(givenName=*)(sn=*)(|(&(sn=" + first_name + ")(givenName=" + last_name + "))(&(sn=" + last_name + ")(givenName=" + first_name + "))))");
    logger.trace("users: {}", users);
    // second query to get all members (dn) of a group
    var dn_group_members = ldap.attribute(group_dn, "member");
    logger.trace("dn_group_members: {}", dn_group_members);
    // this array will contains all members without the baseDn
    var group_members = new java.util.ArrayList();
    for (var i = 0; i < dn_group_members.length; i++) {
        group_members.add(dn_group_members[i].replace("," + domain,""));
    };
    logger.trace("group_members: {}", group_members);
    // this array will contain the result of a left join between users and group_members
    var output =  new java.util.ArrayList();
    for (var i = 0; i < users.length; i++) {
        if (group_members.contains(users[i])) {
            output.add(users[i]);
        }
    }
    logger.debug("users (filtered): {}", output);
    // we must "return" the result.
    output;',
    'var group_dn = "cn=regular-users,ou=Groups,dc=linshare,dc=org";
    // initial query; looking for users
    var users = ldap.search(domain, "(&(objectClass=inetOrgPerson)(mail=*)(givenName=*)(sn=*)(|(mail=" + pattern + ")(sn=" + pattern + ")(givenName=" + pattern + ")))");
    logger.trace("users: {}", users);
    // second query to get all members (dn) of a group
    var dn_group_members = ldap.attribute(group_dn, "member");
    logger.trace("dn_group_members: {}", dn_group_members);
    // this array will contains all members without the baseDn
    var group_members = new java.util.ArrayList();
    for (var i = 0; i < dn_group_members.length; i++) {
        group_members.add(dn_group_members[i].replace("," + domain,""));
    };
    logger.trace("group_members: {}", group_members);
    // this array will contain the result of a left join between users and group_members
    var output =  new java.util.ArrayList();
    for (var i = 0; i < users.length; i++) {
        if (group_members.contains(users[i])) {
            output.add(users[i]);
        }
    }
    logger.debug("users (filtered): {}", output);
    // we must "return" the result.
    output;',
    100,
    100,
    10,
    10,
    now(),
    now()
);

INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (27, 'user_mail', 'mail', false, true, true, 7, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (28, 'user_firstname', 'givenName', false, true, true, 7, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (29, 'user_lastname', 'sn', false, true, true, 7, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (30, 'user_uid', 'uid', false, true, true, 7, false);

-- default-openldap-filtered-by-memberOf.
INSERT INTO ldap_pattern(
    id,
    uuid,
    pattern_type,
    label,
    description,
    auth_command,
    search_user_command,
    system,
    auto_complete_command_on_first_and_last_name,
    auto_complete_command_on_all_attributes,
    search_page_size,
    search_size_limit,
    completion_page_size,
    completion_size_limit,
    creation_date,
    modification_date)
VALUES (
    8,
    'a8914c53-4ad0-4b30-ae91-c2a2de8f8cc4',
    'USER_LDAP_PATTERN',
    'default-openldap-filtered-by-memberOf',
    'This is default openldap filtered by memberOf.',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(memberOf=cn=regular-users,ou=Groups,dc=linshare,dc=org)(mail=*)(givenName=*)(sn=*)(|(mail="+login+")(uid="+login+")))");',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(memberOf=cn=regular-users,ou=Groups,dc=linshare,dc=org)(mail="+mail+")(givenName="+first_name+")(sn="+last_name+"))");',
    true,
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(memberOf=cn=regular-users,ou=Groups,dc=linshare,dc=org)(mail=*)(givenName=*)(sn=*)(|(&(sn=" + first_name + ")(givenName=" + last_name + "))(&(sn=" + last_name + ")(givenName=" + first_name + "))))");',
    'ldap.search(domain, "(&(objectClass=inetOrgPerson)(memberOf=cn=regular-users,ou=Groups,dc=linshare,dc=org)(mail=*)(givenName=*)(sn=*)(|(mail=" + pattern + ")(sn=" + pattern + ")(givenName=" + pattern + ")))");',
    100,
    100,
    10,
    10,
    now(),
    now()
);

INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (31, 'user_mail', 'mail', false, true, true, 8, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (32, 'user_firstname', 'givenName', false, true, true, 8, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (33, 'user_lastname', 'sn', false, true, true, 8, true);
INSERT INTO ldap_attribute(id, field, attribute, sync, system, enable, ldap_pattern_id, completion)
	VALUES (34, 'user_uid', 'uid', false, true, true, 8, false);
-- root domain quota
INSERT INTO quota(id, uuid, creation_date, modification_date, batch_modification_date,
	current_value, last_value, domain_id,
    quota, quota_override,
    quota_warning,
    default_quota, default_quota_override,
    quota_type, current_value_for_subdomains)
VALUES (1, '2a01ac66-a279-11e5-9086-5404a683a462', NOW(), NOW(), null,
	0, 0, 1,
	10000000000000, null,
	10000000000000,
    1000000000000, true,
    'DOMAIN_QUOTA', 0);
-- quota : 10 To
-- quota_warning : 10000000000000 : 10 To
-- default_quota : 1000000000000 : 1 To (1 To per sub domain)
UPDATE quota SET default_max_file_size_override = null, default_account_quota_override = null, default_quota_override = null, quota_override = null WHERE id = 1;
UPDATE quota SET default_domain_shared = false, domain_shared = true WHERE id = 1;
UPDATE quota SET default_domain_shared_override = null, domain_shared_override = null WHERE id = 1;

-- 'CONTAINER_QUOTA', 'USER' for root domain
INSERT INTO quota(id, uuid, creation_date, modification_date, batch_modification_date,
	quota_domain_id, current_value, last_value, domain_id,
    quota, quota_override,
    quota_warning,
    default_quota, default_quota_override,
    default_max_file_size, default_max_file_size_override,
    default_account_quota, default_account_quota_override,
    max_file_size, max_file_size_override,
    account_quota, account_quota_override,
    quota_type, container_type, shared)
VALUES (11, '26323798-a1a8-11e6-ad47-0800271467bb', NOW(), NOW(), null,
	1, 0, 0, 1,
	400000000000, null,
    400000000000,
    400000000000, false,
    10000000000, null,
    100000000000, null,
    100000000000, null,
    100000000000, null,
    'CONTAINER_QUOTA', 'USER', false);
-- quota : 400000000000 : 400 Go for all users
-- quota_warning : 400000000000 : 400 Go
-- default_quota : 400000000000 : 400 Go
-- default_max_file_size : 10000000000  : 10 Go
-- default_account_quota : 100000000000 : 100 Go : default value for container created inside a container of a top domain
-- max_file_size : 100000000000  : 100 Go
-- account_quota : 100000000000 : 100 Go : value for account created inside container the root domain
UPDATE quota SET default_max_file_size_override = null, default_account_quota_override = null, default_quota_override = null, quota_override = null WHERE id = 11;

-- 'CONTAINER_QUOTA', 'WORK_GROUP' for root domain
INSERT INTO quota(id, uuid, creation_date, modification_date, batch_modification_date,
	quota_domain_id, current_value, last_value, domain_id,
    quota, quota_override,
    quota_warning,
    default_quota, default_quota_override,
    default_max_file_size, default_max_file_size_override,
    default_account_quota, default_account_quota_override,
    max_file_size, max_file_size_override,
    account_quota, account_quota_override,
    quota_type, container_type, shared)
VALUES (12, '63de4f14-a1a8-11e6-a369-0800271467bb', NOW(), NOW(), null,
	1, 0, 0, 1,
	400000000000, null,
    400000000000,
    400000000000, false,
    10000000000, null,
    400000000000, null,
    10000000000, null,
    400000000000, null,
    'CONTAINER_QUOTA', 'WORK_GROUP', true);
UPDATE quota SET default_max_file_size_override = null, default_account_quota_override = null, default_quota_override = null, quota_override = null WHERE id = 12;

-- quota : 400000000000 : 400 Go for all workgroups
-- quota_warning : 400000000000 : 400 Go
-- default_quota : 400000000000 : 400 Go
-- default_max_file_size : 10000000000  : 10 Go
-- default_account_quota : 400000000000 : 400 Go, also 400 Go for one workgroup
-- max_file_size : 10000000000  : 10 Go
-- account_quota : 400000000000 : 400 Go, also 400 Go for one workgroup

    -- root user ACCOUNT QUOTA
INSERT INTO quota(
    id, uuid, creation_date, modification_date, batch_modification_date,
    quota_container_id, current_value, last_value,
    domain_id, account_id, domain_parent_id,
    quota, quota_override,
    quota_warning,
    max_file_size, max_file_size_override,
    shared, quota_type)
VALUES (
    13, '815e1d22-49e0-4817-ac01-e7eefbee56ba', NOW(), NOW(), null,
    11, 0, 0,
    1, 1, null,
    100000000000, true,
    100000000000,
    100000000000, true,
    false, 'ACCOUNT_QUOTA');
UPDATE quota SET default_domain_shared = null, domain_shared = true WHERE id = 13;
UPDATE quota SET default_domain_shared_override = null, domain_shared_override = null WHERE id = 13;

--Welcome messages
INSERT INTO welcome_messages(id, uuid, name, description, creation_date, modification_date, domain_id)
	VALUES (1, '4bc57114-c8c9-11e4-a859-37b5db95d856', 'WelcomeName', 'a Welcome description', now(), now(), 1);
--Melcome messages Entry
INSERT INTO welcome_messages_entry(id, lang, value, welcome_messages_id)
	VALUES (1, 'en', '<h2>Welcome to LinShare</h2><p>Welcome to LinShare, THE Secure, Open-Source File Sharing Tool.</p>', 1);
INSERT INTO welcome_messages_entry(id, lang, value, welcome_messages_id)
	VALUES (2, 'fr', '<h2>Bienvenue dans LinShare</h2><p>Bienvenue dans LinShare, le logiciel libre de partage de fichiers sécurisé.</p>', 1);
INSERT INTO welcome_messages_entry(id, lang, value, welcome_messages_id)
	VALUES (3, 'vi', '<h2>Chào mừng bạn đến với LinShare</h2><p>Chào mừng bạn đến với LinShare, phần mềm nguồn mở chia sẻ file bảo mật.</p>', 1);
INSERT INTO welcome_messages_entry(id, lang, value, welcome_messages_id)
	VALUES (4, 'ru', '<h2>Добро пожаловать в LinShare</h2><p>Добро пожаловать в LinShare - открытое приложение для надежного обмена файлами.</p>', 1);
-- Default setting welcome messages for all domains
UPDATE domain_abstract SET welcome_messages_id = 1;--Functionality : FILESIZE_MAX
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (1, true, true, 1, false);
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (2, true, true, 1, false);
-- if a functionality is system, you will not be able see/modify its parameters
-- INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (1, false, 'FILESIZE_MAX', 1, 2, 1);
-- INSERT INTO unit(id, unit_type, unit_value) VALUES (1, 1, 1);
-- INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, integer_default_value) VALUES (1, 10, 1);


-- Functionality : QUOTA_GLOBAL
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (3, false, false, 1, false);
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (4, true, true, 1, false);
-- INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (2, false, 'QUOTA_GLOBAL', 3, 4, 1);
-- INSERT INTO unit(id, unit_type, unit_value) VALUES (2, 1, 1);
-- INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, integer_default_value) VALUES (2, 1, 2);


-- Functionality : QUOTA_USER
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (5, true, true, 1, false);
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (6, true, true, 1, false);
-- INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (3, false, 'QUOTA_USER', 5, 6, 1);
-- INSERT INTO unit(id, unit_type, unit_value) VALUES (3, 1, 1);
-- INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, integer_default_value) VALUES (3, 100, 3);


-- Functionality : MIME_TYPE
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (7, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (8, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date) 
	VALUES (4, true, 'MIME_TYPE', 7, 8, 1, now(), now());


--This functionality is not yet available in LinShare 2.0.0
---- Functionality : SIGNATURE
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (9, false, false, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (10, false, false, 2, true);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (5, true, 'SIGNATURE', 9, 10, 1);

--This functionality is not yet available in LinShare 2.0.0
---- Functionality : ENCIPHERMENT
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (11, false, false, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (12, false, false, 2, true);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (6, true, 'ENCIPHERMENT', 11, 12, 1);

-- Functionality : TIME_STAMPING
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (13, false, false, 2, true);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (14, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date) 
	VALUES (7, false, 'TIME_STAMPING', 13, 14, 1, now(), now());
INSERT INTO functionality_string(functionality_id, string_value) 
	VALUES (7, 'http://localhost:8080/signserver/tsa?signerId=1');


-- Functionality : ANTIVIRUS
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (15, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (16, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date) 
	VALUES (8, true, 'ANTIVIRUS', 15, 16, 1, now(), now());

--useless - deleted
---- Functionality : CUSTOM_LOGO
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (17, false, false, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (18, true, true, 1, false);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (9, false, 'CUSTOM_LOGO', 17, 18, 1);
--INSERT INTO functionality_string(functionality_id, string_value) VALUES (9, 'http://linshare-ui-user.local/custom/images/logo.png');

--useless - deleted
---- Functionality : CUSTOM_LOGO__LINK
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (59, false, false, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (60, false, false, 1, false);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param) VALUES (29, false, 'CUSTOM_LOGO__LINK', 59, 60, 1, 'CUSTOM_LOGO', true);
--INSERT INTO functionality_string(functionality_id, string_value) VALUES (29, 'http://linshare-ui-user.local');

-- Functionality : GUESTS
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (27, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (28, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date) 
	VALUES (14, true, 'GUESTS', 27, 28, 1, now(), now());

-- Functionality : GUESTS__EXPIRATION
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (19, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (20, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (111, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date) 
	VALUES (10, false, 'GUESTS__EXPIRATION', 19, 20, 111, 1, 'GUESTS', true, now(), now());
INSERT INTO unit(id, unit_type, unit_value) 
	VALUES (4, 0, 2), (13, 0, 2);
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used) 
	VALUES (10, 4, 4, 13, 3, true, true);

-- Functionality : GUESTS__RESTRICTED
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (47, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (48, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (112, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date) 
	VALUES (24, false, 'GUESTS__RESTRICTED', 47, 48, 112, 1, 'GUESTS', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value) 
	VALUES (24, true);

-- Functionality : GUESTS__CONTACT_LISTS
INSERT INTO policy(id, status, default_status, policy, system)
VALUES (359, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
VALUES (360, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
VALUES (361, false, false, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
VALUES (89, false, 'GUESTS__CONTACT_LISTS', 359, 360, 361, 1, 'GUESTS', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
VALUES (89, true);

-- Functionality : GUESTS__HIDE_MEMBERS
INSERT INTO policy(id, status, default_status, policy, system)
VALUES (362, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
VALUES (363, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
VALUES (364, false, false, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
VALUES (90, false, 'GUESTS__HIDE_MEMBERS', 362, 363, 364, 1, 'GUESTS', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
VALUES (90, true);

-- Functionality : GUESTS__CAN_UPLOAD
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (113, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (114, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (115, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date) 
	VALUES (48, false, 'GUESTS__CAN_UPLOAD', 113, 114, 115, 1, 'GUESTS', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (48, true);

-- Functionality : DOCUMENT_EXPIRATION
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (21, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (22, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date) 
	VALUES (11, false, 'DOCUMENT_EXPIRATION', 21, 22, 1, now(), now());
INSERT INTO unit(id, unit_type, unit_value) 
	VALUES (5, 0, 2),(14, 0, 2);
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used) 
	VALUES (11, 4, 5, 14, 3,true, false);


-- Functionality : SHARE_EXPIRATION
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (23, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (24, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (122, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, creation_date, modification_date) 
	VALUES (12, false, 'SHARE_EXPIRATION', 23, 24, 122, 1, now(), now());
INSERT INTO unit(id, unit_type, unit_value) 
	VALUES (6, 0, 2),(15, 0, 2);
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used) 
	VALUES (12, 4, 6, 15, 3, true, true);

-- Functionality : SHARE_EXPIRATION__DELETE_FILE_ON_EXPIRATION
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (120, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (121, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date) 
	VALUES (50, false, 'SHARE_EXPIRATION__DELETE_FILE_ON_EXPIRATION', 120, 121, 1, 'SHARE_EXPIRATION', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value) 
	VALUES (50, false);

-- Functionality : ANONYMOUS_URL
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (25, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (26, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (116, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, creation_date, modification_date) 
	VALUES (13, false, 'ANONYMOUS_URL', 25, 26, 116, 1, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (13, true);


-- Functionality : INTERNAL_ENABLE_PERSONAL_SPACE formerly known as USER_CAN_UPLOAD
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (29, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (30, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES (15, false, 'INTERNAL_ENABLE_PERSONAL_SPACE', 29, 30, 1, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
VALUES (15, true);

-- Functionality : COMPLETION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (31, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (32, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES (16, false, 'COMPLETION', 31, 32, 1, now(), now());
INSERT INTO functionality_integer(functionality_id, integer_max_value, integer_default_value, default_value_used, max_value_used )
	VALUES (16, 3, 3, true, false);

--useless - deleted
---- Functionality : TAB_HELP
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (33, true, true, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (34, false, false, 1, true);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (17, true, 'TAB_HELP', 33, 34, 1);

--useless - deleted
---- Functionality : TAB_AUDIT
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (35, true, true, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (36, false, false, 1, true);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (18, true, 'TAB_AUDIT', 35, 36, 1);

--useless - deleted
---- Functionality : TAB_USER
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (37, true, true, 1, false);
--INSERT INTO policy(id, status, default_status, policy, system) VALUES (38, false, false, 1, true);
--INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id) VALUES (19, true, 'TAB_USER', 37, 38, 1);

-- Functionality : SHARE_NOTIFICATION_BEFORE_EXPIRATION
-- Policies : MANDATORY(0), ALLOWED(1), FORBIDDEN(2)
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (43, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (44, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES (22, false, 'SHARE_NOTIFICATION_BEFORE_EXPIRATION', 43, 44, 1, now(), now());
INSERT INTO functionality_string(functionality_id, string_value)
	VALUES (22, '2,7');

-- Functionality : WORK_GROUP__CREATION_RIGHT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (57, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (58, false, false, 1, false);
-- INSERT INTO policy(id, status, default_status, policy, system) VALUES (117, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (28, false, 'WORK_GROUP__CREATION_RIGHT', 57, 58, 1, 'SHARED_SPACE', true, now(), now());
-- INSERT INTO functionality_boolean(functionality_id, boolean_value) VALUES (28, true);

	-- Functionality : WORK_GROUP__FILE_VERSIONING
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (297, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (298, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (299, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (63, false, 'WORK_GROUP__FILE_VERSIONING', 297, 298, 299, 1, 'SHARED_SPACE', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (63, true);

	-- Functionality : WORKGROUP__FILE_EDITION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (303, false, false, 2, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (304, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (305, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (65, true, 'WORK_GROUP__FILE_EDITION', 303, 304, 305, 1, 'SHARED_SPACE', false, now(), now());
INSERT INTO functionality_string(functionality_id, string_value) 
	VALUES (65, 'http://editor.linshare.local');

-- Functionality : WORK_GROUP__DOWNLOAD_ARCHIVE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (306, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (307, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (66, false, 'WORK_GROUP__DOWNLOAD_ARCHIVE', 306, 307, 1, 'SHARED_SPACE', true, now(), now());
INSERT INTO unit(id, unit_type, unit_value)
	VALUES (12, 1, 1),(16, 1, 1);
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used) 
	VALUES (66, 900, 12, 16, 0, false, true);

-- Functionality : CONTACTS_LIST
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (53, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (54, false, false, 1, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES (26, true, 'CONTACTS_LIST', 53, 54, 1, now(), now());

--Functionality : CONTACTS_LIST__CREATION_RIGHT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (55, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (56, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(27, false, 'CONTACTS_LIST__CREATION_RIGHT', 55, 56, null, 1, 'CONTACTS_LIST', true, now(), now());


-- Functionality : DOMAIN
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (118, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (119, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES(49, false, 'DOMAIN', 118, 119, 1, now(), now());

-- Functionality : DOMAIN__NOTIFICATION_URL
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (61, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (62, false, false, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(30, false, 'DOMAIN__NOTIFICATION_URL', 61, 62, 1, 'DOMAIN', true, now(), now());
INSERT INTO functionality_string(functionality_id, string_value)
	VALUES (30, 'http://linshare-ui-user.local/');

-- Functionality : DOMAIN__MAIL
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (49, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)	
	VALUES (50, false, false, 2, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (25, false, 'DOMAIN__MAIL', 49, 50, 1, 'DOMAIN', true,now(), now());
INSERT INTO functionality_string(functionality_id, string_value)
	VALUES (25, 'linshare-noreply@linagora.com');


-- Functionality : UPLOAD_REQUEST
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (63, true, true, 2, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (64, true, true, 1, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES(31, false, 'UPLOAD_REQUEST', 63, 64, 1, now(), now());
INSERT INTO functionality_string(functionality_id, string_value)
	VALUES (31, 'http://linshare-upload-request.local');

-- Functionality : UPLOAD_REQUEST__DELAY_BEFORE_ACTIVATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (65, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (66, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (67, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(32, false, 'UPLOAD_REQUEST__DELAY_BEFORE_ACTIVATION', 65, 66, 67, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO unit(id, unit_type, unit_value)
	VALUES (7, 0, 2),(17, 0, 2);
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used, unlimited_value, unlimited_value_used)
	VALUES (32, 0, 7, 17, 0, true, true, true, true);

-- Functionality : UPLOAD_REQUEST__DELAY_BEFORE_EXPIRATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (68, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (69, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (70, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(33, false, 'UPLOAD_REQUEST__DELAY_BEFORE_EXPIRATION', 68, 69, 70, 1, 'UPLOAD_REQUEST', true, now(), now());
-- time unit : month
 INSERT INTO unit(id, unit_type, unit_value)
 	VALUES (8, 0, 2),(18, 0, 2);
-- The default value 3 months - max value 4 months
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used)
	VALUES (33, 4, 8, 18, 3, true, true);

-- Functionality : UPLOAD_REQUEST__MAXIMUM_FILE_COUNT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (74, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (75, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (76, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(35, false, 'UPLOAD_REQUEST__MAXIMUM_FILE_COUNT', 74, 75, 76, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO functionality_integer(functionality_id, integer_max_value, integer_default_value, default_value_used, max_value_used)
	VALUES (35, 100, 10, true, true);

-- Functionality : UPLOAD_REQUEST__MAXIMUM_FILE_SIZE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (77, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (78, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (79, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(36, false, 'UPLOAD_REQUEST__MAXIMUM_FILE_SIZE', 77, 78, 79, 1, 'UPLOAD_REQUEST', true, now(), now());
 -- file size unit : Mega
INSERT INTO unit(id, unit_type, unit_value)
	VALUES (9, 1, 1),(19, 1, 1);
-- size : 10 Mega
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used)
	VALUES (36, 20, 9, 19, 10, true, true);

-- Functionality : UPLOAD_REQUEST__MAXIMUM_DEPOSIT_SIZE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (80, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (81, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (82, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(37, false, 'UPLOAD_REQUEST__MAXIMUM_DEPOSIT_SIZE', 80, 81, 82, 1, 'UPLOAD_REQUEST', true, now(), now());
 -- file size unit : Mega
INSERT INTO unit(id, unit_type, unit_value)
	VALUES (10, 1, 1),(20, 1, 1);
-- size : 500 Mega
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used)
	VALUES (37, 1000, 10, 20, 500, true, true);

-- Functionality : UPLOAD_REQUEST__NOTIFICATION_LANGUAGE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (83, true, true, 1, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (84, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (85, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(38, false, 'UPLOAD_REQUEST__NOTIFICATION_LANGUAGE', 83, 84, 85, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO functionality_enum_lang(functionality_id, lang_value)
	VALUES (38, 'en');

-- Functionality : UPLOAD_REQUEST__REMINDER_NOTIFICATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (328, true, true, 1, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (329, true, true, 1, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(69, false, 'UPLOAD_REQUEST__REMINDER_NOTIFICATION', 328, 329, null, 1, 'UPLOAD_REQUEST', true, now(), now());

-- Functionality : UPLOAD_REQUEST__PROTECTED_BY_PASSWORD
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (86, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (87, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (88, false, false, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(39, false, 'UPLOAD_REQUEST__PROTECTED_BY_PASSWORD', 86, 87, 88, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (39, false);

-- Functionality : UPLOAD_REQUEST__CAN_DELETE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (92, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (93, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (94, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(41, false, 'UPLOAD_REQUEST__CAN_DELETE', 92, 93, 94, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (41, true);

-- Functionality : UPLOAD_REQUEST__DELAY_BEFORE_NOTIFICATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (95, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (96, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (97, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(42, false, 'UPLOAD_REQUEST__DELAY_BEFORE_NOTIFICATION', 95, 96, 97, 1, 'UPLOAD_REQUEST', true, now(), now());
-- time unit : day
INSERT INTO unit(id, unit_type, unit_value)
	VALUES (11, 0, 0),(21, 0, 0);
-- time : default value 7 days - max value 21 days
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used)
	VALUES (42, 21, 11, 21, 7, true, true);

-- Functionality : UPLOAD_REQUEST__CAN_CLOSE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (98, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (99, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (100, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(43, false, 'UPLOAD_REQUEST__CAN_CLOSE', 98, 99, 100, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (43, true);

 -- Functionality : UPLOAD_PROPOSITION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (101, false, false, 2, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (102, true, true, 1, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES(44, false, 'UPLOAD_PROPOSITION', 101, 102, 1, now(), now());

-- Functionality : GUEST__EXPIRATION_ALLOW_PROLONGATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (123, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (124, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(51, false, 'GUESTS__EXPIRATION_ALLOW_PROLONGATION', 123, 124, null, 1, 'GUESTS', true, now(), now());

-- Functionality : UPLOAD_REQUEST_ENABLE_TEMPLATE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (129, false, false, 2, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (130, true, true, 1, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, param, creation_date, modification_date)
	VALUES(53, false, 'UPLOAD_REQUEST_ENABLE_TEMPLATE', 129, 130, 1, false, now(), now());

-- Functionality : SHARE_CREATION_ACKNOWLEDGEMENT_FOR_OWNER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (126, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (127, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (128, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, creation_date, modification_date)
	VALUES(52, false, 'SHARE_CREATION_ACKNOWLEDGEMENT_FOR_OWNER', 126, 127, 128, 1, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (52, true);

-- Functionality : UNDOWNLOADED_SHARED_DOCUMENTS_ALERT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (131, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (132, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (133, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, creation_date, modification_date)
 	VALUES(54, false, 'UNDOWNLOADED_SHARED_DOCUMENTS_ALERT', 131, 132, 133, 1, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (54, true);

-- Functionality : UNDOWNLOADED_SHARED_DOCUMENTS_ALERT__DURATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (134, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (135, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (136, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	 VALUES(55, false, 'UNDOWNLOADED_SHARED_DOCUMENTS_ALERT__DURATION', 134, 135, 136, 1, 'UNDOWNLOADED_SHARED_DOCUMENTS_ALERT', true, now(), now());
INSERT INTO functionality_integer(functionality_id, integer_max_value, integer_default_value, default_value_used, max_value_used)
	VALUES (55, 3, 3, true, false);
-- Functionality : ANONYMOUS_URL__NOTIFICATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (224, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (225, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (226, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(56, false, 'ANONYMOUS_URL__NOTIFICATION', 224, 225, 226, 1, 'ANONYMOUS_URL', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (56, true);

-- Functionality : ANONYMOUS_URL__NOTIFICATION_URL
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (228, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (229, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (230, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
 	VALUES(57, false, 'ANONYMOUS_URL__NOTIFICATION_URL', 228, 229, 230, 1, 'ANONYMOUS_URL', true, now(), now());
INSERT INTO functionality_string(functionality_id, string_value)
	VALUES (57, 'http://linshare-ui-user.local/');

-- Functionality : ANONYMOUS_URL__FORCE_ANONYMOUS_SHARING
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (279, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (280, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (281, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(58, false, 'ANONYMOUS_URL__FORCE_ANONYMOUS_SHARING', 279, 280, 281, 1, 'ANONYMOUS_URL', true, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (58, false);

-- Functionality : ANONYMOUS_URL__HIDE_RECEIVED_SHARE_MENU
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (282, false, false, 2, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (283, false, false, 2, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES(59, false, 'ANONYMOUS_URL__HIDE_RECEIVED_SHARE_MENU', 282, 283, 1, 'ANONYMOUS_URL', true, now(), now());

-- Functionality : JWT_PERMANENT_TOKEN
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (290, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (291, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, creation_date, modification_date)
	VALUES (60, false, 'JWT_PERMANENT_TOKEN', 290, 291, 1, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
    VALUES (60, true);

-- Functionality : DRIVE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (317, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (318, true, false, 0, true);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, param, creation_date, modification_date)
	VALUES (67, false, 'SHARED_SPACE', 317, 318, 1, false, now(), now());

-- Functionality : WORK_SPACE__CREATION_RIGHT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (295, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (296, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (62, false, 'WORK_SPACE__CREATION_RIGHT', 295, 296, 1, 'SHARED_SPACE', true, now(), now());

-- Functionality : SECOND_FACTOR_AUTHENTICATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (325, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (326, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (327, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, param, creation_date, modification_date)
	VALUES (68, false, 'SECOND_FACTOR_AUTHENTICATION', 325, 326, 327, 1, false, now(), now());
INSERT INTO functionality_boolean(functionality_id, boolean_value)
	VALUES (68, false);

UPDATE functionality_integer SET unlimited_value = FALSE, unlimited_value_used = FALSE;
UPDATE functionality_unit SET unlimited_value = FALSE, unlimited_value_used = FALSE;

UPDATE functionality_integer SET unlimited_value_used = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'UPLOAD_REQUEST__MAXIMUM_FILE_COUNT');
UPDATE functionality_unit SET unlimited_value_used = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'SHARE_EXPIRATION');
UPDATE functionality_unit SET unlimited_value_used = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'UPLOAD_REQUEST__MAXIMUM_DEPOSIT_SIZE');
UPDATE functionality_unit SET unlimited_value_used = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'UPLOAD_REQUEST__MAXIMUM_FILE_SIZE');
UPDATE functionality_unit SET unlimited_value_used = TRUE, unlimited_value = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'UPLOAD_REQUEST__DELAY_BEFORE_ACTIVATION');
UPDATE functionality_unit SET unlimited_value_used = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'UPLOAD_REQUEST__DELAY_BEFORE_EXPIRATION');
UPDATE functionality_unit SET unlimited_value_used = TRUE WHERE functionality_id in (SELECT id FROM functionality WHERE identifier = 'UPLOAD_REQUEST__DELAY_BEFORE_NOTIFICATION');

UPDATE functionality_unit SET integer_max_value = 900
	WHERE
		functionality_id IN (SELECT id FROM functionality WHERE identifier = 'WORK_GROUP__DOWNLOAD_ARCHIVE')
	AND
		integer_max_value = -1;
UPDATE functionality_unit SET unlimited_value = TRUE, integer_max_value = 0 WHERE integer_max_value = -1;


-- Functionality : COLLECTED_EMAILS_EXPIRATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (336, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (337, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, param, creation_date, modification_date)
	VALUES (70, false, 'COLLECTED_EMAILS_EXPIRATION', 336, 337, NULL, 1, false, now(), now());
INSERT INTO unit(id, unit_type, unit_value)
	VALUES (22, 0, 0), (23, 0, 0);
INSERT INTO functionality_unit(functionality_id, integer_max_value, unit_id, max_unit_id, integer_default_value, default_value_used, max_value_used)
	VALUES (70, 0, 22, 23, 8, true, false);

-- SHARED_SPACE__WORKSPACE_LIMIT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (347, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (348, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (71, false, 'SHARED_SPACE__WORKSPACE_LIMIT', 347, 348, 1, 'SHARED_SPACE', true, now(), now());
INSERT INTO functionality_integer(functionality_id, integer_max_value, integer_default_value, default_value_used, max_value_used, unlimited_value, unlimited_value_used)
	VALUES (71, 5, 0, false, true, false, false);

-- SHARED_SPACE__NESTED_WORKGROUPS_LIMIT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (349, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (350, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (72, false, 'SHARED_SPACE__NESTED_WORKGROUPS_LIMIT', 349, 350, 1, 'SHARED_SPACE', true, now(), now());
INSERT INTO functionality_integer(functionality_id, integer_max_value, integer_default_value, default_value_used, max_value_used, unlimited_value, unlimited_value_used)
	VALUES (72, 5, 5, false, true, false, false);

-- UPLOAD_REQUEST__LIMIT
	INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (351, false, false, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (352, true, true, 1, false);
INSERT INTO functionality(id, system, identifier, policy_activation_id, policy_configuration_id, domain_id, parent_identifier, param, creation_date, modification_date)
	VALUES (73, false, 'UPLOAD_REQUEST__LIMIT', 351, 352, 1, 'UPLOAD_REQUEST', true, now(), now());
INSERT INTO functionality_integer(functionality_id, integer_max_value, integer_default_value, default_value_used, max_value_used, unlimited_value, unlimited_value_used)
	VALUES (73, 5, 5, false, true, false, false);


-- MailActivation : FILE_WARN_OWNER_BEFORE_FILE_EXPIRY
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (137, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (138, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (139, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(1, false, 'FILE_WARN_OWNER_BEFORE_FILE_EXPIRY', 137, 138, 139, 1, true);

-- MailActivation : SHARE_NEW_SHARE_FOR_RECIPIENT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (140, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (141, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (142, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(2, false, 'SHARE_NEW_SHARE_FOR_RECIPIENT', 140, 141, 142, 1, true);

-- MailActivation : SHARE_NEW_SHARE_ACKNOWLEDGEMENT_FOR_SENDER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (143, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (144, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (145, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(3, false, 'SHARE_NEW_SHARE_ACKNOWLEDGEMENT_FOR_SENDER', 143, 144, 145, 1, true);

-- MailActivation : SHARE_FILE_DOWNLOAD_ANONYMOUS
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (146, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (147, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (148, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(4, false, 'SHARE_FILE_DOWNLOAD_ANONYMOUS', 146, 147, 148, 1, true);

-- MailActivation : SHARE_FILE_DOWNLOAD_USERS
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (149, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (150, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (151, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(5, false, 'SHARE_FILE_DOWNLOAD_USERS', 149, 150, 151, 1, true);

-- MailActivation : SHARE_FILE_SHARE_DELETED
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (152, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (153, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (154, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(6, false, 'SHARE_FILE_SHARE_DELETED', 152, 153, 154, 1, true);

-- MailActivation : SHARE_WARN_RECIPIENT_BEFORE_EXPIRY
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (155, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (156, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (157, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(7, false, 'SHARE_WARN_RECIPIENT_BEFORE_EXPIRY', 155, 156, 157, 1, true);

-- MailActivation : SHARE_WARN_UNDOWNLOADED_FILESHARES
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (158, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (159, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (160, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(8, false, 'SHARE_WARN_UNDOWNLOADED_FILESHARES', 158, 159, 160, 1, true);

-- MailActivation : GUEST_ACCOUNT_NEW_CREATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (161, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (162, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (163, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(9, false, 'GUEST_ACCOUNT_NEW_CREATION', 161, 162, 163, 1, true);

-- MailActivation : GUEST_ACCOUNT_RESET_PASSWORD_LINK
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (164, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (165, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (166, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(10, false, 'GUEST_ACCOUNT_RESET_PASSWORD_LINK', 164, 165, 166, 1, true);

-- MailActivation : UPLOAD_REQUEST_UPLOADED_FILE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (167, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (168, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (169, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(11, false, 'UPLOAD_REQUEST_UPLOADED_FILE', 167, 168, 169, 1, true);

-- MailActivation : UPLOAD_REQUEST_UNAVAILABLE_SPACE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (170, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (171, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (172, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(12, false, 'UPLOAD_REQUEST_UNAVAILABLE_SPACE', 170, 171, 172, 1, true);

-- MailActivation : UPLOAD_REQUEST_WARN_BEFORE_EXPIRY
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (173, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (174, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (175, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(13, false, 'UPLOAD_REQUEST_WARN_BEFORE_EXPIRY', 173, 174, 175, 1, true);

-- MailActivation : UPLOAD_REQUEST_WARN_EXPIRY
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (176, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (177, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (178, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(14, false, 'UPLOAD_REQUEST_WARN_EXPIRY', 176, 177, 178, 1, true);

-- MailActivation : UPLOAD_REQUEST_CLOSED_BY_RECIPIENT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (179, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (180, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (181, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(15, false, 'UPLOAD_REQUEST_CLOSED_BY_RECIPIENT', 179, 180, 181, 1, true);

-- MailActivation : UPLOAD_REQUEST_FILE_DELETED_BY_RECIPIENT
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (182, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (183, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (184, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(16, false, 'UPLOAD_REQUEST_FILE_DELETED_BY_RECIPIENT', 182, 183, 184, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (231, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (232, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (233, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(17, false, 'UPLOAD_REQUEST_ACTIVATED_FOR_RECIPIENT', 231, 232, 233, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (234, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (235, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (236, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(18, false, 'UPLOAD_REQUEST_ACTIVATED_FOR_OWNER', 234, 235, 236, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (237, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (238, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (239, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(19, false, 'UPLOAD_REQUEST_REMINDER', 237, 238, 239, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (240, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (241, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (242, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(20, false, 'UPLOAD_REQUEST_PASSWORD_RENEWAL', 240, 241, 242, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (243, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (244, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (245, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(21, false, 'UPLOAD_REQUEST_CREATED', 243, 244, 245, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (246, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (247, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (248, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(22, false, 'UPLOAD_REQUEST_CLOSED_BY_OWNER', 246, 247, 248, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (249, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (250, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (251, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(23, false, 'UPLOAD_REQUEST_RECIPIENT_REMOVED', 249, 250, 251, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (252, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (253, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (254, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(24, false, 'UPLOAD_REQUEST_UPDATED_SETTINGS', 252, 253, 254, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (255, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (256, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (257, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(25, false, 'UPLOAD_REQUEST_FILE_DELETED_BY_OWNER', 255, 256, 257, 1, true);

INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (258, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (259, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (260, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(26, false, 'GUEST_WARN_MODERATOR_ABOUT_GUEST_EXPIRATION', 258, 259, 260, 1, true);

-- MailActivation : SHARE_WARN_SENDER_ABOUT_SHARE_EXPIRATION_WITHOUT_DOWNLOAD
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (261, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (262, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (263, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 	VALUES(27, false, 'SHARE_WARN_SENDER_ABOUT_SHARE_EXPIRATION_WITHOUT_DOWNLOAD', 261, 262, 263, 1, true);

-- MailActivation : SHARE_WARN_RECIPIENT_ABOUT_EXPIRED_SHARE
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (264, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (265, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (266, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable) 
 	VALUES(28, false, 'SHARE_WARN_RECIPIENT_ABOUT_EXPIRED_SHARE', 264, 265, 266, 1, true);

-- MailActivation : WORKGROUP_WARN_NEW_MEMBER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (267, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (268, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (269, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)  
 	VALUES(29, false, 'WORKGROUP_WARN_NEW_MEMBER', 267, 268, 269, 1, true);

-- MailActivation : WORKGROUP_WARN_UPDATED_MEMBER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (270, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (271, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (272, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable) 
 	VALUES(30, false, 'WORKGROUP_WARN_UPDATED_MEMBER', 270, 271, 272, 1, true);

-- MailActivation : WORKGROUP_WARN_DELETED_MEMBER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (273, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (274, true, true, 1, false);
	INSERT INTO policy(id, status, default_status, policy, system)
VALUES (275, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable) 
 	VALUES(31, false, 'WORKGROUP_WARN_DELETED_MEMBER', 273, 274, 275, 1, true);

-- MailActivation : GUEST_WARN_GUEST_ABOUT_HIS_PASSWORD_RESET
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (276, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (277, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (278, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable) 
 	VALUES(32, false, 'GUEST_WARN_GUEST_ABOUT_HIS_PASSWORD_RESET', 276, 277, 278, 1, true);

-- MailActivation : ACCOUNT_OWNER_WARN_JWT_PERMANENT_TOKEN_CREATED
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (284, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (285, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (286, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable) 
 	VALUES(33, false, 'ACCOUNT_OWNER_WARN_JWT_PERMANENT_TOKEN_CREATED', 284, 285, 286, 1, true);
 
 	-- MailActivation : ACCOUNT_OWNER_WARN_JWT_PERMANENT_TOKEN_DELETED
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (287, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (288, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (289, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable) 
 	VALUES(34, false, 'ACCOUNT_OWNER_WARN_JWT_PERMANENT_TOKEN_DELETED', 287, 288, 289, 1, true);

	-- MailActivation : WORK_SPACE_WARN_NEW_MEMBER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (308, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (309, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (310, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(35, false, 'WORK_SPACE_WARN_NEW_MEMBER', 308, 309, 310, 1, true);

	-- MailActivation : WORK_SPACE_WARN_UPDATED_MEMBER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (311, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (312, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (313, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(36, false, 'WORK_SPACE_WARN_UPDATED_MEMBER', 311, 312, 313, 1, true);

	-- MailActivation : WORK_SPACE_WARN_DELETED_MEMBER
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (314, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (315, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (316, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(37, false, 'WORK_SPACE_WARN_DELETED_MEMBER', 314, 315, 316, 1, true);
	
-- MailActivation : GUEST_ACCOUNT_RESET_PASSWORD_FOR_4_0
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (319, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (320, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (321, false, false, 2, true);
-- --mail activation
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(38, false, 'GUEST_ACCOUNT_RESET_PASSWORD_FOR_4_0', 319, 320, 321, 1, true);

-- MailActivation : WORKGROUP_WARN_DELETED_WORKGROUP
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (330, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (331, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (332, false, false, 2, true);
-- --mail activation
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(40, false, 'WORKGROUP_WARN_DELETED_WORKGROUP', 330, 331, 332, 1, true);

	-- MailActivation : WORK_SPACE_WARN_DELETED
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (333, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (334, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (335, false, false, 2, true);
-- --mail activation
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(41, false, 'WORK_SPACE_WARN_DELETED', 333, 334, 335, 1, true);

-- MAilActivation: SHARE_ANONYMOUS_RESET_PASSWORD
-- --policies 
INSERT INTO policy
	(id, status, default_status, policy, system)
VALUES
	(322, true, true, 0, true),
	(323, true, true, 1, false),
	(324, false, false, 2, true);
-- --mail activation
INSERT INTO mail_activation
	(id, system, identifier, policy_activation_id, 
	policy_configuration_id, policy_delegation_id, domain_id, enable)
VALUES
	(39, false, 'SHARE_ANONYMOUS_RESET_PASSWORD',
	322, 323, 324, 1, true);

-- Mail activation: GUEST_MODERATOR_CREATION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (338, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (339, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (340, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(42, false, 'GUEST_MODERATOR_CREATION', 338, 339, 340, 1, true);

-- Mail activation: GUEST_MODERATOR_UPDATE
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (341, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (342, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (343, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(43, false, 'GUEST_MODERATOR_UPDATE', 341, 342, 343, 1, true);

-- Mail activation: GUEST_MODERATOR_DELETION
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (344, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (345, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (346, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(44, false, 'GUEST_MODERATOR_DELETION', 344, 345, 346, 1, true);

-- Mail activation: WORKGROUP_WARN_NEW_WORKGROUP_DOCUMENT
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (353, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (354, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (355, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
	VALUES(45, false, 'WORKGROUP_WARN_NEW_WORKGROUP_DOCUMENT', 353, 354, 355, 1, true);

-- Mail activation: WORKGROUP_WARN_WORKGROUP_DOCUMENT_UPDATED
INSERT INTO policy(id, status, default_status, policy, system) 
	VALUES (356, true, true, 0, true);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (357, true, true, 1, false);
INSERT INTO policy(id, status, default_status, policy, system)
	VALUES (358, false, false, 2, true);
INSERT INTO mail_activation(id, system, identifier, policy_activation_id, policy_configuration_id, policy_delegation_id, domain_id, enable)
 VALUES(46, false, 'WORKGROUP_WARN_WORKGROUP_DOCUMENT_UPDATED', 356, 357, 358, 1, true);
INSERT INTO mail_layout (creation_date,description,domain_abstract_id,id,layout,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,uuid,visible) VALUES (NOW(),'Default HTML layout',1,1,'','','','','',NOW(),true,'15044750-89d1-11e3-8d50-5404a683a462',true);

INSERT INTO mail_config (creation_date,domain_abstract_id,id,mail_layout_id,modification_date,name,readonly,uuid,visible) VALUES (NOW(),1,1,1,NOW(),'Default mail config',true,'946b190d-4c95-485f-bfe6-d288a2de1edd',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,1,1,'','','','',NOW(),true,'','1507e9c0-c1e1-4e0f-9efb-506f63cbba97',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,2,2,'','','','',NOW(),true,'','250e4572-7bb9-4735-84ff-6a8af93e3a42',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,3,3,'','','','',NOW(),true,'','01e0ac2e-f7ba-11e4-901b-08002722e7b1',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,4,4,'','','','',NOW(),true,'','403e5d8b-bc38-443d-8b94-bab39a4460af',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,5,5,'','','','',NOW(),true,'','554a3a2b-53b1-4ec8-9462-2d6053b80078',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,6,6,'','','','',NOW(),true,'','e7bf56c2-b015-4e64-9f07-3c7e2f3f9ca8',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,7,7,'','','','',NOW(),true,'','eb291876-53fc-419b-831b-53a480399f7c',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,8,8,'','','','',NOW(),true,'','a1ca74a5-433d-444a-8e53-8daa08fa0ddb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,9,9,'','','','',NOW(),true,'','753d57a8-4fcc-4346-ac92-f71828aca77c',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,10,10,'','','','',NOW(),true,'','5ea27e5b-9260-4ce1-b1bd-27372c5b653d',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,11,11,'','','','',NOW(),true,'','48fee30b-b2d3-4f85-b9ee-22044f9dbb4d',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,12,12,'','','','',NOW(),true,'','d43b22d6-d915-41cc-99e4-9c9db66c5aac',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,13,13,'','','','',NOW(),true,'','0cd705f3-f1f5-450d-bfcd-f2f5a60c57f8',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,14,14,'','','','',NOW(),true,'','6c0c1214-0a77-46d0-92c5-c41d225bf9aa',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,15,15,'','','','',NOW(),true,'','88b90304-e9c9-11e4-b6b4-5404a6202d2c',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),NULL,1,16,16,'','','','',NOW(),true,'','9f00708c-60e7-11e7-a8eb-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,17,17,'','','','',NOW(),true,'','9f03b0bc-60e7-11e7-a512-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,18,18,'','','','',NOW(),true,'','9f06f22c-60e7-11e7-a753-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,19,19,'','','','',NOW(),true,'','9f0a2758-60e7-11e7-b1e9-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,20,20,'','','','',NOW(),true,'','9f0d6ac6-60e7-11e7-b1b6-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,21,21,'','','','',NOW(),true,'','9f10ba3c-60e7-11e7-9a73-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,22,22,'','','','',NOW(),true,'','9f146074-60e7-11e7-94ba-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,23,23,'','','','',NOW(),true,'','9f17d614-60e7-11e7-94e3-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,24,24,'','','','',NOW(),true,'','9f1aca72-60e7-11e7-a75f-0800271467bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,25,25,'','','','',NOW(),true,'','82cd65c6-b968-11e7-aee9-eb159cedc719',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,26,26,'','','','',NOW(),true,'','4375a5b6-c3ca-11e7-bd7c-47cacbfe09d9',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,27,27,'','','','',NOW(),true,'','935a0086-c53c-11e7-83d4-3fe6e27902d8',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,28,28,'','','','',NOW(),true,'','cd33405c-c617-11e7-be9c-c763a78e452c',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,29,29,'','','','',NOW(),true,'','a4ef5ac0-c619-11e7-886b-7bf95112b643',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,30,30,'','','','',NOW(),true,'','47404f3c-c61a-11e7-bc5e-27c80414733b',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,31,31,'','','','',NOW(),true,'','d5c4e4ba-d6b5-11e7-9bac-0f07881b63bc',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,32,32,'','','','',NOW(),true,'','dbf022d8-8389-11e8-b804-d32666b16d41',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,33,33,'','','','',NOW(),true,'','dbf1b49a-8389-11e8-a006-77d9edee84a4',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,34,34,'','','','',NOW(),true,'','16a7001a-ee6d-11e8-bb18-ef4f3a73c249',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,35,35,'','','','',NOW(),true,'','01acd058-fc92-11e8-b2b3-d7189fc47d83',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,36,36,'','','','',NOW(),true,'','a9983e78-ffa9-11e8-b920-7b238822b4bb',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,37,37,'','','','',NOW(),true,'','cb30b05c-78b5-11ea-ae9c-3f0dd07b717b',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,39,39,'','','','',NOW(),true,'','b8fd5482-c47f-11eb-8529-0242ac130003',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,40,40,'','','','',NOW(),true,'','c34c8f84-c47f-11eb-8529-0242ac130003',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,41,41,'','','','',NOW(),true,'','11650cc8-b73c-11ec-a84c-235f5362c454',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,42,42,'','','','',NOW(),true,'','11679380-b73c-11ec-8bba-17ee00d3ad28',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,43,43,'','','','',NOW(),true,'','116957c4-b73c-11ec-80f2-2b24398412f7',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,44,44,'','','','',NOW(),true,'','c23bf2a6-e7f6-11ec-914a-635e67f5625b',true);

INSERT INTO mail_content (body,creation_date,description,domain_abstract_id,id,mail_content_type,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,subject,uuid,visible) VALUES ('',NOW(),'',1,45,45,'','','','',NOW(),true,'','b1404cb6-ed7a-11ec-96a5-7f908770885e',true);

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (1,0,1,1,1,true,'4f3c4723-531e-449b-a1ae-d304fd3d2387');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (2,0,1,2,2,true,'81041673-c699-4849-8be4-58eea4507305');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (3,0,1,3,3,true,'85538234-1fc1-47a2-850d-7f7b59f1640e');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (4,0,1,4,4,true,'ed70cc00-099e-4c44-8937-e8f51835000b');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (5,0,1,5,5,true,'f355793b-17d4-499c-bb2b-e3264bc13dbd');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (6,0,1,6,6,true,'5a6764fc-350c-4f10-bdb0-e95ca7607607');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (7,0,1,7,7,true,'8d707581-3920-4d82-a8ba-f7984afc54ca');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (8,0,1,8,8,true,'fd6011cf-e4cf-478d-835b-75b25e024b81');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (9,0,1,9,9,true,'7a560359-fa35-4ffd-ac1d-1d9ceef1b1e0');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (10,0,1,10,10,true,'822b3ede-daea-4b60-a8a2-2216c7d36fea');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (11,0,1,11,11,true,'9bf9d474-fd10-48da-843c-dfadebd2b455');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (12,0,1,12,12,true,'ec270da7-e9cb-11e4-b6b4-5404a6202d2c');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (13,0,1,13,13,true,'447217e4-e1ee-11e4-8a45-fb8c68777bdf');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (14,0,1,14,14,true,'bfcced12-7325-49df-bf84-65ed90ff7f59');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (15,0,1,15,15,true,'2837ac03-fb65-4007-a344-693d3fb31533');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (16,0,1,16,16,true,'9f017ae0-60e7-11e7-b430-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (17,0,1,17,17,true,'9f04eafe-60e7-11e7-813f-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (18,0,1,18,18,true,'9f07da3e-60e7-11e7-94a2-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (19,0,1,19,19,true,'9f0b1a00-60e7-11e7-bac1-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (20,0,1,20,20,true,'9f0e565c-60e7-11e7-b12b-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (21,0,1,21,21,true,'9f11f578-60e7-11e7-8f05-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (22,0,1,22,22,true,'9f15538a-60e7-11e7-9782-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (23,0,1,23,23,true,'9f18c682-60e7-11e7-a184-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (24,0,1,24,24,true,'9f1bae1a-60e7-11e7-9c81-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (25,0,1,25,25,true,'82cde226-b968-11e7-8d63-83050cc4d746');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (26,0,1,26,26,true,'4375f264-c3ca-11e7-a27a-bf234a0daed3');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (27,0,1,27,27,true,'935a40fa-c53c-11e7-8fbc-ebfc048f79f6');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (28,0,1,28,28,true,'cd339002-c617-11e7-8d48-eb704ae08d79');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (29,0,1,29,29,true,'a4ef9882-c619-11e7-94d7-239170350774');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (30,0,1,30,30,true,'47409334-c61a-11e7-bfd9-fbd9e2c973bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (31,0,1,31,31,true,'d5c520c4-d6b5-11e7-8fb4-eb93819bda25');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (32,0,1,32,32,true,'dbf0aaaa-8389-11e8-8743-9b6e3afe9f53');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (33,0,1,33,33,true,'dbf1f8ba-8389-11e8-83c9-0b5ecc4849b0');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (34,0,1,34,34,true,'16a78382-ee6d-11e8-b388-13bb3e6feb85');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (35,0,1,35,35,true,'01ad9c5e-fc92-11e8-9736-ef560a979e00');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (36,0,1,36,36,true,'a9992e32-ffa9-11e8-bbfe-b32f26c4955b');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (37,0,1,37,37,true,'bc543cdc-78c1-11ea-872b-bbec41be01d1');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (39,0,1,39,39,true,'84738a92-c47f-11eb-8529-0242ac130003');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (40,0,1,40,40,true,'92708d98-c47f-11eb-8529-0242ac130003');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (41,0,41,1,41,true,'1165b0b0-b73c-11ec-b20a-33728c1610a7');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (42,0,42,1,42,true,'1167f136-b73c-11ec-947a-7f07dff5f89a');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (43,0,43,1,43,true,'1169c600-b73c-11ec-8f48-177d8ee3ef97');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (44,0,44,1,44,true,'c23de28c-e7f6-11ec-b95c-5312dd811c59');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (45,0,45,1,45,true,'b140b322-ed7a-11ec-a4ea-9f2d5c6565a3');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (101,1,1,1,1,true,'28e5855a-c0e7-40fc-8401-9cf25eb53f03');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (102,1,1,2,2,true,'41d0f03d-57dd-420e-84b0-7908179c8329');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (103,1,1,3,3,true,'72c0fff4-4638-4e98-8223-df27f8f8ea8b');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (104,1,1,4,4,true,'6fbabf1a-58c0-49b9-859e-d24b0af38c87');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (105,1,1,5,5,true,'b85fc62f-d9eb-454b-9289-fec5eab51a76');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (106,1,1,6,6,true,'25540d2d-b3b8-46a9-811b-0549ad300fe0');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (107,1,1,7,7,true,'6580009b-36fd-472d-9937-41d0097ead91');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (108,1,1,8,8,true,'86fdc43c-5fd7-4aba-b01a-90fccbfb5489');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (109,1,1,9,9,true,'f9455b1d-3582-4998-8675-bc0a8137fc73');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (110,1,1,10,10,true,'e5a9f689-c005-47c2-958f-b68071b1bf6f');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (111,1,1,11,11,true,'2daaea2a-1b13-48b4-89a6-032f7e034a2d');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (112,1,1,12,12,true,'8f579a8a-e352-11e4-99b3-08002722e7b1');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (113,1,1,13,13,true,'fa7a23cb-f545-45b4-b9dc-c39586cb2398');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (114,1,1,14,14,true,'44bc0912-cf91-4fc0-b376-f0ebb82acd51');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (115,1,1,15,15,true,'cccb263e-1c24-4eb9-bff7-298713cc3ab7');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (116,1,1,16,16,true,'9f02736e-60e7-11e7-bf58-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (117,1,1,17,17,true,'9f05d3ec-60e7-11e7-98a3-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (118,1,1,18,18,true,'9f08b468-60e7-11e7-87e7-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (119,1,1,19,19,true,'9f0c0672-60e7-11e7-ba0a-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (120,1,1,20,20,true,'9f0f3ea0-60e7-11e7-a25e-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (121,1,1,21,21,true,'9f12e0f0-60e7-11e7-8c20-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (122,1,1,22,22,true,'9f164a06-60e7-11e7-998e-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (123,1,1,23,23,true,'9f199652-60e7-11e7-a9cf-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (124,1,1,24,24,true,'9f1c879a-60e7-11e7-95d8-0800271467bb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (125,1,1,25,25,true,'82ce572e-b968-11e7-9f2c-8b110ac99bc9');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (126,1,1,26,26,true,'4376471e-c3ca-11e7-96f0-df378884d9bd');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (127,1,1,27,27,true,'935a7b10-c53c-11e7-8ce9-17fe85e6b389');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (128,1,1,28,28,true,'cd33d42c-c617-11e7-979a-6bf962f5c6c8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (129,1,1,29,29,true,'a4efd518-c619-11e7-8cdf-13a90ce64cda');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (130,1,1,30,30,true,'4740d3f8-c61a-11e7-8d5a-3f431ce9643a');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (131,1,1,31,31,true,'d5c55f44-d6b5-11e7-b521-4f65da9d047d');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (132,1,1,32,32,true,'dbf12958-8389-11e8-964e-6b7eef81da86');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (133,1,1,33,33,true,'dbf23f1e-8389-11e8-b430-a3d498f96a4f');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (134,1,1,34,34,true,'16a7f1aa-ee6d-11e8-9dab-3b0fd56ae1eb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (135,1,1,35,35,true,'01ae8e66-fc92-11e8-9e2e-2b5cc9cf184f');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (136,1,1,36,36,true,'a99a4650-ffa9-11e8-b09e-83360a30f184');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (137,1,1,37,37,true,'fa6a42d2-78c1-11ea-aba9-174059c40540');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (139,1,1,39,39,true,'84738a92-c47f-11eb-8529-0242ac130003');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (140,1,1,40,40,true,'92708d98-c47f-11eb-8529-0242ac130003');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (141,1,41,1,41,true,'11663c88-b73c-11ec-8649-27fb71fc49cf');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (142,1,42,1,42,true,'11685018-b73c-11ec-8a49-0b3657e2f901');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (143,1,43,1,43,true,'116a1cb8-b73c-11ec-9e9e-b7c7d1b3387a');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (144,1,44,1,44,true,'c23f9d34-e7f6-11ec-bc34-73bea5d8f368');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (145,1,45,1,45,true,'b1413a36-ed7a-11ec-97e3-4fe345e8ff3e');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (201,2,1,1,1,true,'28e5855a-c0e7-40fc-8401-9cf25eb53f30');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (202,2,1,2,2,true,'41d0f03d-57dd-420e-84b0-7908179c8392');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (203,2,1,3,3,true,'72c0fff4-4638-4e98-8223-df27f8f8eab8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (204,2,1,4,4,true,'6fbabf1a-58c0-49b9-859e-d24b0af38c78');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (205,2,1,5,5,true,'b85fc62f-d9eb-454b-9289-fec5eab51a67');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (206,2,1,6,6,true,'25540d2d-b3b8-46a9-811b-0549ad300f0e');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (207,2,1,7,7,true,'6580009b-36fd-472d-9937-41d0097ead19');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (208,2,1,8,8,true,'86fdc43c-5fd7-4aba-b01a-90fccbfb5444');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (209,2,1,9,9,true,'f9455b1d-3582-4998-8675-bc0a8137fd25');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (210,2,1,10,10,true,'e5a9f689-c005-47c2-958f-b68071b1b666');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (211,2,1,11,11,true,'2daaea2a-1b13-48b4-89a6-032f7e034a3s');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (212,2,1,12,12,true,'8f579a8a-e352-11e4-99b3-08002722e5de');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (213,2,1,13,13,true,'fa7a23cb-f545-45b4-b9dc-c39586cb2ggg');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (214,2,1,14,14,true,'44bc0912-cf91-4fc0-b376-f0ebb82acmmm');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (215,2,1,15,15,true,'cccb263e-1c24-4eb9-bff7-298713cc3854');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (216,2,1,16,16,true,'9f02736e-60e7-11e7-bf58-080027146bb7');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (217,2,1,17,17,true,'9f05d3ec-60e7-11e7-98a3-080027146bb7');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (218,2,1,18,18,true,'9f08b468-60e7-11e7-87e7-080027146bb7');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (219,2,1,19,19,true,'9f0c0672-60e7-11e7-ba0a-080027146bb7');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (220,2,1,20,20,true,'9f0f3ea0-60e7-11e7-a25e-080027146rr8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (221,2,1,21,21,true,'9f12e0f0-60e7-11e7-8c20-080027146rr8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (222,2,1,22,22,true,'9f164a06-60e7-11e7-998e-080027146rr8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (223,2,1,23,23,true,'9f199652-60e7-11e7-a9cf-080027146rr8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (224,2,1,24,24,true,'9f1c879a-60e7-11e7-95d8-080027146rr8');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (225,2,1,25,25,true,'82ce572e-b968-11e7-9f2c-8b110ac9988y');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (226,2,1,26,26,true,'4376471e-c3ca-11e7-96f0-df378884dyur');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (227,2,1,27,27,true,'935a7b10-c53c-11e7-8ce9-17fe85e6bhji');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (228,2,1,28,28,true,'cd33d42c-c617-11e7-979a-6bf962f5cii9');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (229,2,1,29,29,true,'a4efd518-c619-11e7-8cdf-13a90ce64aaz');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (230,2,1,30,30,true,'4740d3f8-c61a-11e7-8d5a-3f431ce96zza');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (231,2,1,31,31,true,'d5c55f44-d6b5-11e7-b521-4f65da9d0zaz');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (232,2,1,32,32,true,'dbf12958-8389-11e8-964e-6b7eef81d99z');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (233,2,1,33,33,true,'dbf23f1e-8389-11e8-b430-a3d498f96z88');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (234,2,1,34,34,true,'250c2fe2-5f7c-11e9-8a15-bfaa0debac8a');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (235,2,1,35,35,true,'dbaef9ba-5f7b-11e9-909b-b73741598b74');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (236,2,1,36,36,true,'e6d0bb08-5f7b-11e9-a49e-bffcfe6b06bf');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (237,2,1,37,37,true,'4f5a1b10-78c1-11ea-959e-43f0d02dafd1');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (239,2,1,39,39,true,'84738a92-c47f-11eb-8529-0242ac130003');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (240,2,1,40,40,true,'92708d98-c47f-11eb-8529-0242ac130003');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (241,2,41,1,41,true,'1166d990-b73c-11ec-b337-4b09e04976cd');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (242,2,42,1,42,true,'1168ad92-b73c-11ec-b7d0-8bf4f18337f7');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (243,2,43,1,43,true,'116a9968-b73c-11ec-b40a-53616caa8660');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (244,2,44,1,44,true,'c2410228-e7f6-11ec-8243-376f41b1ce73');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (245,2,45,1,45,true,'b141949a-ed7a-11ec-af19-1bf3d47e03a3');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (301,3,1,1,1,true,'a6445e06-f603-4c40-8e94-1d58b947d7dd');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (302,3,1,2,2,true,'b4f2b727-5d96-42ed-8a05-bf02eeeb5c5c');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (303,3,1,3,3,true,'dacfe199-3be9-4aad-bfee-629d071ea8a4');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (304,3,1,4,4,true,'bc7381a9-f4f0-426e-bac5-d1bd3c1c0487');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (305,3,1,5,5,true,'d6b12524-c508-4d81-a2a2-c799919bc080');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (306,3,1,6,6,true,'b118276d-ad78-44d0-b853-0a7923826675');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (307,3,1,7,7,true,'27e4883d-9a4d-4e41-9edf-9d27237b376d');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (308,3,1,8,8,true,'d2c17e5a-7ab5-4177-bc0e-21e96475622c');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (309,3,1,9,9,true,'1e802ece-8acd-49af-ba1e-27ffe0285768');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (310,3,1,10,10,true,'6a2611b3-086f-40b9-b3a2-7c24cd3a6008');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (311,3,1,11,11,true,'d6ff215e-acbd-487a-b415-67757b8d9378');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (312,3,1,12,12,true,'31a57c1a-f208-4c2b-b15f-8303cc29cc45');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (313,3,1,13,13,true,'a01eaf4a-053e-4454-a47a-ae4fa36cdf98');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (314,3,1,14,14,true,'1a63ee64-ab36-4dc2-a5c6-936e4b78cf2b');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (315,3,1,15,15,true,'8ed4f664-e05d-450f-8436-3be617e34ed4');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (316,3,1,16,16,true,'f1c2ace7-f44d-4b3e-88d0-272c02926fdf');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (317,3,1,17,17,true,'57f09972-00e8-491a-ace2-ff6001f9ed71');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (318,3,1,18,18,true,'665c6a74-7bd2-4aa4-ad72-e4c3a3b1c125');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (319,3,1,19,19,true,'3a21dc4e-dd41-4287-a94a-8ba06aa72dd3');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (320,3,1,20,20,true,'0b53c749-9213-487b-b094-4b834d21424d');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (321,3,1,21,21,true,'df2de9fe-ab36-42f7-977b-b3e16094ae79');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (322,3,1,22,22,true,'49d411d5-f85b-4995-b687-9386bdfb6620');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (323,3,1,23,23,true,'e8a14781-83cf-4ac0-b7c5-796bed26eed6');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (324,3,1,24,24,true,'0ae957f5-05c1-4c49-9f70-785a4a6c1347');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (325,3,1,25,25,true,'88385379-7e91-4352-95a1-0961e7257368');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (326,3,1,26,26,true,'9bc9a409-f9d4-4b98-98e9-b5fabb5ff693');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (327,3,1,27,27,true,'45525ca9-7caf-421b-a312-05f53e2c7e29');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (328,3,1,28,28,true,'403f4f41-9289-4b92-ab3d-3690acd86c1a');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (329,3,1,29,29,true,'10395e20-8f41-41bf-95bf-99f7c4eeeabb');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (330,3,1,30,30,true,'d4bec4da-f2cb-4cca-9fc2-8670354dc578');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (331,3,1,31,31,true,'11fd4bcc-81db-4838-9213-1a526b2d5cd9');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (332,3,1,32,32,true,'c2b6192e-131a-4a4c-a85f-78792b1f38f3');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (333,3,1,33,33,true,'5d45f6bf-b101-4db4-9513-0b5dd9474560');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (334,3,1,34,34,true,'48ce7e17-0d97-47a1-8977-d3a42df2921e');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (335,3,1,35,35,true,'50f5f20d-0734-4f5d-80bd-1d68fea2060c');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (336,3,1,36,36,true,'015664c3-61ce-48cc-81be-9b4e413f3355');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (337,3,1,37,37,true,'64ff5e0d-8abf-423e-8869-37b7f92b2d93');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (339,3,1,39,39,true,'146b3d7c-a1d9-4873-9545-6d720d257710');

INSERT INTO mail_content_lang (id,language,mail_config_id,mail_content_id,mail_content_type,readonly,uuid) VALUES (340,3,1,40,40,true,'643faedc-b571-4a2f-94f7-85bf0bbed627');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (341,3,41,1,41,true,'41866136-666c-4278-9093-5b44cb5069d7');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (342,3,42,1,42,true,'2ca93a77-0b6e-4723-904c-0ce906c3438a');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (343,3,43,1,43,true,'70321d34-32a5-42d1-8c66-2eac4c84c5a6');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (344,3,44,1,44,true,'88af3711-9068-4c89-bb56-811fc2fd4187');

INSERT INTO mail_content_lang (id,language,mail_content_id,mail_config_id,mail_content_type,readonly,uuid) VALUES (345,3,45,1,45,true,'3667ad78-8776-40b9-b910-f9b1a69b6c06');

-- SHARE_ANONYMOUS_RESET_PASSWORD
-- -- mail content table 
INSERT INTO mail_content 
	(body,creation_date,description,domain_abstract_id,
	id, mail_content_type, messages_english, messages_french, 
	messages_russian, messages_vietnamese, modification_date, readonly,subject,
	uuid, visible)
VALUES 
	('',NOW(),'', 1, 
	38, 38,'','','',
	'', NOW(),true,'',
	'cea69b9c-7e38-11ea-ba25-7307bfa8c28e',true);
INSERT INTO mail_content_lang 
	(id,language, mail_config_id, mail_content_id, 
	mail_content_type, readonly, uuid)
VALUES
-- -- mail_content_lang table (en) 
	(38, 0, 1, 38,
	38,true,'d4a62580-7e38-11ea-a959-7b71cac4767c'),
-- -- mail_content_lang table (fr)
	(138, 1, 1, 38,
	38, true, 'df2c01dc-7e38-11ea-84b1-ef277e1a9180'),
-- -- mail_content_lang table (ru)
	(238, 2, 1, 38,
	38, true, 'cea69b9c-7e38-11ea-ba25-7307bfa8c28e'),
-- -- mail_content_lang table (vi)
	(338, 3, 1, 38,
	38, true, '760ab9cf-7ffe-497e-b2c7-0ac825963b19');

INSERT INTO mail_footer (creation_date,description,domain_abstract_id,footer,id,messages_english,messages_french,messages_russian,messages_vietnamese,modification_date,readonly,uuid,visible) VALUES (NOW(),'footer html',1,'',1,'','','','',NOW(),true,'e85f4a22-8cf2-11e3-8a7a-5404a683a462',true);

INSERT INTO mail_footer_lang (id,language,mail_config_id,mail_footer_id,readonly,uuid) VALUES (1,0,1,1,true,'bf87e580-fb25-49bb-8d63-579a31a8f81e');

INSERT INTO mail_footer_lang (id,language,mail_config_id,mail_footer_id,readonly,uuid) VALUES (2,1,1,1,true,'a6c8ee84-b5a8-4c96-b148-43301fbccdd9');

INSERT INTO mail_footer_lang (id,language,mail_config_id,mail_footer_id,readonly,uuid) VALUES (3,2,1,1,true,'a6c8ee84-b5a8-4c96-b148-43301fbccde8');

INSERT INTO mail_footer_lang (id,language,mail_config_id,mail_footer_id,readonly,uuid) VALUES (4,3,1,1,true,'44bdbb94-99c2-405a-85e8-a061410d4279');

UPDATE domain_abstract SET mailconfig_id = 1;
UPDATE mail_layout SET messages_french='common.availableUntil = Expire le
common.byYou= | Par vous
common.download= Télécharger
common.filesInShare=Fichiers joints
common.recipients = Destinataires
common.titleSharedThe= Partagé le
date.format=d MMMM, yyyy
date.formatWithHours=d MMMM, yyyy HH:mm
productCompagny=Linagora
productName=LinShare
workGroupRightAdminTitle = Administration
workGroupRightWirteTitle = Écriture
workGroupRightContributeTitle = Contribution
workGroupRightReadTitle = Lecture
workGroupRightContributorTitle = Contributeur
workSpaceRoleAdminTitle = WorkSpace: Administrateur
workSpaceRoleWriteTitle = WorkSpace: Auteur
workSpaceRoleReadTitle = WorkSpace: Lecteur
welcomeMessage = Bonjour {0},',messages_english='common.availableUntil = Expiry date
common.byYou= | By you
common.download= Download
common.filesInShare = Attached files
common.recipients = Recipients
common.titleSharedThe= Creation date
date.format= MMMM d, yyyy
date.formatWithHours= MMMM d, yyyy HH:mm
productCompagny=Linagora
productName=LinShare
workGroupRightAdminTitle = Administrator
workGroupRightWirteTitle = Writer
workGroupRightContributeTitle = Contributor
workGroupRightReadTitle = Reader
workSpaceRoleAdminTitle = WorkSpace: Administrator
workSpaceRoleWriteTitle = WorkSpace: Writer
workSpaceRoleReadTitle = WorkSpace: Reader
welcomeMessage = Hello {0},',messages_russian='common.availableUntil = Срок действия
common.byYou= | Вами
common.download= Загрузить
common.filesInShare = Прикрепленные файлы
common.recipients = Получатели
common.titleSharedThe= Дата создания
date.format= d MMMM, yyyy
date.formatWithHours= d MMMM, yyyy HH:mm
productCompagny= Linagora
productName=LinShare
workGroupRightAdminTitle = Администратор
workGroupRightWirteTitle = Автор
workGroupRightContributeTitle = Редактор
workGroupRightReadTitle = Читатель
workSpaceRoleAdminTitle = WorkSpace: Администратор
workSpaceRoleWriteTitle = WorkSpace: Автор
workSpaceRoleReadTitle = WorkSpace: Читатель
welcomeMessage = Здравствуйте {0},',messages_vietnamese='common.availableUntil = Ngày hết hạn 
common.byYou= Bởi bạn 
common.download= Tải xuống 
common.filesInShare = Tài liệu đính kèm 
common.recipients = Người nhận 
common.titleSharedThe= NGày tạo 
date.format= d MMMM, yyyy
date.formatWithHours= d MMMM, yyyy HH:mm
productCompagny= Linagora
productName=LinShare
workGroupRightAdminTitle = Quản trị viên 
workGroupRightWirteTitle = Người viết 
workGroupRightContributeTitle = Người đóng góp 
workGroupRightReadTitle = Người đọc 
workSpaceRoleAdminTitle = WorkSpace: Quản trị viên 
workSpaceRoleWriteTitle = WorkSpace: Người viết 
workSpaceRoleReadTitle = WorkSpace: Người đọc 
welcomeMessage = Xin chào {0},',layout='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">

<body>
  <!--/* Beginning of common base layout template*/-->
  <div data-th-fragment="email_base(upperMainContentArea,bottomSecondaryContentArea)">
    <div
      style="width:100%!important;margin:0;padding:0;background-color:#ffffff;font-family:''Open Sans'',arial,Helvetica,sans-serif;">
      <center>
        <table bgcolor="#ffffff" border="0" cellpadding="0" cellspacing="0" height="100% !important"
          style="height:100%!important;margin:0;padding:0;background-color:#ffffff;width:90%;max-width:450px"
          width="90%">
          <tbody>
            <tr>
              <td align="center" style="border-collapse:collapse" valign="top">
                <table border="0" cellpadding="0" cellspacing="0" style="border:0px;width:90%;max-width:500px"
                  width="90%">
                  <tbody>
                    <tr>
                      <td align="center" style="border-collapse:collapse" valign="top">
                        <table bgcolor="transparent" border="0" cellpadding="0" cellspacing="0"
                          style="background-color:transparent;border-bottom:0;padding:0px">
                          <tbody>
                            <tr>
                              <td align="center" bgcolor="#ffffff"
                                style="border-collapse:collapse;color:#202020;background-color:#ffffff;font-size:34px;font-weight:bold;line-height:100%;padding:0;text-align:center;vertical-align:middle">
                                <div align="center" style="text-align:center">
                                  <a target="_blank"
                                    style="border:0;line-height:100%;outline:none;text-decoration:none;width:233px;height:57px;padding:20px 0 20px 0"
                                    data-th-href="@{${linshareURL}}">
                                    <img src="cid:logo.linshare@linshare.org"
                                      style="display:inline-block;margin-bottom:20px;margin-top:20px" width="233"
                                      alt="Logo" height="57" />
                                  </a>
                                </div>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td align="center" style="border-collapse:collapse" valign="top">
                        <table border="0" cellpadding="0" cellspacing="0" style="width:95%;max-width:500px" width="95%">
                          <tbody>
                            <tr>
                              <td
                                style="border-collapse:collapse;border-radius:3px;font-weight:300;border:1px solid #e1e1e1;background:white;border-top:none;"
                                valign="top">
                                <table border="0" cellpadding="20" cellspacing="0" width="100%">
                                  <tbody>
                                    <tr>
                                      <td style="border-collapse:collapse;padding:0px" valign="top">
                                        <div align="left"
                                          style="color:#505050;font-size:14px;line-height:150%;text-align:left">
                                          <th:block data-th-replace="${upperMainContentArea}" />
                                        </div>
                                        <table border="0" cellspacing="0" cellpadding="0" width="100%"
                                          style="background-color: #f8f8f8;">
                                          <tbody>
                                            <tr>
                                              <td width="15"
                                                style="mso-line-height-rule: exactly; line-height: 9px; border-top:1px solid #c9cacc;">
                                                &nbsp;</td>
                                              <td width="20" style="mso-line-height-rule: exactly; line-height: 9px;">
                                                <img src="cid:logo.arrow@linshare.org" width="20" height="9" border="0"
                                                  style="display:block;" alt="down arrow" />
                                              </td>
                                              <td
                                                style="mso-line-height-rule: exactly; line-height: 9px; border-top:1px solid #c9cacc;">
                                                &nbsp;</td>
                                            </tr>
                                          </tbody>
                                        </table>
                                        <table border="0" cellspacing="0" cellpadding="0" width="100%">
                                          <tbody>
                                            <tr>
                                              <td
                                                style="font-size:14px;padding: 0px 17px;background: #f8f8f8;text-align:left;color:#7f7f7f;line-height:20px;">
                                                <div align="left"
                                                  style="font-size:13px;line-height:20px;margin:0;padding: 15px 0 20px;">
                                                  <th:block data-th-replace="${bottomSecondaryContentArea}" />
                                                </div>
                                              </td>
                                            </tr>
                                          </tbody>
                                        </table>
                                        <table width="100%"
                                          style="background:#f0f0f0;text-align:left;color:#a9a9a9;line-height:20px;border-top:1px solid #e1e1e1">
                                          <tbody>
                                            <tr data-th-insert="footer :: email_footer">
                                            </tr>
                                          </tbody>
                                        </table>
                                      </td>
                                    </tr>
                                  </tbody>
                                </table>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td align="center" style="border-collapse:collapse" valign="top">
                        <table bgcolor="white" border="0" cellpadding="10" cellspacing="0"
                          style="background-color:white;border-top:0" width="400">
                          <tbody>
                            <tr>
                              <td style="border-collapse:collapse" valign="top">
                                <table border="0" cellpadding="10" cellspacing="0" width="100%">
                                  <tbody>
                                    <tr>
                                      <td bgcolor="#ffffff" colspan="2"
                                        style="border-collapse:collapse;background-color:#ffffff;border:0;padding: 0 8px;"
                                        valign="middle">
                                        <div align="center"
                                          style="color:#707070;font-size:12px;line-height:125%;text-align:center">
                                          <!--/* Do not remove the copyright  ! */-->
                                          <div data-th-insert="copyright :: copyright">
                                            <p
                                              style="line-height:15px;font-weight:300;margin-bottom:0;color:#b2b2b2;font-size:10px;margin-top:0">
                                              You are using the Open Source and free version of
                                              <a href="http://www.linshare.org/"
                                                style="text-decoration:none;color:#b2b2b2;"><strong>LinShare</strong>™</a>,
                                              powered by <a href="http://www.linshare.org/"
                                                style="text-decoration:none;color:#b2b2b2;"><strong>Linagora</strong></a>
                                              ©&nbsp;2009–2022. Contribute to
                                              Linshare R&amp;D by subscribing to an Enterprise offer.
                                            </p>
                                          </div>
                                        </div>
                                      </td>
                                    </tr>
                                  </tbody>
                                </table>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </td>
            </tr>
          </tbody>
        </table>
      </center>
    </div>
  </div>
  <!--/* End of common base layout template*/-->
</body>

</html>
<!--/* Common lower info title style */-->
<div style="margin-bottom:17px;"
  data-th-fragment="infoItemsToUpdate(editedInfoMsg, addedInfoMsg, deletedInfoMsg, oldValue, newValue)">
  <span>
    <th:block th:if="${oldValue != null} AND ${newValue} != null">
      <th:block data-th-replace="layout :: infoEditedItem(${editedInfoMsg}, ${oldValue}, ${newValue})" />
    </th:block>
    <th:block th:if="${oldValue == null} AND ${newValue} != null">
      <th:block data-th-replace="layout :: infoAddedItem(${addedInfoMsg}, ${newValue})" />
    </th:block>
    <th:block th:if="${oldValue != null} AND ${newValue} == null">
      <th:block data-th-replace="layout :: infoDeletedItem(${deletedInfoMsg}, ${oldValue})" />
    </th:block>
  </span>
</div>

<div style="margin-bottom:17px;" data-th-fragment="infoEditedItem(titleInfo, oldValue, newValue)">
  <span style="font-weight:bold;">
    <th:block th:replace="${titleInfo}" />
  </span>
  <br />
  <span>
    <th:block th:if="${oldValue != null}">
      <th:block th:replace="${oldValue}" />
      =>
    </th:block>
    <th:block th:if="${newValue != null}">
      <th:block th:replace="${newValue}" />
    </th:block>
  </span>
</div>

<div style="margin-bottom:17px;" data-th-fragment="infoAddedItem(titleInfo, newValue)">
  <span style="font-weight:bold;">
    <th:block th:replace="${titleInfo}" />
  </span>
  <br />
  <span>
    <th:block th:replace="${newValue}" />
  </span>
</div>

<div style="margin-bottom:17px;" data-th-fragment="infoDeletedItem(titleInfo, oldValue)">
  <span style="font-weight:bold;">
    <th:block th:replace="${titleInfo}" />
  </span>
  <br />
  <span>
    <th:block th:replace="${oldValue}" />
  </span>
</div>

<!--/* Edited  date  display settings  style */-->
<div style="margin-bottom:17px;"
  data-th-fragment="infoDateItemsToUpdate(editedInfoMsg, addedInfoMsg, deletedInfoMsg, oldValue, newValue)">
  <span>
    <th:block th:if="${oldValue != null} AND ${newValue} != null">
      <th:block data-th-replace="layout :: infoEditedDateItem(${editedInfoMsg}, ${oldValue}, ${newValue})" />
    </th:block>
    <th:block th:if="${oldValue == null} AND ${newValue} != null">
      <th:block data-th-replace="layout :: infoAddedDateItem(${addedInfoMsg}, ${newValue})" />
    </th:block>
    <th:block th:if="${oldValue != null} AND ${newValue} == null">
      <th:block data-th-replace="layout :: infoDeletedDateItem(${deletedInfoMsg}, ${oldValue})" />
    </th:block>
  </span>
</div>

<div style="margin-bottom:17px;" data-th-fragment="infoEditedDateItem(titleInfo, oldValue, newValue)">
  <span style="font-weight:bold;">
    <th:block th:replace="${titleInfo}" />
  </span>
  <br />
  <span>
    <th:block th:if="${oldValue != null}">
      <th:block th:with="df=#{date.format}" data-th-text="${#dates.format(oldValue, df)}" />
      =>
    </th:block>
    <th:block th:if="${newValue != null}">
      <th:block th:with="df=#{date.format}" data-th-text="${#dates.format(newValue, df)}" />
    </th:block>
  </span>
</div>

<div style="margin-bottom:17px;" data-th-fragment="infoAddedDateItem(titleInfo, newValue)">
  <span style="font-weight:bold;">
    <th:block th:replace="${titleInfo}" />
  </span>
  <br />
  <span>
    <th:block th:with="df=#{date.format}" data-th-text="${#dates.format(newValue, df)}" />
  </span>
</div>

<div style="margin-bottom:17px;" data-th-fragment="infoDeletedDateItem(titleInfo, oldValue)">
  <span style="font-weight:bold;">
    <th:block th:replace="${titleInfo}" />
  </span>
  <br />
  <span>
    <th:block th:with="df=#{date.format}" data-th-text="${#dates.format(oldValue, df)}" />
  </span>
</div>

<!--/* Common header template */-->

<head data-th-fragment="header">
  <title data-th-text="${mailSubject}">Mail subject</title>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head>

<!--/* Common greeting  template */-->
<div data-th-fragment="greetings(currentFirstName)">
  <p style="color:#505050;margin-top:0;font-weight:300;margin-bottom:10px"
    data-th-text="#{welcomeMessage(${currentFirstName})}">
    Hello Amy,</p>
</div>

<!--/* Common upper email section  template */-->
<div data-th-fragment="contentUpperSection(sectionContent)" style="margin-bottom:17px;border-top: 1px solid #e1e1e1;">
  <div align="left" style="padding:24px 17px 5px;line-height: 21px;margin:0px;text-align:left;font-size: 13px;
border-top: 1px solid #e1e1e1;">
    <th:block th:replace="${sectionContent}" />
  </div>
</div>

<!--/* Common message section template */-->
<div data-th-fragment="contentMessageSection(messageTitle,messageContent)"
  style="margin-bottom:17px;border-top: 1px solid #e1e1e1;">
  <div align="left" style="padding:24px 17px 15px;line-height: 21px;margin:0px;text-align:left;font-size: 13px;">
    <p style="color:#505050;margin-top:0;font-weight:300;margin-bottom:10px">
      <th:block th:replace="${messageTitle}" />
    </p>
    <p style="margin:0;color: #88a3b1;">
      <th:block th:replace="${messageContent}" />
    </p>
  </div>
</div>

<!--/* Common link style */-->
<div data-th-fragment="infoActionLink(titleInfo,urlLink)" style="margin-bottom:17px;">
  <span style="font-weight:bold;" data-th-text="${titleInfo}">Download link title </span>
  <br />
  <a target="_blank" style="color:#1294dc;text-decoration:none;" data-th-text="${urlLink}" th:href="@{${urlLink}}">Link
  </a>
</div>

<!--/* Common date display  style */-->
<div style="margin-bottom:17px;" data-th-fragment="infoDateArea(titleInfo,contentInfo)">
  <div data-th-if="${contentInfo != null}">
    <span style="font-weight:bold;" data-th-text="${titleInfo}">Shared the </span>
    <br />
    <span th:with="df=#{date.format}" data-th-text="${#dates.format(contentInfo,df)}">7th of November, 2018</span>
  </div>
</div>

<!--/* Common date with hours display style */-->
<div style="margin-bottom:17px;" data-th-fragment="infoDateAreaWithHours(titleInfo,contentInfo)">
  <div data-th-if="${contentInfo != null}">
    <span style="font-weight:bold;" data-th-text="${titleInfo}">Shared the </span>
    <br />
   <span th:with="dfwh=#{date.formatWithHours}" data-th-text="${#dates.format(contentInfo,dfwh)}">7th of November, 2018 at 10:30</span>
  </div>
</div>

<!--/* Common lower info title style */-->
<div style="margin-bottom:17px;" data-th-fragment="infoStandardArea(titleInfo,contentInfo)">
  <div data-th-if="${contentInfo != null}">
    <span style="font-weight:bold;">
      <th:block th:replace="${titleInfo}" />
    </span>
    <br />
    <th:block th:replace="${contentInfo}" />
  </div>
</div>

<!--/* Common button action style */-->
<span data-th-fragment="actionButtonLink(labelBtn,urlLink)">
  <a style="border-radius:3px;font-size:15px;color:white;text-decoration:none;padding: 10px 7px;width:auto;max-width:50%;display:block;background-color: #42abe0;text-align: center;margin-top: 17px;"
    target="_blank" data-th-text="${labelBtn}" th:href="@{${urlLink}}">Button label</a>
</span>

<!--/* Common recipient listing for external and internal users */-->
<div style="margin-bottom:17px;" data-th-fragment="infoRecipientListingArea(titleInfo,arrayRecipients)">
  <span style="font-weight:bold;" data-th-text="${titleInfo}">Recipients</span>
  <table>
    <th:block th:each="recipientData: ${arrayRecipients}">
      <tr>
        <td style="color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
        <td>
          <div data-th-if="(${#strings.isEmpty(recipientData.lastName)})">
            <span style="color:#787878;font-size:13px" data-th-utext="${recipientData.mail}">
              my-file-name.pdf
            </span>
          </div>
          <div data-th-if="(${!#strings.isEmpty(recipientData.lastName)})">
            <span style="color:#787878;font-size:13px">
              <th:block data-th-utext="${recipientData.firstName}" />
              <th:block data-th-utext="${recipientData.lastName}" />
            </span>
          </div>
        </td>
      </tr>
    </th:block>
  </table>
</div>
<div data-th-if="(${!isAnonymous})">
  <a target="_blank" style="color:#1294dc;text-decoration:none;font-size:13px" th:href="@{${shareLink.href}}"
    data-th-utext="${shareLink.name}">
    my-file-name.pdf
  </a>
</div>
</div>

<!--/* Lists all file links in a share   */-->
<div style="margin-bottom:17px;" data-th-fragment="infoFileLinksListingArea(titleInfo,arrayFileLinks,isAnonymous)">
  <span style="font-weight:bold;" data-th-text="${titleInfo}">Shared the </span>

  <table>
    <th:block th:each="shareLink : ${arrayFileLinks}">
      <tr>
        <td style="color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
        <td>
          <div data-th-if="(${!isAnonymous})">
            <a style="color:#1294dc;text-decoration:none;font-size:13px" data-th-utext="${shareLink.name}"
              th:href="@{${shareLink.href}}">
              my-file-name.pdf
            </a>
          </div>
          <div data-th-if="(${isAnonymous})">
            <a style="color:#787878;text-decoration:none;font-size:13px" data-th-utext="${shareLink.name}">
              my-file-name.pdf
            </a>
          </div>
        </td>
      </tr>
    </th:block>
  </table>
</div>
<!--/* Lists all file links in a share  and checks witch one are the recpient\s */-->
<div style="margin-bottom:17px;" data-th-fragment="infoFileListWithMyUploadRefs(titleInfo,arrayFileLinks)">
  <span style="font-weight:bold;" data-th-text="${titleInfo}">Shared the </span>

  <table>
    <th:block th:each="shareLink : ${arrayFileLinks}">
      <tr>
        <td style="color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
        <td>
          <a style="color:#787878;text-decoration:none;font-size:13px" data-th-utext="${shareLink.name}">
            my-file-name.pdf
          </a>
          <th:block data-th-if="(${shareLink.mine})"> <span data-th-text="#{common.byYou}">| By You</span></th:block>
        </td>
      </tr>
    </th:block>
  </table>
</div>

<!--/* Lists all file links in a share along with their download status   */-->
<div data-th-fragment="infoFileListUploadState(titleInfo,arrayFileLinks)">
  <span style="font-weight:bold;" data-th-text="${titleInfo}">Shared the </span>

  <table>
    <th:block th:each="shareLink : ${arrayFileLinks}" data-th-if="(${shareLink.downloaded})">
      <tr>
        <td style="color:#00b800;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
        <td>
          <th:block data-th-if="(${shareLink.isDownloading})">
            <a style="color:#1294dc;text-decoration:none;font-size:13px ;font-weight:bold"
              data-th-utext="${shareLink.name}">
              my-file-name.pdf
            </a>
          </th:block>
          <th:block data-th-if="(${!shareLink.isDownloading})">
            <a style="color:#1294dc;text-decoration:none;font-size:13px" data-th-utext="${shareLink.name}">
              my-file-name.pdf
            </a>
          </th:block>
        </td>
      </tr>
    </th:block>

    <th:block th:each="shareLink : ${arrayFileLinks}" data-th-if="(${!shareLink.downloaded})">
      <tr>
        <td style=" color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
      <td>
        <a style="color:#1294dc;text-decoration:none;font-size:13px" data-th-utext="${shareLink.name}">
          my-file-name.pdf
        </a>
      </td>
      </tr>
    </th:block>
  </table>
</div>
<!--/* Lists all recpients download states per file   */-->
<div style="margin-bottom:17px;" data-th-fragment="infoFileListRecipientUpload(titleInfo,arrayFileLinks)">
  <span style="font-weight:bold;" data-th-text="${titleInfo}">Shared the </span>
  <th:block style="color: #787878; font-size:10px;margin-top:10px; display: inline-block;"
    th:each="shareLink : ${arrayFileLinks}">
    <div style="border-bottom: 1px solid #e3e3e3;display: inline-block;width: 100%;margin-bottom: 3px;">
      <!--[if mso]>
					&nbsp;&nbsp;
				<![endif]-->
      <a target="_blank" style="color:#1294dc;text-decoration:none;font-size:13px" th:href="@{${shareLink.href}}">
        <span align="left" style="display: inline-block; width: 96%;"
          data-th-utext="${shareLink.name}">test-file.jpg</span>
      </a>
      <span data-th-if="(${!shareLink.allDownloaded})" style="color: #787878; font-size: 22px;">&bull;</span>
      <span data-th-if="(${shareLink.allDownloaded})" style="color: #00b800; font-size: 22px;">&bull;</span>
    </div>
    <table>
      <th:block th:each="recipientData: ${shareLink.shares}">
        <th:block data-th-if="(${!recipientData.downloaded})">
          <tr>
            <td style="color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>

            <th:block data-th-if="(${!#strings.isEmpty(recipientData.lastName)})">
              <td>
                <span style="color:#7f7f7f;font-size:13px;">
                  <th:block data-th-utext="${recipientData.firstName}" />
                  <th:block data-th-utext="${recipientData.lastName}" />
                </span>
              </td>
            </th:block>
            <th:block data-th-if="(${#strings.isEmpty(recipientData.lastName)})">
              <td>
                <span style="color:#7f7f7f;font-size:13px;"
                  data-th-utext="${recipientData.mail}">able.cornell@linshare.com </span>
              </td>
            </th:block>
          </tr>
        </th:block>

        <th:block data-th-if="(${recipientData.downloaded})">
          <tr>
            <td style="color:#00b800;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>

            <th:block data-th-if="(${!#strings.isEmpty(recipientData.lastName)})">
              <td>
                <span style="color:#7f7f7f;font-size:13px;">
                  <th:block data-th-utext="${recipientData.firstName}" />
                  <th:block data-th-utext="${recipientData.lastName}" />
                </span>
              </td>
            </th:block>
            <th:block data-th-if="(${#strings.isEmpty(recipientData.lastName)})">
              <td>
                <span style="color:#7f7f7f;font-size:13px;"
                  data-th-utext="${recipientData.mail}">able.cornell@linshare.com </span>
              </td>
            </th:block>
          </tr>
        </th:block>
      </th:block>
    </table>
  </th:block>
</div>' WHERE id=1;
UPDATE mail_content SET subject='[(#{subject})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${recipient.firstName})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                      <span th:if="(${owner.firstName} !=null AND ${owner.lastName} !=null)
                       AND (${owner.firstName} != ${recipient.firstName} AND ${recipient.lastName} != ${owner.lastName})"
                                      data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName},${label})}">
                      </span>
                       <span th:if="(${owner.firstName} !=null AND ${owner.lastName} !=null)
                       AND (${owner.firstName} == ${recipient.firstName} AND ${recipient.lastName} == ${owner.lastName})"
                                      data-th-utext="#{mainMsgOwner(${owner.firstName},${owner.lastName},${label})}">
                      </span>
                  </p>
                      <span data-th-utext="#{endMsg}"></span>
                      <span>
                             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="#{tokenLinkEndOfLine(${jwtTokenLink})}" th:href="@{${jwtTokenLink}}" >
                            </a>
                     </span>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
           <th:block data-th-replace="layout :: infoStandardArea(#{tokenLabel},${label})"/>
           <th:block data-th-replace="layout :: infoDateArea(#{tokenCreationDate},${creationDate})"/>
           <div data-th-if="${!#strings.isEmpty(description)}">
             <th:block data-th-replace="layout :: infoStandardArea(#{tokenDescription},${description})"/>
           </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='subject = Création d''''un jeton d''''accès permanent
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> a créé un jeton d''''accès permanent: {2}, pour votre compte.
mainMsgOwner = Vous vous avez créé un jeton d''''accès permanent : {2},pour votre compte.
tokenCreationDate = Date de création
endMsg = Vous pouvez consulter les jetons d''''accès liés à votre compte
tokenLinkEndOfLine = ici
tokenLabel = Nom
tokenDescription = Description',messages_english='subject = Creation of a permanent authentication token
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> has created a permanent authentication token: {2}, for your account.
mainMsgOwner = You have created a permanent authentication token: {2}, for your account.
tokenCreationDate = Creation date
endMsg = You can review the active tokens tied to your account
tokenLinkEndOfLine = here
tokenLabel = Name
tokenDescription = Description',messages_russian='subject = Создание постоянного токена аутентификации
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> создал постоянный токен аутентификации: {2},для вашей учетной записи.
mainMsgOwner = Вы создали постоянный токен аутентификации: {2}, для своего аккаунта.
tokenCreationDate = Дата создания
endMsg = Вы можете просмотреть все активные токены вашего аккаунта
tokenLinkEndOfLine = здесь
tokenLabel = Имя
tokenDescription = Описание' ,messages_vietnamese='subject = Tạo một mã xác thực vĩnh viễn. 
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã tạo một mã xác thực vĩnh viễn: {2}, cho tài khoản của bạn.
mainMsgOwner = Bạn đã tạo một mã xác thực vĩnh viễn: {2}, cho tài khoản của bạn.
tokenCreationDate = Ngày tạo 
endMsg = Bạn có thể xem lại và kích hoạt các mã xác thực của tài khoản của bạn 
tokenLinkEndOfLine = ở đây 
tokenLabel = Tên 
tokenDescription = Mô tả' WHERE id=32;
UPDATE mail_content SET subject='[(#{subject})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${recipient.firstName})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                      <span th:if="(${owner.firstName} !=null AND ${owner.lastName} !=null)
                       AND (${owner.firstName} != ${recipient.firstName} AND ${recipient.lastName} != ${owner.lastName})"
                                      data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName},${label})}">
                      </span>
                       <span th:if="(${owner.firstName} !=null AND ${owner.lastName} !=null)
                       AND (${owner.firstName} == ${recipient.firstName} AND ${recipient.lastName} == ${owner.lastName})"
                                      data-th-utext="#{mainMsgOwner(${owner.firstName},${owner.lastName},${label})}">
                      </span>
                     </span>
                  </p>
                      <span data-th-utext="#{endMsg}"></span>
                      <span>
                             <a target="_blank" style="color:#1294dc;text-decoration:none;" data-th-text="#{tokenLinkEndOfLine(${jwtTokenLink})}" th:href="@{${jwtTokenLink}}" >
                            </a>
                     </span>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
           <th:block data-th-replace="layout :: infoStandardArea(#{tokenLabel},${label})"/>
           <th:block data-th-replace="layout :: infoDateArea(#{tokenCreationDate},${creationDate})"/>
           <div data-th-if="${!#strings.isEmpty(description)}">
             <th:block data-th-replace="layout :: infoStandardArea(#{tokenDescription},${description})"/>
           </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='subject = Suppression d''''un jeton d''''accès permanent
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> a supprimé un jeton d''''accès permanent: {2}, pour votre compte.
mainMsgOwner = Vous avez supprimé un jeton d''''accès permanent: {2}, pour votre compte.
tokenCreationDate = Date de création
endMsg = Vous pouvez consulter les jetons d''''accès liés à votre compte
tokenLinkEndOfLine = ici
tokenLabel = Nom
tokenDescription = Description
tokenIdentifier = Identifiant',messages_english='subject = Deletion of a permanent authentication token
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> has deleted a permanent authentication token: {2}, for your account.
mainMsgOwner = You have deleted a permanent authentication token: {2}, for your account.
tokenCreationDate = Creation date
endMsg = You can review the active tokens tied to your account
tokenLinkEndOfLine = here
tokenLabel = Name
tokenDescription = Description',messages_russian='subject = Удаление постоянного токена аутентификации
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> удалил постоянный токен аутентификации: {2}, для вашего аккаунта.
mainMsgOwner = Вы удалили постоянный токен аутентификации: {2}, для вашего аккаунта.
tokenCreationDate = Дата создания
endMsg = Вы можете просмотреть все активные токены вашего аккаунта
tokenLinkEndOfLine = здесь
tokenLabel = Имя
tokenDescription = Описание',messages_vietnamese='subject = Xóa mã xác thực vĩnh viễn.
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã xóa mã xác thực vĩnh viễn: {2}, cho tài khoản của bạn.
mainMsgOwner = Bạn đã xóa mã xác thực vĩnh viễn: {2}, cho tài khoản của bạn.
tokenCreationDate = Ngày tạo
endMsg = Bạn có thể xem và kích hoạt các mã của tài khoản của bạn
tokenLinkEndOfLine = tại đây 
tokenLabel = Tên
tokenDescription = Mô tả' WHERE id=33;
UPDATE mail_content SET subject='[( #{subject(${document.name})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
  <head  data-th-replace="layout :: header"></head>
  <body>
    <div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
    <section id="main-content">
      <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
        <div id="section-content">
          <!--/* Greetings */-->
            <th:block data-th-replace="layout :: greetings(${owner.firstName})"/>
          <!--/* End of Greetings */-->
          <!--/* Main email  message content*/-->
          <p>
     <span  data-th-utext="#{beginningMainMsgInt}"></span>
            <span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${document.name}" th:href="@{${document.href}}" >
                  filename.ext
              </a>
          </span>
  <span  data-th-utext="#{endingMainMsgInt(${daysLeft})}">  </span>
           <!--/* Single download link for external recipient */-->
            <th:block   data-th-replace="layout :: actionButtonLink(#{common.download},${document.href})"/>
          </p> <!--/* End of Main email  message content*/-->
        </div><!--/* End of section-content*/-->
      </div><!--/* End of main-content container*/-->
    </section> <!--/* End of main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
      <th:block data-th-replace="layout :: infoDateArea(#{uploadedThe},${document.creationDate})"/>
      <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${document.expirationDate})"/>
    </section>  <!--/* End of Secondary content for bottom email section */-->
  </body>
</html>',messages_french='beginningMainMsgInt =  Votre fichier
endingMainMsgInt = sera automatiquement supprimé dans <b> {0} jours</b> de votre Espace Personnel.
subject = Le fichier {0} va bientôt être supprimé
uploadedThe = Déposé le',messages_english='beginningMainMsgInt = Your file
endingMainMsgInt = will automatically be deleted in <b> {0} days</b> from your Personal Space.
subject = The file {0} is about to be deleted
uploadedThe = Upload date',messages_russian='beginningMainMsgInt = Ваш файл
endingMainMsgInt = будет автоматически удален через <b> {0} дней</b> из вашего личного пространства.
subject = Файл {0} будет удален
uploadedThe = Дата загрузки',messages_vietnamese='beginningMainMsgInt = Tài liệu của bạn
endingMainMsgInt = sẽ tự động bị xóa trong <b> {0} ngày </b> từ Không gian cá nhân của bạn. 
subject = File {0} sắp bị xóa. 
uploadedThe = Ngày tải lên' WHERE id=1;
UPDATE mail_content SET subject='[( #{subject(${creator.firstName},${creator.lastName}, #{productName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${guest.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(${creator.firstName},${creator.lastName},#{productName})}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
          <th:block  data-th-replace="layout :: actionButtonLink(#{accessToLinshareBTn},${resetLink})"/>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoStandardArea(#{userNameTitle},${guest.mail})"/>
    <th:block data-th-replace="layout :: infoActionLink(#{activationLinkTitle},${resetLink})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{accountExpiryDateTitle},${guestExpirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accessToLinshareBTn = Activer mon compte
accountExpiryDateTitle = Date d''''''expiration
activationLinkTitle = Lien d''''initialisation
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> vous a créé un compte invité sur <b>LinShare</b> qui vous permet de partager des fichiers de façon sécurisée. <br/> Pour vous connecter, vous devez finaliser votre inscription en créant votre mot de passe à l''''aide du lien  ci-dessous.
subject = {0}  {1} vous invite a activer votre compte
userNameTitle = Identifiant',messages_english='accessToLinshareBTn = Activate account
accountExpiryDateTitle = Account expiry date
activationLinkTitle = Initialization link
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> has created a <b>{2}</b> guest account for you, which enables you to transfer files more securely. <br/>To log into your account, you will need to finalize your subscription by creating your password, using the following link.
subject = {0}  {1} invited you to activate your {2} account
userNameTitle = Username',messages_russian='accessToLinshareBTn = Активировать аккаунт
accountExpiryDateTitle = Срок действия аккаунта
activationLinkTitle = Ссылка активации
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> создал гостевой аккаунт <b>{2}</b>  для вас, который позволяет надежно обмениваться файлами. <br/>Для входа в ваш аккаунт, завершите процесс регистрации, используя ссылку
subject = {0}  {1} пригласил вас активировать ваш {2} аккаунт
userNameTitle = Имя пользователя',messages_vietnamese='accessToLinshareBTn = Kích hoạt tài khoản
accountExpiryDateTitle = Ngày hết hạn tài khoản 
activationLinkTitle = Đường dẫn
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã tạo một <b>{2}</b> tài khoản khách cho bạn, điều này cho phép bạn trao đổi tài liệu bảo mật hơn. <br/> Để đăng nhập tài khoản của bạn, bạn cần phải tạo mật khẩu bằng đường dẫn dưới đây. 
subject = {0}  {1} đã mời bạn kích hoạt {2} tài khoản
userNameTitle = Tên đăng nhập' WHERE id=8;
UPDATE mail_content SET subject= '[( #{subject})]',
body= '<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${guest.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p data-th-utext="#{mainTitle}"><p>
          <br/>
        <span data-th-utext="#{additionalMsg}"></span>
        <br/>
          <b>NB:</b> <span data-th-utext="#{noteMsg}"></span>
        </p><br/>
          <!--/* Activation link for initialisation of the guest account */-->
          <th:block data-th-replace="layout :: actionButtonLink(#{changePasswordBtn},${resetLink})"/>
        <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoStandardArea(#{userNameTitle},${guest.mail})"/>
    <th:block data-th-replace="layout :: infoActionLink(#{resetLinkTitle},${resetLink})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{urlExpiryDateTitle},${urlExpirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',
messages_french= 'urlExpiryDateTitle = Date d''''expiration de l''''URL
additionalMsg = Vous pouvez également, utiliser le formulaire de mot de passe perdu pour accomplir cette tache.
noteMsg = Ce lien est utilisable une seule fois et sera valide pendant 1 semaine.
changePasswordBtn = Réinitialiser
mainTitle = Afin de renforcer la sécurité de votre compte, vous devez changer le mot de passe de votre compte LinShare. Toute connexion sera impossible tant que cette étape ne sera pas réalisée.
resetLinkTitle = Lien de réinitialisation
subject =  Mise à jour de sécurité
userNameTitle = Identifiant',
messages_english= 'urlExpiryDateTitle = URL expiry date
additionalMsg = You can also use the reset password form to do this task.
noteMsg = This link can be used only once and will be valid for 1 week. 
changePasswordBtn = Change password
mainTitle = In order to enhance the security of your account, you must change your password to your LinShare account. Any connection will be forbidden until this step is not carried out.
resetLinkTitle = LinShare reset password link
subject =  Security update
userNameTitle = Username',
messages_russian= 'urlExpiryDateTitle = Истечение срока действия URL
additionalMsg = Вы также можете использовать форму сброса пароля для выполнения этой задачи.
noteMsg = Эта ссылка может быть использована только один раз и будет действительна в течение 1 недели.
changePasswordBtn = Изменить пароль
mainTitle = Чтобы повысить уровень безопасности, вы должны изменить пароль своей учетной записи LinShare. Любое соединение будет запрещено до тех пор, пока этот шаг не будет выполнен.
resetLinkTitle = Ссылка для сброса пароля LinShare
subject =  Обновление безопасности
userNameTitle = Имя пользователя',
messages_vietnamese= 'urlExpiryDateTitle = URL ngày hết hạn 
additionalMsg = Bạn cũng có thể dùng form đổi mật khẩu để thực hiện việc này. 
noteMsg = Đường dẫn này chỉ được dùng một ngày và có giá trị trong 1 tuần. 
changePasswordBtn = Đổi mật khẩu 
mainTitle = Để nâng cao bảo bật cho tài khoản LinShare của bạn, bạn cần phải đổi mật khẩu tài khoản. Bất cứ kết nối nào cũng sẽ bị chặn cho đến khi bạn hoàn thành bước này. 
resetLinkTitle = Đường dẫn đổi mật khẩu LinShare. 
subject =  Cập nhật bảo mật 
userNameTitle = Tên người dùng '
WHERE id= 37;
UPDATE mail_content SET subject='[( #{subject})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${guest.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p style="font-weight:bold;font-size:15px;"  data-th-utext="#{mainTile}">Did you forget your password ?</p>
        <p>
          <span data-th-utext="#{beginingMainMsg}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
          <th:block data-th-replace="layout :: actionButtonLink(#{changePasswordBtn},${resetLink})"/>
          <br/>
        </p>
        <p  data-th-utext="#{endingMainMsg}"></p>
        <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoStandardArea(#{userNameTitle},${guest.mail})"/>
    <th:block data-th-replace="layout :: infoActionLink(#{resetLinkTitle},${resetLink})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{accountExpiryDateTitle},${guestExpirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accountExpiryDateTitle = Date d''''expiration
beginingMainMsg =  Suivez le lien ci-dessous afin de réinitialiser le mot de passe de votre compte LinShare.
changePasswordBtn = Réinitialiser
endingMainMsg = Si vous n''''avez pas sollicité ce changement de mot de passe, merci d''''ignorer cet email. Votre mot de passe ne sera pas mis à jour tant que vous n''''en créé pas un nouveau, via le lien ci-dessus.
mainTile = Vous avez oublié votre mot de Passe ?
resetLinkTitle = Lien de réinitialisation
subject =  LinShare instruction de réinitialisation de mot de passe
userNameTitle = Identifiant',messages_english='accountExpiryDateTitle = Account expiry date
beginingMainMsg =  Follow the link below to reset your LinShare password account.
changePasswordBtn = Change password
endingMainMsg = If you did not request a password reset, please ignore this email. Your password will not change until you create a new one via the link above.
mainTile = Did you forget your password ?
resetLinkTitle = LinShare reset password link
subject =  LinShare reset password instructions
userNameTitle = Username',messages_russian='accountExpiryDateTitle = Дата окончания действия аккаунта
beginingMainMsg =  Используйте ссылку ниже для смены пароля к вашему аккаунту LinShare.
changePasswordBtn = Изменить пароль
endingMainMsg = Если вы не запрашивали смену пароля, пожалуйста, проигнорируйте это письмо. Ваш пароль не будет изменен пока вы не создадите новый, перейдя по ссылке.
mainTile = Забыли пароль?
resetLinkTitle = Ссылка на смену пароля LinShare
subject =  Инструкция по смену пароля LinShare
userNameTitle = Имя пользователя' ,messages_vietnamese='accountExpiryDateTitle = Ngày hết hạn tài khoản
beginingMainMsg =  Bấm vào link dưới đây để đặt lại mật khẩu cho tài khoản LinShare của bạn.
changePasswordBtn = Đổi mật khẩu
endingMainMsg = Nếu bạn không yêu cầu đổi mật khẩu, hãy bỏ qua thư này. Mật khẩu của bạn sẽ không được đổi trừ khi bạn tạo một mật khẩu mới thông qua đường dẫn trên.
mainTile = Bạn quên mật khẩu? 
resetLinkTitle = Đường dẫn đổi mật khẩu 
subject =  Hướng dẫn đổi mật khẩu LinShare 
userNameTitle = Tên người dùng' WHERE id=9;
UPDATE mail_content SET subject='[( #{subject(${actor.firstName},${actor.lastName}, #{productName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${account.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(${actor.firstName},${actor.lastName},${guest.firstName},${guest.lastName},${role})}"></span>
          <!--/* Access button to guest account */-->
          <th:block  data-th-replace="layout :: actionButtonLink(#{accessToLinshareBTn},${guestLink})"/>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
        <th:block data-th-replace="layout :: infoStandardArea(#{guestNameTitle},${guest.mail})"/>
    </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accessToLinshareBTn = Accéder
subject = {0} {1} vous a ajouté comme modérateur d''''invité
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> vous a ajouté comme modérateur de <b>{2}</b> <b>{3}</b> avec <b>{4}</b> role.
guestNameTitle = Invité',
messages_english='accessToLinshareBTn = Access
subject = {0} {1} added you as guest moderator
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> added you as a guest moderator for <b>{2}</b> <b>{3}</b> with <b>{4}</b> role.
guestNameTitle = Guest',
messages_russian='accessToLinshareBTn = Доступ
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> добавил вас в качестве приглашенного модератора в <b>{2}</b> <b>{3}</b> с ролью <b>{4}</b>.
subject = {0} {1} добавил вас в качестве приглашенного модератора
guestNameTitle = Гость',
messages_vietnamese='accessToLinshareBTn = Truy cập 
subject = {0} {1} đã thêm bạn làm người giám sát tài khoản khách
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã thêm bạn làm quản trị viên của khách <b>{2}</b> <b>{3}</b> với <b>{4}</b> quyền.
guestNameTitle = Khách' WHERE id=41;
UPDATE mail_content SET subject='[( #{subject(${actor.firstName},${actor.lastName}, #{productName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${account.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(${actor.firstName},${actor.lastName},${guest.firstName},${guest.lastName})}"></span>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
        <th:block data-th-replace="layout :: infoStandardArea(#{guestNameTitle},${guest.mail})"/>
    </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accessToLinshareBTn = Accéder
subject = {0} {1} vous a supprimé de la liste des modérateurs d''''invité
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> vous a supprimé de la liste des modérateurs de <b>{2}</b> <b>{3}</b>.
guestNameTitle = Invité',
messages_english='accessToLinshareBTn = Access
subject = {0} {1} deleted you from guest moderator''''s list
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> deleted you from moderators list of <b>{2}</b> <b>{3}</b>.
guestNameTitle = Guest',
messages_russian='accessToLinshareBTn = Доступ
subject = {0} {1} удалил вас из списка приглашенных модераторов
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> удалил вас из списка приглашенных модераторов в <b>{2}</b> <b>{3}</b>.
guestNameTitle = Гость',
messages_vietnamese='accessToLinshareBTn = Truy cập
subject = {0} {1} đã xóa bạn khỏi danh sách quản trị 
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã xóa bạn khỏi danh sách quản trị của <b>{2}</b> <b>{3}</b>.
guestNameTitle = Khách' WHERE id=43;
UPDATE mail_content SET subject='[( #{subject(${actor.firstName},${actor.lastName}, #{productName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${account.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(${actor.firstName},${actor.lastName},${guest.firstName},${guest.lastName},${role})}"></span>
          <!--/* Access button to guest account */-->
          <th:block  data-th-replace="layout :: actionButtonLink(#{accessToLinshareBTn},${guestLink})"/>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
           <th:block data-th-replace="layout :: infoEditedItem(#{role}, ${role.oldValue}, ${role.value})"/>
    </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accessToLinshareBTn = Accéder
subject = {0} {1} vous a modifié le modérateur role
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> vous a modifié le modérateur role pour <b>{2}</b> <b>{3}</b>.
role = Role',
messages_english='accessToLinshareBTn = Access
subject = {0} {1} updated your moderator role
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> updated your moderator role on the guest <b>{2}</b> <b>{3}</b>.
role = Role',
messages_russian='accessToLinshareBTn = Доступ
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> обновил вашу роль модератора в гостевом <b>{2}</b> <b>{3}.
subject = {0} {1} обновил вашу роль модератора
role = Роль',
messages_vietnamese='accessToLinshareBTn = Truy cập 
subject = {0} {1} cập nhật quyền quản trị của bạn 
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã cập nhật quyền quản trị của bạn đối với khách <b>{2}</b> <b>{3}</b>.
role = Quyền'WHERE id=42;
UPDATE mail_content SET subject='[( #{subject})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${guest.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(#{productName},${guest.mail})}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoDateArea(#{accountCreationDateTitle},${guestCreationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{accountExpiryDateTitle},${guestExpirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accountCreationDateTitle = Date de création
accountExpiryDateTitle = Date d''''expiration
mainMsg = Le mot de passe du compte {0} <b>{1}</b> a été modifié.
subject = Votre mot de passe a été modifié',messages_english='accountCreationDateTitle = Account creation date
accountExpiryDateTitle = Account expiry date
mainMsg = The password of the account {0} <b>{1}</b> was modified.
subject = Your password has been modified',messages_russian='accountCreationDateTitle = Дата создания аккаунта
accountExpiryDateTitle = Дата окончания действия аккаунта
mainMsg = Пароль аккаунта {0} <b>{1}</b> был изменен.
subject = Ваш пароль был изменен',messages_vietnamese='accountCreationDateTitle = Ngày tạo tài khoản 
accountExpiryDateTitle = Ngày tài khoản hết hạn 
mainMsg = Mật khẩu của tài khoản {0} <b>{1}</b> đã được thay đổi. 
subject = Mật khẩu của bạn đã được thay đổi' WHERE id=31;
UPDATE mail_content SET subject='[( #{subject(${guest.firstName},${guest.lastName}, #{productName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${owner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(${guest.firstName},${guest.lastName},${daysLeft})}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoDateArea(#{accountCreationDateTitle},${guestCreationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{accountExpiryDateTitle},${guestExpirationDate})"/>
    <th:block data-th-replace="layout :: infoStandardArea(#{userEmailTitle},${guest.mail})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='accessToLinshareBTn = Le compte de votre invité expire
accountCreationDateTitle = Date de création
accountExpiryDateTitle = Date d''''expiration
activationLinkTitle = Initialization link
mainMsg = Le compte invité de : <b> {0} <span style="text-transform:uppercase">{1}</span></b> expirera dans {2} jours. Pensez à prolonger la validité du compte si besoin.
subject = Le compte invité de {0}  {1} expire bientôt
userEmailTitle = Email',messages_english='accessToLinshareBTn = Expiration account
accountCreationDateTitle = Account creation date
accountExpiryDateTitle = Account expiry date
activationLinkTitle = Initialization link
mainMsg = The  <b> {0} <span style="text-transform:uppercase">{1}</span></b> guest account is about to expire in {2} days. If this account is still needed,  postpone its expiration date.
subject = {0}  {1} guest account will expire soon.
userEmailTitle = Email',messages_russian='accessToLinshareBTn = Истечение срока действия аккаунта
accountCreationDateTitle = Дата создания аккаунта
accountExpiryDateTitle = Дата истечения срока действия аккаунта
activationLinkTitle = Ссылка активации
mainMsg = Срок действия гостевого аккаунта <b> {0} <span style="text-transform:uppercase">{1}</span></b> заканчивается через {2} дня. Если вам все еще нужен аккаунт, продлите срок его действия.
subject = {0}  {1} срок действия гостевого аккакунта скоро закончится.
userEmailTitle = Электронная почта',messages_vietnamese='accessToLinshareBTn = Tài khoản hết hạn 
accountCreationDateTitle = Ngày tạo tài khoản 
accountExpiryDateTitle = Ngày tài khoản hết hạn 
activationLinkTitle = Đường dẫn 
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span></b> Tài khoản khách sắp hết hạn trong {2} ngày. Nếu tài khoản này vẫn cần thiết, bạn có thể gia hạn.
subject = {0}  {1} tài khoản khách sắp hết hạn 
userEmailTitle = Email' WHERE id=25;
UPDATE mail_content SET subject= '[( #{subject})]',
body= '<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
          <th:block data-th-replace="layout :: greetings(${shareRecipient.mail})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p style="font-weight:bold;font-size:15px;"  data-th-utext="#{mainTitle(${shareOwner.firstName} , ${shareOwner.lastName})}"></p>
        <p>
          <span data-th-utext="#{beginingMainMsg}"></span>
          <span data-th-utext="#{otherMsg}"></span>
        </p>
        <th:block data-th-replace="layout :: actionButtonLink(#{downloadBtn},${anonymousURL})"/></br>
        <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
  <th:block data-th-replace="layout :: infoStandardArea(#{passwordMessageTitle},${password})"/>
  <th:block data-th-replace="layout :: infoActionLink(#{downloadLinkTit},${anonymousURL})"/>
  <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${shares[0].creationDate})"/>
  <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${shares[0].expirationDate})"/>
  <th:block data-th-replace="layout :: infoFileLinksListingArea(#{common.filesInShare},${shares},${anonymous})"/>

  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',
messages_french= '
	subject=LinShare Génération d''''un nouveau mot de passe
	mainTitle= Un nouveau mot de passe vous a été généré par {0} {1}.
	beginingMainMsg= Pour des raisons de sécurité un nouveau mot de passe pour accéder à votre partage a été généré.
	otherMsg= Vous pouvez de nouveau cliquer sur le boutton ci-dessous pour télécharger le partage et saisissez le nouveau mot de passe.
	downloadBtn=Télécharger
	passwordMessageTitle= Voici le nouveau mot de passe:
	downloadLinkTit = lien de téléchargement:
	',
messages_english= '
	subject=LinShare New password Generation  
	mainTitle= A new password was generated by {0} {1} 
	beginingMainMsg= For a security reasons a new password was generated.
	otherMsg= You can click the button below to download the shares and enter the new generated password below.
	downloadBtn= Download
	passwordMessageTitle= Here is the new password:
	downloadLinkTit= Download link:
	',
messages_russian= '
	subject=LinShare Генерация нового пароля
	mainTitle= Новый пароль был сгенерирован {0} {1}
	beginingMainMsg= В целях безопасности был сгенерирован новый пароль.
	otherMsg= Вы можете нажать кнопку ниже, чтобы загрузить общие файлы и ввести новый сгенерированный пароль.
	downloadBtn= Загрузить
	passwordMessageTitle= Новый пароль:
	downloadLinkTit= Ссылка загрузки:
	',
messages_vietnamese= '
	subject=LinShare Tạo Mật khẩu mới
	mainTitle= Một mật khẩu mới đã được tạo bởi {0} {1} 
	beginingMainMsg= Vì mục đích bảo mật một mật khẩu mới đã được tạo
	otherMsg= Bạn có thể bấm vào đường dẫn dưới đây để tải về file chia sẻ và nhập mật khẩu mới dưới đây 
	downloadBtn= Tải xuống 
	passwordMessageTitle= Đây là mật khẩu mới:
	downloadLinkTit= Link tải:
	'
WHERE id= 38;
UPDATE mail_content
SET subject='[# th:if="${!anonymous}"]
  [# th:if="${shareRecipient.contactListName != null}"]
    [( #{subjectContactList(${shareRecipient.contactListName},${share.name})})]
  [/]
  [# th:if="${shareRecipient.contactListName == null}"]
    [( #{subject(${shareRecipient.firstName},${shareRecipient.lastName},${share.name})})]
  [/]
[/]
[# th:if="${anonymous}"]
  [( #{subjectAnonymous(${shareRecipient.mail},${share.name})})]
[/]',
    body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/*  Upper main-content */-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${shareOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <th:block th:if="${!anonymous}">
            <span th:if="${shareRecipient.contactListName != null}"
                  data-th-utext="#{mainMsgContactList(${shareRecipient.contactListName})}">
              One member of the contact list has downloaded your file
            </span>
            <span th:unless="${shareRecipient.contactListName != null}"
                  data-th-utext="#{mainMsgInt(${shareRecipient.firstName},${shareRecipient.lastName})}">
              Peter WILSON has downloaded your file
            </span>
          </th:block>
          <th:block th:if="${anonymous}">
            <span data-th-utext="#{mainMsgExt(${shareRecipient.mail})}">
              unknown@domain.com has downloaded your file
            </span>
          </th:block>
          <span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;" data-th-text="#{fileNameEndOfLine(${share.name})}" th:href="@{${share.href}}">
                  filename.ext
              </a>
          </span>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
<th:block th:if="${!anonymous}">
      <th:block th:if="${shareRecipient.contactListName != null}">
        <th:block data-th-replace="layout :: infoStandardArea(#{shareRecipientTitle}, ${shareRecipient.contactListName})"/>
      </th:block>
      <th:block th:if="${shareRecipient.contactListName == null}">
        <th:block data-th-replace="layout :: infoStandardArea(#{shareRecipientTitle}, ~{::#recipientName})">
          <span id="recipientName">
            <span th:text="${shareRecipient.firstName}"/> <span style="text-transform:uppercase" th:text="${shareRecipient.lastName}"/>
          </span>
        </th:block>
      </th:block>
    </th:block>
    <th:block th:if="${anonymous}">
      <th:block data-th-replace="layout :: infoStandardArea(#{shareRecipientTitle},${shareRecipient.mail})"/>
    </th:block>
    <th:block data-th-replace="layout :: infoDateArea(#{downloadDate},${actionDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${shareDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${expiryDate})"/>
    <th:block th:if="${sharesCount} > 1">
      <th:block data-th-replace="layout :: infoFileListUploadState(#{common.filesInShare},${shares})"/>
    </th:block>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',
    messages_french='downloadDate = Téléchargé le
fileNameEndOfLine = {0}.
mainMsgExt = Le destinataire externe <b>{0}</b> a téléchargé votre fichier
mainMsgInt = <b>{0} <span style="text-transform:uppercase">{1}</span></b> a téléchargé votre fichier
mainMsgContactList = Un membre de la liste de contacts <b>{0}</b> a téléchargé votre fichier
shareRecipientTitle = Destinataire
subject = {0} {1} a téléchargé {2}
subjectAnonymous = {0} a téléchargé {1}
subjectContactList = Un membre de {0} a téléchargé {1}',
    messages_english='downloadDate = Download date
fileNameEndOfLine = {0}.
mainMsgExt = The external recipient <b>{0}</b> has downloaded your file
mainMsgInt = <b>{0} <span style="text-transform:uppercase">{1}</span></b> has downloaded your file
mainMsgContactList = One member of the contact list <b>{0}</b> has downloaded your file
shareRecipientTitle = Recipient
subject = {0} {1} has downloaded {2}
subjectAnonymous = {0} has downloaded {1}
subjectContactList = A member of {0} has downloaded {1}',
    messages_russian='downloadDate = Дата загрузки
fileNameEndOfLine = {0}.
mainMsgExt = Внешний пользователь <b>{0}</b> скачал(а) ваш файл
mainMsgInt = <b>{0} <span style="text-transform:uppercase">{1}</span></b> скачал(а) ваш файл
mainMsgContactList = Один участник списка контактов <b>{0}</b> скачал(а) ваш файл
shareRecipientTitle = Получатель
subject = {0} {1} был скачан {2}
subjectAnonymous = {0} был скачан {1}
subjectContactList = Участник {0} скачал(а) {1}',
    messages_vietnamese='downloadDate = Ngày tải
fileNameEndOfLine = {0}.
mainMsgExt = Người nhận ngoài <b>{0}</b> đã tải xuống file của bạn
mainMsgInt = <b>{0} <span style="text-transform:uppercase">{1}</span></b> đã tải xuống file của bạn
mainMsgContactList = Một thành viên của danh sách liên hệ <b>{0}</b> đã tải xuống file của bạn
shareRecipientTitle = Người nhận
subject = {0} {1} đã tải xuống {2}
subjectAnonymous = {0} đã tải xuống {1}
subjectContactList = Thành viên của {0} đã tải xuống {1}'
WHERE id = 4;UPDATE mail_content SET subject='[( #{subject(${shareOwner.firstName},${shareOwner.lastName},${share.name})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${shareRecipient.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg(${shareOwner.firstName},${shareOwner.lastName})}">
             Peter WILSON has downloaded your file
          </span>
          <span style="font-weight:bold" data-th-text="${share.name}" >
             filename.ext
          </span>.
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${share.creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{deletedDate},${share.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='deletedDate = Supprimé le
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> a supprimé le partage
subject = {0} {1} a supprimé le partage de {2}',messages_english='deletedDate = Deletion date
mainMsg = <b>{0} <span style="text-transform:uppercase">{1}</span></b> has deleted the  fileshare
subject = {0} {1} has deleted the fileshare {2}',messages_russian='deletedDate = Дата удаления
mainMsg = <b>{0} <span style="text-transform:uppercase">{1}</span></b> удалил файл рассылки
subject = {0} {1} удалил файл рассылки {2}',messages_vietnamese='deletedDate = Ngày xóa
mainMsg = <b>{0} <span style="text-transform:uppercase">{1}</span></b> đã xóa tài liệu chia sẻ 
subject = {0} {1} đã xóa tài liệu chia sẻ  {2}' WHERE id=5;
UPDATE mail_content SET subject='[# th:if="${documentsCount} > 1"] 
[( #{subjectPlural})]
[/]
[# th:if="${documentsCount} ==  1"]
[( #{subjectSingular})]
[/]
[# th:if="${!#strings.isEmpty(customSubject)}"]
[(${ ": " +customSubject})]
[/]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/*  Upper main-content */-->
  <section id="main-content">
    <!--/* If the sender has added a  customized message */-->
    <th:block data-th-if="${!#strings.isEmpty(customMessage)}">
      <div th:replace="layout :: contentMessageSection( ~{::#message-title}, ~{::#message-content})">
        <span id="message-title">
          <span data-th-text="#{msgFor}">You have a message from</span>
        </span>
        <span id="message-content" data-th-text="*{customMessage}" style="white-space: pre-line;">
          Hi Amy,<br>
          As agreed,  i am sending you the report as well as the related files. Feel free to contact me if need be. <br>Best regards, Peter.
        </span>
      </div>
    </th:block>
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${shareOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-if="(${documentsCount} > 1)" data-th-utext="#{numFilesMsgPlural(${documentsCount})}">
            Peter WILSON has  shared 4 files
            </span>
          <span data-th-if="(${documentsCount} ==  1)" data-th-utext="#{numFilesMsgSingular(${documentsCount})}">
            Peter WILSON has  shared 1 file
            </span>
          <span data-th-if="(${recipientsCount} >  1)" th:with="df=#{date.format}"
                data-th-utext="#{recipientCountMsgPlural(${#dates.format(expirationDate,df)},${recipientsCount})}">
             to 3 recipients set to expire for the 7th December 2018
            </span>
          <span data-th-if="(${recipientsCount} ==  1)" th:with="df=#{date.format}"
                data-th-utext="#{recipientCountMsgSingular(${#dates.format(expirationDate,df)},${recipientsCount})}">
            to 1 recipient set to expire for the 7th December 2018
            </span>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End upper of main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <span style="font-weight:bold;" data-th-text="#{common.recipients}">Recipients</span>
      <div class="recipient-info">
      <div th:each="recipient : ${recipients}">
        <span th:if="${recipient.contactListName != null}" th:text="${recipient.contactListName}"/>
        <span th:if="${recipient.contactListName == null}">
          <span th:if="${recipient.firstName != null and recipient.lastName != null}">
            <span th:text="${recipient.firstName}"/>
            <span style="text-transform:uppercase" th:text="${recipient.lastName}"/>
          </span>
          <span th:if="${recipient.firstName == null or recipient.lastName == null}" th:text="${recipient.mail}"/>
        </span>
      </div>
    </div>
    <div style="margin-bottom: 16px;"></div>
    <th:block data-th-replace="layout :: infoFileLinksListingArea(#{common.filesInShare},${documents},false)"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='numFilesMsgPlural = Vous avez partagé <b>{0} fichiers</b>
numFilesMsgSingular = Vous avez partagé <b>{0} fichier</b>
recipientCountMsgPlural = avec <b>{1} destinataires</b>. Ce partage expirera le <b>{0}</b>.
recipientCountMsgSingular = avec <b>{1} destinataire</b>. Ce partage expirera le <b>{0}</b>.
subjectPlural = Vous avez partagé des fichiers
subjectSingular = Vous avez partagé un fichier
msgFor = Votre message de partage',messages_english='numFilesMsgPlural = You have shared <b>{0} files</b>
numFilesMsgSingular = You have shared <b>{0} file</b>
recipientCountMsgPlural =   to <b>{1} recipients</b>. The fileshare will expire on : {0}.
recipientCountMsgSingular =   to <b>{1} recipient</b>. The fileshare will  expire on : {0}.
subjectPlural =  You have shared some files 
subjectSingular = You have shared a file
msgFor = Your message of sharing',messages_russian='numFilesMsgPlural = Вы поделились <b>{0} files</b>
numFilesMsgSingular = Вы поделились <b>{0} file</b>
recipientCountMsgPlural =   с <b>{1} recipients</b>. Срок действия рассылки закончится: {0}.
recipientCountMsgSingular =   с <b>{1} recipient</b>. Срок действия рассылки закончится: {0}.
subjectPlural =  Вы поделились некоторыми файлами 
subjectSingular =Вы поделились файлом
msgFor = Ваше сообщение рассылки',messages_vietnamese='numFilesMsgPlural = Bạn đã chia sẻ <b>{0} files</b>
numFilesMsgSingular = Bạn đã chia sẻ <b>{0} file</b>
recipientCountMsgPlural = tới <b>{1} recipients</b>. Tài liệu chia sẻ sẽ hết hạn vào : {0}.
recipientCountMsgSingular =   tới <b>{1} recipient</b>. Tài liệu chia sẻ sẽ hết hạn vào : {0}.
subjectPlural = Bạn đã chia sẻ một số tìa liệu 
subjectSingular = Bạn đã chia sẻ 1 tài liệu' WHERE id=3;
UPDATE mail_content SET subject='[# th:if="${#strings.isEmpty(customSubject)}"]
[# th:if="${sharesCount} > 1"]
[( #{subjectPlural(${shareOwner.firstName},${ shareOwner.lastName})})]
[/]
[# th:if="${sharesCount} ==  1"]
[( #{subjectSingular(${shareOwner.firstName },${ shareOwner.lastName})})]
[/]
[/]
[# th:if="${!#strings.isEmpty(customSubject)}"]
[(${customSubject})]   [( #{subjectCustomAlt(${shareOwner.firstName },${shareOwner.lastName})})]
[/]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/*  Upper main-content */-->
  <section id="main-content">
    <!--/* If the sender has added a  customized message */-->
    <th:block data-th-if="${!#strings.isEmpty(customMessage)}">
      <div th:replace="layout :: contentMessageSection( ~{::#message-title}, ~{::#message-content})">
        <span id="message-title">
          <span data-th-text="#{msgFrom}">You have a message from</span>
          <b data-th-text="#{name(${shareOwner.firstName} , ${shareOwner.lastName})}">Peter Wilson</b> :
        </span>name = {0} {1}
        <span id="message-content" data-th-text="*{customMessage}" style="white-space: pre-line;">
          Hi Amy,<br>
          As agreed,  i am sending you the report as well as the related files. Feel free to contact me if need be. <br>Best regards, Peter.
        </span>
      </div>
    </th:block>
    <!--/* End of customized message */-->
    <!--/* main-content container */-->
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings for external or internal user */-->
        <div data-th-if="(${!anonymous})">
          <th:block data-th-replace="layout :: greetings(${shareRecipient.firstName})"/>
        </div>
        <div data-th-if="(${anonymous})">
          <th:block data-th-replace="layout :: greetings(${shareRecipient.mail})"/>
        </div> <!--/* End of Greetings for external or internal recipient */-->
        <!--/* Main email  message content*/-->
        <p>
            <span data-th-if="(${sharesCount} ==  1)"
                  data-th-utext="#{mainMsgSingular(${shareOwner.firstName},${shareOwner.lastName},${sharesCount})}">
            Peter WILSON has shared 4 file with you
            </span>
          <span data-th-if="(${sharesCount} > 1)"
                data-th-utext="#{mainMsgPlural(${shareOwner.firstName},${shareOwner.lastName},${sharesCount})}">
            Peter WILSON has shared 4 files with you
            </span>
          <br/>
          <!--/* Check if the external user has a password protected file share */-->
          <span data-th-if="(${protected})">
       <span data-th-if="(${sharesCount} ==  1)" data-th-text="#{helpPasswordMsgSingular}">Click on the link below in order to download it     </span>
            <span data-th-if="(${sharesCount} >  1)" data-th-text="#{helpPasswordMsgPlural}">Click on the links below in order to download them </span>
            </span>
          <span data-th-if="(${!anonymous})">
            <span data-th-if="(${sharesCount} ==  1)">
              <span  data-th-utext="#{click}"></span>
                <span>
                 <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="#{link}" th:href="@{${filesSharesLink}}" >
                  link
                 </a>
               </span>
              <span data-th-utext="#{helpMsgSingular}"></span>
            </span>
            <span data-th-if="(${sharesCount} >  1)">
              <span  data-th-utext="#{click}"></span>
              <span>
                <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="#{link}" th:href="@{${filesSharesLink}}" >
                 link
               </a>
              </span>
             <span data-th-utext="#{helpMsgPlural}"></span>
            </span>
            </span>
        </p>
        <!--/* Single download link for external recipient */-->
        <div data-th-if="(${anonymous})">
          <th:block data-th-replace="layout :: actionButtonLink(#{downloadBtn},${anonymousURL})"/>
        </div>
        <!--/* End of Main email message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container */-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <div data-th-if="(${protected})">
      <th:block data-th-replace="layout :: infoStandardArea(#{password},${password})"/>
    </div>
    <div data-th-if="(${anonymous})">
      <th:block data-th-replace="layout :: infoActionLink(#{downloadLink},${anonymousURL})"/>
    </div>
    <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${shares[0].creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${shares[0].expirationDate})"/>
    <th:block data-th-replace="layout :: infoFileLinksListingArea(#{common.filesInShare},${shares},${anonymous})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
  </div>
</body>
</html>',messages_french='downloadBtn = Télécharger
downloadLink = Lien de téléchargement
helpMsgSingular =  pour visualiser le document partagé.
helpMsgPlural =pour visualiser tous les documents du partage.
helpPasswordMsgSingular = Cliquez sur le lien pour le télécharger et saisissez le mot de passe fourni ici.
helpPasswordMsgPlural = Cliquez sur le lien pour les télécharger et saisissez le mot de passe fourni.
mainMsgPlural = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>a partagé {2} fichiers avec vous.
mainMsgSingular = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> a partagé {2} fichier  avec vous.
msgFrom = Vous avez un message de
name = {0} {1}
password = Mot de passe
subjectCustomAlt =de {0} {1}
subjectPlural =  {0} {1} vous a partagé des fichiers
subjectSingular =  {0} {1} vous a partagé un fichier
click = Cliquez sur ce
link = lien',messages_english='downloadBtn = Download
downloadLink = Download link
helpMsgPlural = to access to all documents in this share.
helpMsgSingular = to access to the document in this share.
helpPasswordMsgSingular = Click on the link below in order to download it and enter the provided password.
helpPasswordMsgPlural = Click on the link below in order to download them and enter the provided password.
mainMsgPlural = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> has shared <b>{2} files</b> with you.
mainMsgSingular = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> has shared <b>{2} file</b> with you.
msgFrom = You have a message from
name = {0} {1}
password = Password
subjectCustomAlt =by {0} {1}
subjectPlural = {0} {1} has shared some files with you
subjectSingular = {0} {1} has shared a file with you
click = Follow this
link = link',messages_russian='downloadBtn = Загрузить
downloadLink = Загрузить по ссылке
helpMsgPlural = , чтобы получить доступ ко всем документам рассылки.
helpMsgSingular = , чтобы получить доступ ко всем документам рассылки.
helpPasswordMsgSingular = Перейдите по ссылке ниже, чтобы загрузить файлы и ввести пароль.
helpPasswordMsgPlural = Перейдите по ссылке ниже, чтобы загрузить файлы и ввести пароль.
mainMsgPlural = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> поделился с вами файлами <b>{2} файлов</b>.
mainMsgSingular = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> поделился с вами  <b>{2} файлами</b>.
msgFrom = Вы получили сообщение от
name = {0} {1}
password = Пароль
subjectCustomAlt =by {0} {1}
subjectPlural = {0} {1} поделился с вами файлами
subjectSingular = {0} {1} поделился с вами файлами
click = Перейдите по
link = ссылке' ,messages_vietnamese='downloadBtn = Tải xuống 
downloadLink = Đường dẫn tải xuống 
helpMsgPlural = để truy cập tất cả tài liệu được chia sẻ 
helpMsgSingular = để truy cập tất cả tài liệu được chia sẻ. 
helpPasswordMsgSingular = Bấm vào đường link dưới đây để tải và nhập mật khẩu được cung cấp trước đó.
helpPasswordMsgPlural = Bấm vào đường link dưới đây để tải và nhập mật khẩu được cung cấp trước đó. 
mainMsgPlural = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> đã chia sẻ <b>{2} files</b> với bạn .
mainMsgSingular = <b> {0} <span style="text-transform:uppercase">{1}</span> </b> đã chia sẻ <b>{2} file</b> với bạn.
msgFrom = Bạn có 1 tin nhắn từ 
name = {0} {1}
password = Mật khẩu
subjectCustomAlt =by {0} {1}
subjectPlural = {0} {1} đã chia sẻ một vài tài liệu với bạn.
subjectSingular = {0} {1} đã chia sẻ một tài liệu với bạn. 
click = Bấm vào 
link = link' WHERE id=2;
UPDATE mail_content SET subject='[( #{subject(${share.name})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${shareRecipient.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{beginningMainMsg}"></span>
          <b><span data-th-text="#{fileNameEndOfLine(${share.name})}"></span></b>
          <span data-th-utext="#{endingMainMsg(${shareOwner.firstName},${shareOwner.lastName})}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoStandardArea(#{shareFileTitle},${share.name})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{shareCreationDateTitle},${share.creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{shareExpiryDateTitle},${share.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='shareFileTitle = Le fichier partagé
shareCreationDateTitle = Date de création
shareExpiryDateTitle = Date d''''expiration
activationLinkTitle = Initialization link
beginningMainMsg = Le partage
endingMainMsg = émis par <b> {0} <span style="text-transform:uppercase">{1}</span></b> a expiré et a été supprimé par le <b>système</b>.
subject = Le partage {0} a expiré
fileNameEndOfLine = {0}',messages_english='shareFileTitle = The shared file
shareCreationDateTitle = Creation date
shareExpiryDateTitle = Expiration date
activationLinkTitle = Initialization link
beginningMainMsg =  The fileshare
endingMainMsg = sent by <b> {0} <span style="text-transform:uppercase">{1}</span></b> has expired and been deleted by the <b>system</b>.
subject = The fileshare {0} has expired
fileNameEndOfLine = {0}',messages_russian='shareFileTitle = Файл рассылки
shareCreationDateTitle = Дата создания
shareExpiryDateTitle = Дата срока истечения действия
activationLinkTitle = Ссылка активации
beginningMainMsg =  У файла рассылки
endingMainMsg = отправленного <b> {0} <span style="text-transform:uppercase">{1}</span></b> истек срок действия и он был удален <b>system</b>.
subject = Срок действия файла рассылки {0} истек
fileNameEndOfLine = {0}' ,messages_vietnamese='shareFileTitle = Tài liệu chia sẻ 
shareCreationDateTitle = Ngày tạo 
shareExpiryDateTitle = NGày hết hạn 
activationLinkTitle = Đường dẫn 
beginningMainMsg =  Tài liệu chia sẻ 
endingMainMsg = được gửi bởi <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã hết hạn và bị xóa bởi <b>system</b>.
subject = Tài liệu chia sẻ  {0} đã hết hạn. 
fileNameEndOfLine = {0}'WHERE id=27;
UPDATE mail_content SET subject='[( #{subject(${share.name})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-if="(${!anonymous})">
          <th:block data-th-replace="layout :: greetings(${shareRecipient.firstName})"/>
        </th:block>
        <th:block data-th-if="(${anonymous})">
          <th:block data-th-replace="layout :: greetings(${shareRecipient.mail})"/>
        </th:block>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <th:block data-th-if="(${anonymous})">
            <span
              data-th-utext="#{mainMsgExt(${share.name}, ${shareOwner.firstName},${shareOwner.lastName},${daysLeft})}">
              Your share link for Peter sent by Peter WILSON, will expire in 8 days. a-shared-file.txt.
            </span>
          </th:block>
          <th:block data-th-if="(${!anonymous})">
            <span data-th-utext="#{beginningMainMsgInt}"></span>
            <span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;" data-th-text="${share.name}"
                th:href="@{${share.href}}">
                  filename.ext
             </a>
          </span>
            <span
              data-th-utext="#{endingMainMsgInt(${shareOwner.firstName},${shareOwner.lastName},${daysLeft})}">  </span>
            <!--/* Single download link for external recipient */-->
            <th:block data-th-replace="layout :: actionButtonLink(#{common.download},${share.href})"/>
          </th:block>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block
      data-th-replace="layout :: infoStandardArea(#{sharedBy},#{name(${shareOwner.firstName},${shareOwner.lastName})})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${share.creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${share.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='beginningMainMsgInt = Le partage
endingMainMsgInt = émis par <b> {0} <span style="text-transform:uppercase">{1}</span></b>, va expirer dans <b>{2} jours</b>.
mainMsgExt = Le partage <b>{0}</b> émis par <b> {1} <span style="text-transform:uppercase">{2}</span></b>, va expirer dans <b>{3} jours</b>.
name = {0} {1}
sharedBy = Partagé par
subject =  Le partage {0} va bientôt expirer',messages_english='beginningMainMsgInt = The fileshare
endingMainMsgInt = sent by <b> {0} <span style="text-transform:uppercase">{1}</span></b>,  will expire in <b>{2} days</b>.
mainMsgExt = The fileshare <b>{0}</b> sent by <b> {1} <span style="text-transform:uppercase">{2}</span></b>,  will expire in <b>{3} days</b>.
name = {0} {1}
sharedBy = Shared by
subject = The fileshare for {0} is about to expire',messages_russian='beginningMainMsgInt = Срок действия файла рассылки
endingMainMsgInt = отправленного <b> {0} <span style="text-transform:uppercase">{1}</span></b>,  закончится через <b>{2} дней</b>.
mainMsgExt = Срок действия файла рассылки <b>{0}</b> sent by <b> {1} <span style="text-transform:uppercase">{2}</span></b>,  закончится через <b>{3} дней</b>.
name = {0} {1}
sharedBy = Отправлено
subject = Срок действия файла рассылки {0} заканчивается',messages_vietnamese='beginningMainMsgInt = Tài liệu chia sẻ 
endingMainMsgInt = được gửi bởi <b> {0} <span style="text-transform:uppercase">{1}</span></b>,  sẽ hết hạn trong <b>{2} ngày </b>.
mainMsgExt = Tài liệu chia sẻ <b>{0}</b> được gửi bởi <b> {1} <span style="text-transform:uppercase">{2}</span></b>,  sẽ hết hạn trong <b>{3} ngày </b>.
name = {0} {1}
sharedBy = Được chia sẻ bởi 
subject = Tài liệu chia sẻ cho {0} sắp hết hạn' WHERE id=6;
UPDATE mail_content
SET subject='[(#{subject})]',
    body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${shareOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{beginningMainMsg}"></span>
          <span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="#{fileNameEndOfLine(${share.name})}" th:href="@{${share.href}}" >
                  filename.ext
              </a>
          </span>
          <span data-th-utext="#{endingMainMsgShort(${daysLeft})}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <div th:if="${recipient.contactListName != null}">
      <th:block data-th-replace="layout :: infoStandardArea(#{shareRecipientTitle}, ${recipient.contactListName})"/>
    </div>
    <div th:unless="${recipient.contactListName != null}">
      <th:block data-th-replace="layout :: infoStandardArea(#{shareRecipientTitle},#{name(${recipient.firstName}, ${recipient.lastName})})"/>
    </div>
    <th:block data-th-replace="layout :: infoStandardArea(#{shareFileTitle},${share.name})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{shareCreationDateTitle},${share.creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{shareExpiryDateTitle},${share.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',
    messages_french='accessToLinshareBTn = Votre partage expire bientôt
shareRecipientTitle =  Destinataire
shareFileTitle = Le fichier partagé
shareCreationDateTitle = Date de création
shareExpiryDateTitle = Date d''''expiration
activationLinkTitle = Initialization link
beginningMainMsg = Le partage
endingMainMsg =  expire dans {0} jours sans avoir été téléchargé par <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
endingMainMsgShort = expire dans {0} jours sans avoir été téléchargé.
subject = Votre partage expire bientôt et n''''a pas encore été téléchargé
name = {0} {1}
fileNameEndOfLine = {0}',
    messages_english='accessToLinshareBTn = Your share will expire soon
shareRecipientTitle = Recipient
shareFileTitle = The shared file
shareCreationDateTitle = Creation date
shareExpiryDateTitle = Expiration date
activationLinkTitle = Initialization link
beginningMainMsg =  The fileshare
endingMainMsg =  will expire in {0} days and has not been downloaded by the recipient <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
endingMainMsgShort = will expire in {0} days and has not been downloaded.
subject = Your share will expire soon and has not been downloaded
name = {0} {1}
fileNameEndOfLine = {0}',
    messages_russian='accessToLinshareBTn = Срок действия вашей рассылки скоро закончится
shareRecipientTitle = Получатель
shareFileTitle = Файл рассылки
shareCreationDateTitle = Дата создания
shareExpiryDateTitle = Дата истечения срока действия
activationLinkTitle = Ссылка активации
beginningMainMsg = Срок действия файла рассылки
endingMainMsg =  закончится через {0} дней, а файла не были скачаны получателем <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
endingMainMsgShort = закончится через {0} дней, а файла не были скачаны.
subject = Срок действия рассылки скоро закончится, а файлы не были скачаны
name = {0} {1}
fileNameEndOfLine = {0}',
    messages_vietnamese='accessToLinshareBTn = Tài liệu chia sẻ của bạn sắp hết hạn
shareRecipientTitle = Người nhận
shareFileTitle = Tài liệu chia sẻ
shareCreationDateTitle = Ngày tạo
shareExpiryDateTitle = Ngày hết hạn
activationLinkTitle = Đường dẫn
beginningMainMsg =  Tài liệu chia sẻ
endingMainMsg =  sẽ hết hạn trong {0} ngày và người nhận vẫn chưa tải về <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
endingMainMsgShort = sẽ hết hạn trong {0} ngày và người nhận vẫn chưa tải về.
subject = Tài liệu chia sẻ của bạn sắp hết hạn và vẫn chưa được tải về
name = {0} {1}
fileNameEndOfLine = {0}' WHERE id=26;UPDATE mail_content SET subject='[# th:if="${documentsCount} > 1"]
[( #{subjectPlural(${documentsCount})})]
[/]
        [# th:if="${documentsCount} ==  1"]
          [( #{subjectSingular(${documentsCount})})]
       [/]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${shareOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-if="(${documentsCount} ==  1)" data-th-utext="#{mainMsgSingular(${documentsCount})}">
            Some recipients have not downloaded 2 files yet. You may find further details of the recipients downloads, below.
          </span>
          <span data-th-if="(${documentsCount} >  1)" data-th-utext="#{mainMsgplural(${documentsCount})}">
            Some recipients have not downloaded 2 files yet. You may find further details of the recipients downloads, below.
          </span>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <div style="margin-bottom:17px;">
      <span style="font-weight:bold;" data-th-text="#{sharedFiles}">Shared files</span>
      <table>
        <th:block th:each="document : ${documents}">
          <tr>
            <td style="color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
            <td>
              <a target="_blank" style="color:#1294dc;text-decoration:none;font-size:13px"
                 th:href="@{${document.href}}" data-th-utext="${document.name}">
                document.pdf
              </a>
            </td>
          </tr>
        </th:block>
      </table>
    </div>
    <div style="margin-bottom:17px;" data-th-if="${recipients != null and !recipients.isEmpty()}">
      <span style="font-weight:bold;" data-th-text="#{common.recipients}">Recipients</span>
      <table>
        <th:block th:each="recipient : ${recipients}">
          <tr>
            <td style="color:#787878;font-size: 22px;" width="20" align="center" valign="top">&bull;</td>
            <td>
               <th:block data-th-if="${recipient.contactListName != null and !recipient.contactListName.isEmpty()}">
                <span style="color:#787878;font-size:13px;font-style:italic;">
                  <th:block data-th-text="${recipient.contactListName}">Contact List Name</th:block>
                  <th:block data-th-if="${recipient.notDownloadedCount != null and recipient.notDownloadedCount > 0}">
                    <span data-th-text="#{contactListUndownloaded(${recipient.notDownloadedCount} , ${recipient.totalMembersCount})}">
                      (2/5 members have not downloaded)
                    </span>
                  </th:block>
                </span>
              </th:block>
              <th:block data-th-if="${recipient.contactListName == null or recipient.contactListName.isEmpty()}">
                <th:block data-th-if="${!#strings.isEmpty(recipient.lastName)}">
                  <span style="color:#787878;font-size:13px;">
                    <th:block data-th-utext="${recipient.firstName}" />
                    <th:block data-th-utext="${recipient.lastName}" />
                  </span>
                </th:block>
                <th:block data-th-if="${#strings.isEmpty(recipient.lastName)}">
                  <span style="color:#787878;font-size:13px;"
                        data-th-utext="${recipient.mail}">
                    user@example.com
                  </span>
                </th:block>
              </th:block>
            </td>
          </tr>
        </th:block>
      </table>
    </div>

    <!--/* Dates */-->
    <th:block data-th-replace="layout :: infoDateArea(#{common.titleSharedThe},${shareGroup.creationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{common.availableUntil},${shareGroup.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='downloadStatesTile = Etat de téléchargement
mainMsgplural = Certains destinataires n''''ont pas téléchargés <b>{0} fichiers</b>. Vous trouverez ci-dessous le récapitulatif de téléchargement de vos destinataires.
mainMsgSingular = Certains destinataires n''''ont pas téléchargés <b>{0} fichier</b>. Vous trouverez ci-dessous le récapitulatif de téléchargement de vos destinataires.
subjectPlural = Rappel de non-téléchargement : {0} fichiers n''''ont pas été téléchargés.
subjectSingular = Rappel de non-téléchargement :  {0} fichier n''''a pas été téléchargé.
sharedFiles = Fichiers partagés
contactListUndownloaded = ({0}/{1} membres n''''ont pas téléchargé)',
                        messages_english='downloadStatesTile = Downloads states
mainMsgplural = Some recipients have not downloaded <b>{0} files</b>. You may find further details of the recipients downloads below.
mainMsgSingular = Some recipients have not downloaded <b>{0} file</b>. You may find further details of the recipients downloads below.
subjectPlural = Undownloaded shared files alert : {0} files have not been downloaded yet.
subjectSingular = Undownloaded shared files alert : {0} file have not been downloaded yet.
sharedFiles = Shared files
contactListUndownloaded = ({0}/{1} members have not downloaded)',
                        messages_russian='downloadStatesTile = Статус загрузки
mainMsgplural = Некоторые получатели рассылки не скачали <b>{0} файлов</b>. Вы можете найти детали о получателях рассылки ниже.
mainMsgSingular = Некоторые получатели рассылки не скачали <b>{0} файлов</b>. Вы можете найти детали о получателях рассылки ниже.
subjectPlural = Уведомдение о не скачанных файлах: {0} файлов были не скачанны.
subjectSingular = Уведомдение о не скачанных файлах: {0} файлов были не скачанны.
sharedFiles = Общие файлы
contactListUndownloaded = ({0}/{1} участников не скачали)',
                        messages_vietnamese='downloadStatesTile = Hiện trạng tải xuống
mainMsgplural = Một vài người nhận đã không tải  <b>{0} files</b>. Bạn có thể xem thông tin chi tiết hơn về việc tải xuống của người nhận dưới đây. 
mainMsgSingular = Some recipients have not downloaded <b>{0} file</b>. Bạn có thể xem thông tin chi tiết hơn về việc tải xuống của người nhận dưới đây. 
subjectPlural = Thông báo chưa tải xuống file chia sẻ : {0} files vẫn chưa được người nhận tải xuống. 
subjectSingular = Thông báo chưa tải xuống file chia sẻ : {0} file vẫn chưa được người nhận tải xuống.
sharedFiles = Tập tin được chia sẻ
contactListUndownloaded = ({0}/{1} thành viên chưa tải xuống)'
WHERE id = 7;
UPDATE mail_content SET subject='[(#{subject(${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${request.subject})}">
                      Your Upload Request repository labeled $subject is now activated.
                     </span>
                     <span data-th-text="#{msgLink}">In order to access it click the link below.</span>
                  </p>
                  <th:block data-th-replace="layout :: actionButtonLink(#{buttonMsg},${requestUrl})"/>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateAreaWithHours(#{closureDate},${request.expirationDate})"/>
            </div>
            <div data-th-if="(${isCollective})">
               <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsOfDepot},${recipients})"/>
            </div>
             <div data-th-if="(${totalMaxDepotSize})">
                   <th:block data-th-replace="layout :: infoStandardArea(#{depotSize},${totalMaxDepotSize})"/>
            </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='buttonMsg = Accès
closureDate = Date de clôture
depotSize = Taille autorisée
mainMsg = Votre dépôt intitulé <b>{0}</b> est désormais actif.
msgLink = Vous pouvez y accéder en cliquant sur le lien ci-dessous.
recipientsOfDepot = Destinataires
subject = Votre invitation de dépôt {0} est désormais active',messages_english='buttonMsg = Access
closureDate = Closure date
depotSize = Allowed size
mainMsg = Your Upload Request labeled <b>{0}</b> is now active.
msgLink = Access it by following the link below.
recipientsOfDepot = Recipients
subject = Your Upload Request : {0}, is now active',messages_russian='buttonMsg = Доступ
closureDate = Дата закрытия
depotSize = Допустимый размер
mainMsg = Ваш запрос загрузки <b>{0}</b> активен.
msgLink = Получите доступ к нему, перейдя по ссылке ниже.
recipientsOfDepot = Получатель
subject = Ваш запрос загрузки {0} активен',messages_vietnamese='buttonMsg = Truy cập 
closureDate = Ngày đóng 
depotSize = Dung lượng cho phép 
mainMsg = Yêu cầu tải của bạn với tên <b>{0}</b> được kích hoạt bây giờ.
msgLink = Truy cập bằng cách mở đường dẫn dưới đây.
recipientsOfDepot = Người nhận 
subject = Yêu cầu tải của bạn: {0}, được kích hoạt ' WHERE id=17;
UPDATE mail_content SET subject='[(#{subject(${requestOwner.firstName}, ${requestOwner.lastName},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* If the sender has added a customized message */-->
            <th:block data-th-if="${!#strings.isEmpty(body)}">
               <div th:replace="layout :: contentMessageSection( ~{::#message-title}, ~{::#message-content})">
                  <span id="message-title">
                  <span data-th-text="#{msgFrom}">You have a message from</span>
                  <b data-th-text="#{name(${requestOwner.firstName} , ${requestOwner.lastName})}">Peter Wilson</b> :
                  </span>
                  <span id="message-content" data-th-text="${body}" style="white-space: pre-line;">
                  Hi Amy,<br>
                  As agreed,  could you send me the report. Feel free to contact me if need be. <br/>Best regards, Peter.
                  </span>
               </div>
            </th:block>
            <!--/* End of customized message */-->
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection(~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                   <th:block data-th-if="(${!request.wasPreviouslyCreated})">
                       <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${subject})}">
                          Peter Wilson invited  you to upload  some files in the Upload Request depot labeled : subject.
                       </span>
                   </th:block>
                    <th:block data-th-if="(${request.wasPreviouslyCreated})">
                       <span data-th-text="#{msgAlt(${subject} , ${requestOwner.firstName} , ${requestOwner.lastName})}"> Peter Wilson''s Upload Request is now activated..</span>
                     </th:block>
                     <br/>
                     <!--/* Check if the external user has a password protected file share */-->
                     <span data-th-if="(${!protected})">
                     <span data-th-text="#{msgUnProtected}">In order to access it click the link below.</span>
                     </span>
                     <span data-th-if="(${protected})">
                     <span data-th-text="#{msgProtected}">In order to access it click the link below and enter the provided password.</span>
                     </span>
                  </p>
                  <th:block data-th-replace="layout :: actionButtonLink(#{buttonMsg},${requestUrl})"/>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <div data-th-if="(${protected})">
               <th:block data-th-replace="layout :: infoStandardArea(#{password},${password})"/>
            </div>
            <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateAreaWithHours(#{closureDate},${request.expirationDate})"/>
            </div>
           <div data-th-if="(${totalMaxDepotSize})">
                    <th:block data-th-replace="layout :: infoStandardArea(#{depotSize},${totalMaxDepotSize})"/>
            </div>
            <div data-th-if="(${isCollective})">
               <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsOfDepot},${recipients})"/>
            </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='buttonMsg = Accès
closureDate = Date de clôture
depotSize = Taille
mainMsg = <b>{0} {1}</b> vous invite à déposer des fichiers via cette Invitation de Dépôt: <b>{2}</b>.
msgAlt = L''''invitation de dépôt {0} de {1} {2} est désormais active.
msgFrom = Le message de
msgProtected = Vous pouvez déverrouiller le dépôt en suivant le lien ci-dessous et en saisissant le mot de passe fourni.
msgUnProtected = Vous pouvez y accéder en suivant le lien ci-dessous.
name = {0} {1}
password = Mot de passe
recipientsOfDepot = Destinataires
subject = {0} {1} vous invite à déposer des fichiers dans le dépôt : {2}',messages_english='buttonMsg = Access
closureDate = Closure date
depotSize = Allowed size
mainMsg = <b>{0} {1}</b> invited you to its upload request : <b>{2}</b>.
msgFrom = Message from
msgAlt = The upload request {0} from {1} {2} is now active.
msgProtected = Unlock it by following the link below and entering the password.
msgUnProtected = Access it by following the link below.
name = {0} {1}
password = Password
recipientsOfDepot = Recipients
subject = {0} {1} invited you to its upload request : {2}',messages_russian='buttonMsg = Доступ
closureDate = Дата закрытия
depotSize = Допустимый размер
mainMsg = <b>{0} {1}</b> пригласил вас в свой запрос загрузки <b>{2}</b>.
msgFrom = Сообщение от
msgAlt = Репозиторий {0} из {1} {2} теперь активен.
msgProtected = Разблокируйте его, перейдя по ссылке ниже и введя пароль.
msgUnProtected = Получите доступ, перейдя по ссылке ниже. 
name = {0} {1}
password = Пароль
recipientsOfDepot = Получатель
subject = {0} {1}  пригласил вас в свой запрос загрузки {2}',messages_vietnamese='buttonMsg = Truy cập 
closureDate = Ngày đóng 
depotSize = Dung lượng cho phép 
mainMsg = <b>{0} {1}</b> đã mời bạn vào yêu cầu tải : <b>{2}</b>.
msgFrom = Tin nhắn từ 
msgAlt = Yêu cầu tải {0} từ {1} {2} được kích hoạt bây giờ.
msgProtected = mở khóa bằng việc mở đường dẫn dưới đây và điền mật khẩu 
msgUnProtected = Truy cập bằng việc mở đường dẫn dưới đây 
name = {0} {1}
password = Mật khẩu 
recipientsOfDepot = Người nhận 
subject = {0} {1} đã mời bạn vào yêu cầu tải : {2}' WHERE id=16;
UPDATE mail_content SET subject='[( #{subject(${requestOwner.firstName}, ${requestOwner.lastName},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection(~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${subject})}">
                     Peter WILSON has closed prematurely his Upload Request Depot labeled : subject.
                     </span>
                  </p>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
               <th:block data-th-replace="layout :: infoFileLinksListingArea(#{filesInURDepot},${documents}, false)"/>
            <div data-th-if="(${isCollective})">
               <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsOfDepot},${recipients})"/>
            </div>
            <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateAreaWithHours(#{closureDate},${request.expirationDate})"/>
            </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='closureDate = Date de clôture
filesInURDepot = Fichiers
mainMsg = <b>{0} {1}</b> a fermé son invitation de dépôt : {2}.
recipientsOfDepot = Destinataires
subject = {0} {1} a fermé l''''invitation de dépôt : {2}',messages_english='closureDate = Closure date
filesInURDepot = Files
mainMsg = <b>{0} {1}</b> has closed the upload request labeled : {2}.
recipientsOfDepot = Recipients
subject = {0} {1} has closed his upload request : {2}',messages_russian='closureDate = Дата закрытия
filesInURDepot = Файлы
mainMsg = <b>{0} {1}</b> закрыл запрос загрузки {2}.
recipientsOfDepot = Получатели
subject = {0} {1} закрыл запрос загрузки {2}',messages_vietnamese='closureDate = Ngày đóng 
filesInURDepot = Files
mainMsg = <b>{0} {1}</b> đã đóng yêu cầu tải được dán nhãn : {2}.
recipientsOfDepot = Recipients
subject = {0} {1} đã đóng yêu cầu tải của anh  : {2}' WHERE id=21;
UPDATE mail_content SET subject='[( #{subject(${requestRecipient.mail},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <section id="main-content">
    <!--/* Upper main-content*/-->
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-if="(${isCollective})" data-th-utext="#{collectiveBeginningMainMsg(${requestRecipient.mail},${subject})}"></span>
          <span data-th-if="!(${isCollective})"
                data-th-utext="#{individualBeginningMainMsg(${requestRecipient.mail},${subject})}"></span>
          <span data-th-if="(${documentsCount} == 1)" data-th-utext="#{endingMainMsgSingular}"></span>
          <span data-th-if="(${documentsCount} > 1)" data-th-utext="#{endingMainMsgPlural(${documentsCount})}"></span>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-if="(${isCollective})">
       <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsURequest},${recipients})"/>
    </th:block>
    <th:block data-th-replace="layout :: infoFileLinksListingArea(#{filesInURDepot},${documents}, false)"/>
    <th:block data-th-replace="layout :: infoStandardArea(#{fileSize}, ${totalSize})"/>
    <th:block data-th-if="(${request.authorizedFiles})">
       <th:block data-th-replace="layout :: infoStandardArea(#{numFilesInDepot},
        #{uploadedOverTotal(${documentsCount},${request.authorizedFiles})})"/>
    </th:block>
    <th:block data-th-if="(${!request.authorizedFiles})">
       <th:block data-th-replace="layout :: infoStandardArea(#{numFilesInDepot},
        #{totalUploaded(${documentsCount})})"/>
    </th:block>
    <th:block data-th-replace="layout :: infoDateAreaWithHours(#{invitationCreationDate},${request.activationDate})"/>
    <th:block data-th-replace="layout :: infoDateAreaWithHours(#{invitationClosureDate},${request.expirationDate})"/>
  </section> <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='endingMainMsgPlural =  Il y a <b> {0} fichiers </b> dans le dépôt.
endingMainMsgSingular = Il y a  <b>1 fichier </b> dans le dépôt.
filesInURDepot =  Fichiers déposés
fileSize =  Taille
collectiveBeginningMainMsg = <b>{0}</b> a clôturé votre Invitation de Dépôt <b>{1}</b>.
invitationClosureDate = Date de clôture
invitationCreationDate = Date d''''activation
numFilesInDepot = Nombre de fichiers déposés
recipientsURequest = Destinataires
subject = {0} a clôturé votre invitation de dépôt : {1}
individualBeginningMainMsg = <b>{0}</b> a clôturé votre Invitation de Dépôt <b>{1}</b>.
uploadedOverTotal = {0} / {1} fichiers
totalUploaded = {0} files',messages_english='endingMainMsgPlural = There are a total of <b> {0} files </b> in the upload request.
endingMainMsgSingular =  There is <b>1 file </b> in the upload request.
filesInURDepot = Files uploaded
fileSize =  Total filesize
collectiveBeginningMainMsg = <b>{0}</b> has closed your collective Upload Request <b>{1}</b>.
invitationClosureDate = Closure date
invitationCreationDate = Activation date
numFilesInDepot = Total uploaded files
recipientsURequest = Recipients
subject =  {0} has closed your Upload Request: {1}
individualBeginningMainMsg  = <b>{0}</b> has closed your Upload Request <b>{1}</b>.
uploadedOverTotal = {0} / {1} files
totalUploaded = {0} files',messages_russian='endingMainMsgPlural = Всего в хранилище <b> {0} файлов </b>.
endingMainMsgSingular =  Всего в хранилище <b>1 файл </b.
filesInURDepot = Файлы загружены
fileSize =  Общий размер файла
collectiveBeginningMainMsg = <b>{0}</b> закрыл ваше групповое хранилище для файлов запроса загрузки <b>{1}</b>.
invitationClosureDate = Дата закрытия
invitationCreationDate = Дата активации
numFilesInDepot = Всего загруженных файлов
recipientsURequest = Получатели
subject =  {0} закрыл ваше хранилище для файлов запроса загрузки {1}
individualBeginningMainMsg  = <b>{0}</b> закрыл ваше хранилище для файлов запроса загрузки <b>{1}</b>.
uploadedOverTotal = {0} / {1} файлов
totalUploaded = {0} файлов' ,messages_vietnamese='endingMainMsgPlural = Có tổng số <b> {0} files </b> trong yêu cầu tải lên.
endingMainMsgSingular = Có <b>1 file </b> in trong yêu cầu tải lên. 
filesInURDepot = Files được tải lên 
fileSize =  Tổng dung lượng file. 
collectiveBeginningMainMsg = <b>{0}</b> đã đóng yêu cầu tải lên chung của bạn <b>{1}</b>.
invitationClosureDate = Ngày đóng 
invitationCreationDate = Ngày kích hoạt
numFilesInDepot = Tổng số file đã tải lên 
recipientsURequest = Người nhận 
subject =  {0} đã đóng yêu cầu tải của bạn: {1}
individualBeginningMainMsg  = <b>{0}</b> đã đóng yêu cầu tải của bạn <b>{1}</b>.
uploadedOverTotal = {0} / {1} files
totalUploaded = {0} files' WHERE id=14;
UPDATE mail_content SET subject='[(#{subject(${requestOwner.firstName}, ${requestOwner.lastName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/*  Upper main-content */-->
  <section id="main-content">
    <!--/* If the sender has added a  customized message */-->
    <th:block data-th-if="${!#strings.isEmpty(body)}">
      <div th:replace="layout :: contentMessageSection(~{::#message-title}, ~{::#message-content})">
        <span id="message-title">
          <span data-th-text="#{msgFrom}">You have a message from</span>
          <b data-th-text="#{name(${requestOwner.firstName} , ${requestOwner.lastName})}">Peter Wilson</b> :
        </span>
        <span id="message-content" data-th-text="*{body}" style="white-space: pre-line;">
          Hi Amy,<br>
          As agreed,  i am sending you the report as well as the related files. Feel free to contact me if need be. <br>Best regards, Peter.
        </span>
      </div>
    </th:block>
    <!--/* End of customized message */-->
    <!--/* main-content container */-->
    <div th:replace="layout :: contentUpperSection(~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings for external or internal user */-->
        <div>
          <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
        </div>
          <!--/* End of Greetings for external or internal recipient */-->
        <!--/* Main email  message content*/-->
        <p>
                 <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${subject})}">
                     Peter Wilson invited  you to upload  some files in the Upload Request depot labeled : subject.
                </span>
 <span th:with="df=#{customDate}" data-th-text="${#dates.format(request.activationDate,df)}">7th of November, 2018</span>
        </p>
        <!--/* End of Main email message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container */-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
  <div data-th-if="${!#strings.isEmpty(request.activationDate)}">
               <th:block data-th-replace="layout :: infoDateAreaWithHours(#{activationDate},${request.activationDate})"/>
            </div>
     <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateAreaWithHours(#{closureDate},${request.expirationDate})"/>
            </div>
       <div data-th-if="(${totalMaxDepotSize})">
               <th:block data-th-replace="layout :: infoStandardArea(#{depotSize},${totalMaxDepotSize})"/>
         </div>
  <div data-th-if="(${isCollective})">
         <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsOfDepot},${recipients})"/>
    </div>
  </section>  <!--/* End of Secondary content for bottom email section */-->
  </div>
</body>
</html>',messages_french='activationDate = Ouverture du dépôt le
closureDate = Date de clôture
customDate= d MMMM yyyy.
depotSize = Taille autorisée
mainMsg = <b>{0} {1}</b> a créé une Invitation de dépôt <b>{2}</b>, qui sera ouverte le
msgFrom = Le message de
name = {0} {1}
recipientsOfDepot = Destinataires
subject = {0} {1} vous a créé une Invitation de Dépôt',messages_english='activationDate = Activation date
closureDate = Closure date
customDate= MMMM d, yyyy.
depotSize = Allowed size
mainMsg = <b>{0} {1}</b> has invited you to access to his Upload Request <b>{2}</b>, sets to open
msgFrom = Message from
name = {0} {1}
recipientsOfDepot = Recipients
subject = {0} {1} has sent an invitation to access to his Upload Request.',messages_russian='activationDate = Дата активации
closureDate = Дата закрытия
customDate= MMMM d, yyyy.
depotSize = Допустимый размер
mainMsg = <b>{0} {1}</b> открыл для вас доступ к его запросу загрузки <b>{2}</b>, созданному
msgFrom = Сообщение от
name = {0} {1}
recipientsOfDepot = Получатели
subject = {0} {1} открыл для вас доступ к его запросу загрузки.',messages_vietnamese='activationDate = Ngày kích hoạt 
closureDate = Ngày đóng 
customDate= MMMM d, yyyy.
depotSize = Dung lượng cho phép
mainMsg = <b>{0} {1}</b> đã mời bạn truy cập Yêu cầu tải lên của anh ấy <b>{2}</b>, sẽ được mở vào 
msgFrom = Tin nhắn từ 
name = {0} {1}
recipientsOfDepot = Người nhận 
subject = {0} {1} đã gửi lời mời truy cập Yêu cầu tải lên của anh ấy.' WHERE id=20;
UPDATE mail_content SET subject='[(#{subject(${requestOwner.firstName}, ${requestOwner.lastName},${document.name})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${document.name},${subject})}">
                 Peter WILSON has deleted the file my-file.txt from the depot : subject
                     </span>
                  </p>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <th:block data-th-replace="layout :: infoDateArea(#{deletionDate},${deletionDate})"/>
            <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateArea(#{closureDate},${request.expirationDate})"/>
            </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='closureDate = Dépôt disponible jusqu''''au
deletionDate = Fichier supprimé le
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b>a supprimé le fichier  <b>{2} </b> de  l''''Invitation de Dépôt : {3}
subject = {0} {1} a supprimé {2} du dépôt',messages_english='closureDate = Depot closure date
deletionDate = File deletion date
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> has deleted the file <b>{2} </b>from the upload request  : {3}.
subject = {0} {1} has deleted {2} from the upload request',messages_russian='closureDate = Срок действия загрузки
deletionDate = Дата удаления
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> удалил файл <b>{2} </b> из хранилища {3}.
subject = {0} {1} удалил файл {2} из хранилища',messages_vietnamese='closureDate = Ngày đóng 
deletionDate = Ngày xóa file 
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> đã xóa file <b>{2} </b>từ yêu cầu tải lên  : {3}.
subject = {0} {1} đã xóa {2} từ yêu cầu tải lên' WHERE id=24;
UPDATE mail_content SET subject='[( #{subject(${requestRecipient.mail},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <section id="main-content">
    <!--/* Upper main-content*/-->
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
  <span  data-th-utext="#{mainMsg(${requestRecipient.mail},${deleted.name},${subject})}"></span>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
     <th:block data-th-replace="layout :: infoDateArea(#{invitationCreationDate},${request.activationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationClosureDate},${request.expirationDate})"/>
  </section> <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='invitationClosureDate = Date d''''expiration
invitationCreationDate = Date d''''activation
mainMsg = <b>{0}</b> a supprimé le fichier <b> {1} </b>de votre Invitation de Dépôt <b>{2}</b>.
subject =  {0} a supprimé un fichier de votre invitation de dépôt {1}',messages_english='invitationClosureDate = Closure date
invitationCreationDate = Activation date
mainMsg = <b>{0}</b> has deleted the file <b> {1} </b>from your Upload Request <b>{2}</b>.
subject = {0} has deleted a file from the Upload Request {1}',messages_russian='invitationClosureDate = Дата закрытия
invitationCreationDate = Дата активации
mainMsg = <b>{0}</b> удалил файл <b> {1} </b> из вашего запроса загрузки <b>{2}</b>.
subject = {0} удалил файл из загрузки {1}',messages_vietnamese='invitationClosureDate = Ngày đóng 
invitationCreationDate = Ngày kích hoạt 
mainMsg = <b>{0}</b> đã xóa file <b> {1} </b>từ yêu cầu tảu lên của bạn <b>{2}</b>.
subject = {0} đã xóa 1 file từ Yêu cầu tải lên {1}' WHERE id=15;
UPDATE mail_content SET subject='[( #{subject(${requestOwner.firstName}, ${requestOwner.lastName},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection(~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${subject})}">
                     Peter Wilson invited  you to upload  some files in the Upload Request depot labeled : subject.
                     </span>
                     <br/>
                     <span data-th-text="#{msgProtected}">In order to access it click the link below and enter the provided password.</span>
                  </p>
                  <th:block data-th-replace="layout :: actionButtonLink(#{buttonMsg},${requestUrl})"/>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <th:block data-th-replace="layout :: infoStandardArea(#{password},${password})"/>
            <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateArea(#{closureDate},${request.expirationDate})"/>
            </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='buttonMsg = Accès au dépôt
closureDate = Dépôt disponible jusqu''''au
mainMsg = <b>{0} {1}</b> a modifié le mot de passe d''''accès à l''''Invitation de Dépôt : {2}.
msgProtected = Vous trouverez ci-dessous le nouveau mot de passe ainsi que le lien d''''accès.
password = Mot de passe
subject = {0} {1} vous envoie le nouveau mot de passe du dépôt : {2}',messages_english='buttonMsg = Access to the depot
closureDate = Depot closure date
mainMsg = <b>{0} {1}</b> has changed the password of the Upload Request : {2}
msgProtected = You may find the new password below as well as the access link.
password = Password
subject = {0} {1} sent you the new password for the Upload Request: {2}',messages_russian='buttonMsg = Доступ к загрузке
closureDate = Дата закрытия загрузки
mainMsg = <b>{0} {1}</b> изменил пароль к загрузке {2}
msgProtected = Новый пароль и доступ к загрузке доступны ниже.
password = Пароль
subject = {0} {1} отправил вам новый пароль к загрузке {2}',messages_vietnamese='buttonMsg = Truy cập 
closureDate = Ngày đóng 
mainMsg = <b>{0} {1}</b> đã thay đổi mật khẩu của yêu cầu tải lên  : {2}
msgProtected = Bạn có thể sử dụng mật khẩu mới dưới đây khi truy cập đường dẫn.
password = Mật khẩu
subject = {0} {1} đã gửi cho bạn mật khẩu mới cho yêu cầu tải lên: {2}' WHERE id=19;
UPDATE mail_content SET subject='[(#{subject(${requestOwner.firstName}, ${requestOwner.lastName},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${subject})}">
                     Peter WILSON has deleted your access to the depot : : subject.
                     </span>
                  </p>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <th:block data-th-replace="layout :: infoDateArea(#{deletionDate},${deletionDate})"/>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='deletionDate = Accès au dépôt retiré le
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b>  a retiré votre accès au dépôt de l''''invitation intitulée : {2}.
subject = {0} {1} a supprimé votre accès au dépôt : {2}',messages_english='deletionDate = Deletion date
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> has removed your access to the Upload Request : {2}.
subject = {0} {1} has removed your access to the Upload Request : {2}',messages_russian='deletionDate = Дата удаления
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> закрыл ваш доступ к загрузке {2}.
subject = {0} {1} закрыл ваш доступ к загрузке {2}',messages_vietnamese='deletionDate = Ngày xóa 
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> đã xóa quyền truy cập của bạn đến yêu cầu tải : {2}.
subject = {0} {1} đã xóa quyền truy cập của bạn đến yêu cầu tải : {2}' WHERE id=22;
UPDATE mail_content SET subject='[(#{subject(${requestOwner.firstName}, ${requestOwner.lastName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* If the sender has added a  customized message */-->
            <th:block data-th-if="${!#strings.isEmpty(body)}">
               <div th:replace="layout :: contentMessageSection(~{::#message-title}, ~{::#message-content})">
                  <span id="message-title">
                  <span data-th-text="#{msgFrom}">You have a message from</span>
                  <b data-th-text="#{name(${requestOwner.firstName}, ${requestOwner.lastName})}">Peter Wilson</b> :
                  </span>
                  <span id="message-content" data-th-text="*{body}" style="white-space: pre-line;">
                  Hi Amy,<br>
                  As agreed,  i am sending you the report as well as the related files. Feel free to contact me if need be. <br>Best regards, Peter.
                  </span>
               </div>
            </th:block>
            <!--/* End of customized message */-->
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection(~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName},${subject})}">
                     Peter Wilson reminds you that he still has not received the requested files. 
                     </span>
                     <span data-th-utext="#{mainMsgEnd}">
                     You can upload your files in the provided depot made available to you labeled  subject.
                     </span>
                     <!--/* Check if the external user has a password protected file share */-->
                     <br/>
                     <span data-th-text="#{msgUnProtected}">In order to access it click the link below.</span>
                  </p>
                  <th:block data-th-replace="layout :: actionButtonLink(#{buttonMsg},${requestUrl})"/>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <div data-th-if="${!#strings.isEmpty(request.expirationDate)}">
               <th:block data-th-replace="layout :: infoDateArea(#{closureDate},${request.expirationDate})"/>
            </div>
            <div data-th-if="(${totalMaxDepotSize})">
                 <th:block data-th-replace="layout :: infoStandardArea(#{depotSize},${totalMaxDepotSize})"/>
            </div>
            <div data-th-if="(${isCollective})">
               <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsOfDepot},${recipients})"/>
            </div>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='buttonMsg = Accès
closureDate = Date de clôture
depotSize = Taille
mainMsg = <b>{0} {1}</b> aimerais vous rappeller de déposer vos fichiers sur: <b>{2}</b>.
mainMsgEnd =
msgFrom =  Le message de
msgUnProtected = Pour accéder au dépôt, suivez le lien ci-dessous.
name = {0} {1}
recipientsOfDepot = Destinataires
subject = {0} {1} attend toujours des fichiers de votre part',messages_english='buttonMsg = Access
closureDate = Closure date
depotSize = Size
mainMsg = <b>{0} {1}</b> kindly reminds you to upload your files on: <b>{2}</b>.
mainMsgEnd =
msgFrom = Message from
msgUnProtected = In order to upload your files, please follow the link below.
name = {0} {1}
recipientsOfDepot = Recipients
subject = {0} {1} is still awaiting your files',messages_russian='buttonMsg = Доступ
closureDate = Дата закрытия
depotSize = Размер
mainMsg = <b>{0} {1}</b> напоминает вам о загрузке ваших файлов on: <b>{2}</b>.
mainMsgEnd =
msgFrom = Сообщение от
msgUnProtected = Для того, чтобы загрузить ваши файлы, пожалуйста, перейдите по ссылке ниже.
name = {0} {1}
recipientsOfDepot = Получатели
subject = {0} {1} ожидает ваши файлы' ,messages_vietnamese='buttonMsg = Truy cập 
closureDate = Ngày đóng 
depotSize = Dung lượng 
mainMsg = <b>{0} {1}</b> nhắc bạn hãy tải file của bạn lên: <b>{2}</b>.
mainMsgEnd =
msgFrom = Tin nhắn từ 
msgUnProtected = Để tải file của bạn, mở link dưới đây
name = {0} {1}
recipientsOfDepot = Người nhận 
subject = {0} {1} đang đợi tài liệu của bạn' WHERE id=18;
UPDATE mail_content SET subject='[( #{subject(${requestRecipient.mail},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div
  th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content */-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p style="font-size: 14px;font-weight: bold;color: #df5656;margin-bottom: 7px;" data-th-utext="#{mainMsgTitle}">
          You have no available space.</p>
        <p>
          <span data-th-utext="#{mainMsg(${requestRecipient.mail})}"></span>
        </p> <!--/* End of Main email  message content*/-->
      <!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper  main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-if="(${maxDepositSize != null})">
      <th:block data-th-replace="layout :: infoStandardArea(#{maxUploadDepotSize},${maxDepositSize})"/>
    </th:block>
    <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsURequest},${recipients})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationCreationDate},${request.activationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationClosureDate},${request.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='invitationClosureDate = Date de clôture
invitationCreationDate = Date d''''activation
mainMsg =  <b>{0}</b>  n''''a pas pu déposer des fichiers dans le dépôt car il n''''y a plus d''''espace disponible dans votre Espace Personnel. Veuillez s''''il vous plait libérez de l''''espace.
mainMsgTitle = Vous n''''avez plus d''''espace disponible.
maxUploadDepotSize =  Taille total du dépôt
recipientsURequest = Destinataires
subject =  {0}  n''''a pu déposer un fichier car il n''''y a plus d''''espace disponible',messages_english='invitationClosureDate = Closure date
invitationCreationDate = Activation date
mainMsg =  <b>{0}</b> is not able to upload any file, since there is no more space available in your Personal Space. Please free up some space.
mainMsgTitle = No more space available.
maxUploadDepotSize = Maximum size of the Upload Request
recipientsURequest = Recipients
subject =  {0} could not upload a file since there is no more space available',messages_russian='invitationClosureDate = Дата закрытия
invitationCreationDate = Дата активации
mainMsg =  <b>{0}</b> не может загрузить файлы, так как в вашем личном пространстве недостаточно места. Пожалуйста, удалите некоторые файлы, чтобы освободить место.
mainMsgTitle = Недостаточно свободного места.
maxUploadDepotSize = Максимальный размер загрузки
recipientsURequest = Получатели
subject =  {0} не может загрузить файл, так как недостаточно свободного места' ,messages_vietnamese='invitationClosureDate = Ngày đóng 
invitationCreationDate = Ngày kích hoạt 
mainMsg =  <b>{0}</b> không thể tải lên file bởi vì không còn dung lượng trống trong Personal Space của bạn. Hãy thêm dung lượng. 
mainMsgTitle = Không còn dung lượng trống 
maxUploadDepotSize = Dung lượng tối đa của yêu cầu tải lên. 
recipientsURequest = Người nhận
subject =  {0} không thể tải file lên vì không còn dung lượng trống'WHERE id=11;
UPDATE mail_content SET subject='[(#{subject(${subject.value})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <head data-th-replace="layout :: header"></head>
   <body>
      <div
         th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
         <!--/*  Upper main-content */-->
         <section id="main-content">
            <!--/* main-content container */-->
            <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
               <div id="section-content">
                  <!--/* Greetings for external or internal user */-->
                  <div>
                     <th:block data-th-replace="layout :: greetings(${requestRecipient.mail})"/>
                  </div>
                  <!--/* End of Greetings for external or internal recipient */-->
                  <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${requestOwner.firstName},${requestOwner.lastName}, ${subject.value})}">
                     </span>
                     <span data-th-utext="#{secondaryMsg}">
                     </span>
                  </p>
                  <!--/* If the sender has added a  customized message */-->
                  <th:block data-th-if="(${message.modified})">
                     <div th:replace="layout :: contentMessageSection( ~{::#message-title}, ~{::#message-content})">
                        <span id="message-title">
                        <span data-th-text="#{msgFrom}">You have a message from</span>
                        <b data-th-text="#{name(${requestOwner.firstName} , ${requestOwner.lastName})}">Peter Wilson</b> :
                        </span>
                        <span id="message-content" data-th-text="*{message.value}" style="white-space: pre-line;">
                        Hi Amy,<br>
                        As agreed,  i am sending you the report as well as the related files. Feel free to contact me if need be. <br>Best regards, Peter.
                        </span>
                     </div>
                  </th:block>
                  <th:block data-th-replace="layout :: actionButtonLink(#{buttonMsg},${requestUrl})"/>
                  <!--/* End of Main email message content*/-->
               </div>
               <!--/* End of section-content*/-->
            </div>
            <!--/* End of main-content container */-->
         </section>
         <!--/* End of upper main-content*/-->
         <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
            <span data-th-if="(${expiryDate.modified})">
               <th:block data-th-replace="layout :: infoDateItemsToUpdate(#{expiryDate}, #{expiryDateParamAdded}, #{expiryDateParamDeleted}, ${expiryDate.oldValue}, ${expiryDate.value})"/>
            </span>
            <span data-th-if="(${activationDate.modified})">
               <th:block data-th-replace="layout :: infoDateItemsToUpdate(#{activationDate}, #{activationDateParamAdded}, #{activationDateParamDeleted}, ${activationDate.oldValue}, ${activationDate.value})"/>
            </span>
            <span data-th-if="(${closureRight.modified})">
               <th:block data-th-replace="layout :: infoItemsToUpdate(#{closureRight}, #{closureRightParamAdded}, #{closureRightParamDeleted}, ${closureRight.oldValue}, ${closureRight.value})"/>
            </span>
            <span data-th-if="(${deletionRight.modified})">
               <th:block data-th-replace="layout :: infoItemsToUpdate(#{deletionRight}, #{deletionRightParamAdded}, #{deletionRightParamDeleted}, ${deletionRight.oldValue}, ${deletionRight.value})"/>
            </span>
            <span data-th-if="(${maxFileSize.modified})">
               <th:block data-th-replace="layout :: infoItemsToUpdate(#{maxFileSize}, #{maxFileSizeParamAdded}, #{maxFileSizeParamDeleted}, ${maxFileSize.oldValue}, ${maxFileSize.value})"/>
            </span>
            <span data-th-if="(${maxFileNum.modified})">
               <th:block data-th-replace="layout :: infoItemsToUpdate(#{maxFileNum}, #{maxFileNumParamAdded}, #{maxFileNumParamDeleted}, ${maxFileNum.oldValue}, ${maxFileNum.value})"/>
            </span>
            <span data-th-if="(${totalMaxDepotSize.modified})">
               <th:block data-th-replace="layout :: infoItemsToUpdate(#{depotSize}, #{totalMaxDepotSizeParamAdded}, #{totalMaxDepotSizeParamDeleted}, ${totalMaxDepotSize.oldValue}, ${totalMaxDepotSize.value})"/>
            </span>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
      </div>
   </body>
</html>',messages_french='activationDate = Date d''''activation
closureRight = Droits de clôture
deletionRight = Droits de suppression
depotSize = Taille du dépôt
expiryDate = Date de clôture
enableNotification = Activation des notifications
mainMsg =   <b> {0} <span style="text-transform:uppercase">{1}</span> </b>  a modifié des paramètres liés à l''''Invitation de dépôt <b>{2}</b>.
maxFileNum = Nombre de Fichiers
maxFileSize = Taille autorisée
msgFrom = Nouveau message de
name = {0} {1}
nameOfDepot: Nom du dépôt
secondaryMsg = Les modifications sont listées ci-dessous.
subject = Modification des paramètres du dépôt : {0}
buttonMsg = Accès,
maxFileSizeParamAdded = Paramètre de la taille de fichier autorisée ajouté
maxFileSizeParamDeleted = Paramètre de la taille de fichier autorisée annulé, ancienne valeur
maxFileNumParamAdded = Paramètre de nombre maximal des fichiers ajouté
maxFileNumParamDeleted = Paramètre de nombre maximal des fichiers annulé, ancienne valeur
totalMaxDepotSizeParamAdded = Paramètre de la taille maximale des fichiers déposés ajouté
totalMaxDepotSizeParamDeleted = Paramètre de la taille maximale des fichiers annulé, ancienne valeur
deletionRightParamAdded = Paramètre de droit de suppression ajouté
deletionRightParamDeleted = Paramètre de droit de suppression annulé, ancienne valeur
closureRightParamAdded = Paramètre de droits de clôture ajouté
closureRightParamDeleted = Paramètre de droits de clôture annulé, ancienne valeur
activationDateParamAdded = Paramètre de date d''''activation ajouté
activationDateParamDeleted = Paramètre de date d''''activation annulé, ancienne valeur
expiryDateParamAdded = Paramètre d''''expiration ajouté
expiryDateParamDeleted = Paramètre d''''expiration annulé, ancienne valeur',messages_english='activationDate = Activation date
closureRight = Closure rights
deletionRight = Deletion rights
depotSize = Repository size
expiryDate = Closure date
enableNotification = Enable notifications
mainMsg =   <b> {0} <span style="text-transform:uppercase">{1}</span> </b>  has updated some settings related to the Upload Request <b>{2}</b>.
maxFileNum = File number
maxFileSize = File size
msgFrom =  New message from
name = {0} {1}
nameOfDepot: Name of the Upload Request
secondaryMsg = Updated settings are listed below.
subject = Updated Settings for Upload Request : {0}
buttonMsg = Access
maxFileSizeParamAdded = Max File size parameter added
maxFileSizeParamDeleted = Max File size parameter canceled, last value
maxFileNumParamAdded = Max File number parameter added
maxFileNumParamDeleted = Max File number parameter deleted, last value
totalMaxDepotSizeParamAdded = Max total deposite size parameter added
totalMaxDepotSizeParamDeleted = Max total deposite size parameter, last value
deletionRightParamAdded = Deletion rights parameter added
deletionRightParamDeleted = Deletion rights parameter canceled
closureRightParamAdded = Closure right parameter added
closureRightParamDeleted = Closure right parameter added, last value
activationDateParamAdded = Activation date parameter added
activationDateParamDeleted = Activation date parameter added, last value
expiryDateParamAdded = Expiration parameter added
expiryDateParamDeleted = Expiration parameter canceled, last value',messages_russian='activationDate = Дата активации
closureRight = Права закрытия
deletionRight = Права удаления
depotSize = Размер репозитория
expiryDate = Дата закрытия
enableNotification = Разрешить уведомления
mainMsg =   <b> {0} <span style="text-transform:uppercase">{1}</span> </b>  обновил некоторые настройки запроса загрузки <b>{2}</b>.
maxFileNum = Номер файла
maxFileSize = Размер файла
msgFrom =  Новое сообщение от
name = {0} {1}
nameOfDepot: Название загрузки
secondaryMsg = Список обновленных настроек доступен ниже.
subject = Обновленные настройки для запроса загрузки {0}
buttonMsg = Доступ
maxFileSizeParamAdded = Добавлен параметр максимального размера файла
maxFileSizeParamDeleted = Параметр максимального размера файла удален, последнее значение
maxFileNumParamAdded = Добавлен параметр максимального количества файлов
maxFileNumParamDeleted = Параметр максимального количества файлов удален, последнее значение
totalMaxDepotSizeParamAdded = Добавлен параметр максимального общего размера депозита
totalMaxDepotSizeParamDeleted = Параметр максимального общего размера депозита удален, последнее значение
deletionRightParamAdded = Добавлен параметр прав на удаление
deletionRightParamDeleted = Параметр прав на удаление отменен
closureRightParamAdded = Добавлен параметр прав на закрытие
closureRightParamDeleted = Параметр прав на закрытие удален
activationDateParamAdded = Добавлен параметр даты активации
activationDateParamDeleted = Добавлен параметр даты активации, последнее значение
expiryDateParamAdded = Добавлен параметр срока действия
expiryDateParamDeleted = Параметр срока действия удален, последнее значение ',messages_vietnamese='activationDate = Ngày kích hoạt
closureRight = Quyền đóng 
deletionRight = Quyền xóa 
depotSize = kích cỡ thư mục 
expiryDate = NGày đóng 
enableNotification = Bật thông báo 
mainMsg =   <b> {0} <span style="text-transform:uppercase">{1}</span> </b>  đã cập nhật một số cài đặt liên quan đến yêu cầu tải  <b>{2}</b>.
maxFileNum = Số filte 
maxFileSize = Khích thước size 
msgFrom =  Tin nhắn mới từ 
name = {0} {1}
nameOfDepot: Tên yêu cầu tải
secondaryMsg = Các chỉnh sửa cài đặt được liệt kê dưới đây. 
subject = Các cài đặt của yêu cầu tải đã được chỉnh sửa: {0}
buttonMsg = Truy cập
maxFileSizeParamAdded = Tham số dung lượng file tối đa đã được thêm vào 
maxFileSizeParamDeleted = Tham số dung lượng file tối đa đa bị hủy, giá trị cuối cùng
maxFileNumParamAdded = Tham số số lượng file tối đa đã được thêm vào 
maxFileNumParamDeleted = Tham số số lượng file tối đa đã bị hủy, giá trị cuối cùng
totalMaxDepotSizeParamAdded = Tham số tổng dung lượng file tối đa đã được thêm vào 
totalMaxDepotSizeParamDeleted = Tham số tổng dung lượng file tối đa đã bị hủy, giá trị cuối cùng
deletionRightParamAdded = Tham số quyền xóa đã được thêm vào 
deletionRightParamDeleted = Tham số quyền xóa đã bị hủy 
closureRightParamAdded = Tham số quyền đóng đã được thêm vào 
closureRightParamDeleted = Tham số quyền đóng đã bị hủy, last value
activationDateParamAdded = Tham số ngày kích hoạt đã được thêm vào 
activationDateParamDeleted = Tham số ngày kích hoạt đã bị hủy, giá trị cuối cùng 
expiryDateParamAdded = Tham số ngày hết hạn đã được thêm vào
expiryDateParamDeleted = Tham số ngày hết hạn đã bị hủy, giá trị cuối cùng' WHERE id=23;
UPDATE mail_content SET subject='[( #{subject(${requestRecipient.mail},${document.name},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{beginningMainMsg(${requestRecipient.mail})}"></span>
          <span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${document.name}" th:href="@{${document.href}}" >
                  filename.ext
             </a>
          </span>
          <span data-th-utext="#{endingMainMsg(${requestRecipient.mail})}"></span>
          <th:block   data-th-replace="layout :: actionButtonLink(#{buttonLabel},${requestUrl})"/>
        </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoDateArea(#{fileUploadedThe},${document.creationDate})"/>
    <th:block data-th-replace="layout :: infoStandardArea(#{fileSize},${document.size})"/>
 <th:block data-th-if="(${request.authorizedFiles})">
      <th:block data-th-replace="layout :: infoStandardArea(#{numFilesInDepot},
         #{uploadedOverTotal(${request.uploadedFilesCount},${request.authorizedFiles})})"/>
 </th:block>
 <th:block data-th-if="(${!request.authorizedFiles})">
      <th:block data-th-replace="layout :: infoStandardArea(#{numFilesInDepot},
         #{totalUploaded(${request.uploadedFilesCount})})"/>
 </th:block>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationCreationDate},${request.activationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationClosureDate},${request.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='endingMainMsg = dans votre Invitation de Dépôt.
fileSize =  Taille du fichier
buttonLabel = Voir
fileUploadedThe= Fichier déposé le
invitationClosureDate = Date de clôture
invitationCreationDate = Date d''''activation
beginningMainMsg = <b> {0} </b> vous a déposé le fichier
numFilesInDepot = Nombre de fichiers déposés
subject =  {0}  vous a déposé {1}  dans votre Invitation de Dépôt
uploadedOverTotal = {0} / {1} fichiers
totalUploaded = {0} fichiers',messages_english='endingMainMsg = in your Upload Request
fileSize =  File size
buttonLabel = View
fileUploadedThe = Upload date
invitationClosureDate = Closure date
invitationCreationDate = Activation date
beginningMainMsg =  <b> {0} </b> has uploaded the file
numFilesInDepot = Total uploaded files
subject =  {0}  has uploaded {1}  in your Upload Request
uploadedOverTotal = {0} / {1} files
totalUploaded = {0} files',messages_russian='endingMainMsg = в вашем запросе загрузки
fileSize = Размер файла
buttonLabel = Просмотр
fileUploadedThe = Дата загрузки
invitationClosureDate = Дата закрытия
invitationCreationDate = Дата активации
beginningMainMsg =  <b> {0} </b> загрузил файл
numFilesInDepot = Всего загруженных файлов
subject =  {0}  загрузил {1}  в ваш запрос загрузки
uploadedOverTotal = {0} / {1} файлы
totalUploaded = {0} файлы',messages_vietnamese='endingMainMsg = trong yêu cầu tải lên của bạn
fileSize =  Kích cỡ file 
buttonLabel = Xem 
fileUploadedThe = Ngày tải lên 
invitationClosureDate = Ngày đóng 
invitationCreationDate = Ngày kích hoạt 
beginningMainMsg =  <b> {0} </b> đã tải lên file 
numFilesInDepot = Tổng số file tải lên 
subject =  {0}  đã tải lên {1}  trong yêu cầu tải của bạn 
uploadedOverTotal = {0} / {1} files
totalUploaded = {0} files' WHERE id=10;
UPDATE mail_content SET subject='[# th:if="${warnOwner}"] [( #{subjectForOwner})]
[/]
[# th:if="${!warnOwner}"]
[( #{subjectForRecipient(${requestOwner.firstName},${requestOwner.lastName})})]
[/]
[# th:if="${!#strings.isEmpty(mailSubject)}"]
[( #{formatMailSubject(${mailSubject})})]
[/]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Upper message content for the owner of the upload request */-->
        <th:block data-th-if="(${warnOwner})">
          <!--/* Greetings */-->
          <th:block    data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
          <!--/* End of Greetings  */-->
          <!--/* Main email  message content*/-->
          <p>
            <span  data-th-if="!(${isCollective})"   data-th-utext="#{beginningMainMsgIndividual(${subject},${remainingDays})}"></span>
            <span  data-th-if="(${isCollective})"   data-th-utext="#{beginningMainMsgCollective(${subject},${remainingDays})}"></span>
            <span data-th-if="(${documentsCount} ==  1)"   data-th-utext="#{endingMainMsgSingular}" ></span>
            <span  data-th-if="(${documentsCount} >  1)"   data-th-utext="#{endingMainMsgPlural(${documentsCount})}"></span>
          </p>
        </th:block>
        <!--/* End of Main email  message content*/-->
        <!--/* End of upper message content for owner of the upload request */-->
        <!--/* upper message content for recipients of the upload request */-->
        <th:block data-th-if="(${!warnOwner})" >
          <!--/* Greetings */-->
          <th:block  data-th-replace="layout :: greetings(${requestRecipient.mail})" />
          <!--/* End of Greetings  */-->
          <!--/* Main email  message content*/-->
          <p>
            <span  data-th-utext="#{beginningMainMsgForRecipient(${requestOwner.firstName},${requestOwner.lastName},${subject},${remainingDays})}"></span>
            <span data-th-if="(${request.uploadedFilesCount} ==  1)"   data-th-utext="#{endingMainMsgSingularForRecipient}" ></span>
            <span  data-th-if="(${request.uploadedFilesCount} >  1)"   data-th-utext="#{endingMainMsgSingularForRecipient(${request.uploadedFilesCount})}"></span>
            <th:block   data-th-replace="layout :: actionButtonLink(#{uploadFileBtn},${requestUrl})"/>
          </p>
        </th:block>
        <!--/* End of Main email  message content*/-->
        <!--/* End of upper message content for recipients of the upload request */-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <!--/*Lower message content for the owner of the upload request */-->
    <th:block  data-th-if="(${warnOwner})">
      <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsURequest},${recipients})"/>
      <th:block data-th-replace="layout :: infoFileLinksListingArea(#{filesInURDepot},${documents}, false)"/>
    </th:block>
    <!--/*Lower message content for the owner of the upload request */-->
    <!--/*Lower message content for recipients of the upload request */-->
    <th:block  data-th-if="(${!warnOwner})">
      <th:block  data-th-if="(${isCollective})">
        <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsURequest},${recipients})"/>
        <th:block data-th-replace="layout :: infoFileListWithMyUploadRefs(#{filesInURDepot},${documents})"/>
      </th:block>
      <th:block  data-th-if="!(${isCollective})">
        <th:block data-th-replace="layout :: infoFileLinksListingArea(#{filesInURDepot},${documents}, true)"/>
      </th:block>
    </th:block>
    <!--/* End of lower message content for recipients of the upload request */-->
    <th:block data-th-replace="layout :: infoDateArea(#{invitationActivationDate},${request.activationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationClosureDate},${request.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='beginningMainMsgForRecipient =   L''''invitation de dépôt de <b> {0} <span style="text-transform:uppercase">{1}</span> </b>: :  <b>{2}</b> sera clôturée dans <b>{3} jours</b>
beginningMainMsgCollective =   Votre Invitation de dépôt collective: {0}, sera clôturée dans  <b>{1} jours</b>.
beginningMainMsgIndividual =   Votre Invitation de dépôt individuelle: {0}, sera clôturée dans  <b>{1} jours</b>.
endingMainMsgPlural = Il y a un total de <b> {0} fichiers </b> dans le dépôt.
endingMainMsgPluralForRecipient = et vous avez actuellement envoyé  <b> {0} fichiers </b> dans l''''invitation de dépôt.
endingMainMsgSingular = Il y a au total <b>1 fichier </b> dans le dépôt.
endingMainMsgSingularForRecipient = et vous avez actuellement envoyé  <b>1 fichier </b> dans l''''invitation de dépôt.
filesInURDepot = Fichiers déposés
formatMailSubject = : {0}
invitationActivationDate = Date d''''activation
invitationClosureDate =  Date de clôture
recipientsURequest = Destinataires
subjectForOwner =  Votre invitation de dépôt sera bientôt clôturée
subjectForRecipient = L''''invitation au dépôt de {0} {1} sera bientôt clôturée
uploadFileBtn = Déposer un fichier',messages_english='beginningMainMsgForRecipient = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>''''s upload Request:  <b>{2}</b> is about to reach it''''s end date in <b>{3} days</b>
beginningMainMsgCollective = Your collective upload request: {0}, is about to be closed in  <b>{1} days</b>.
beginningMainMsgIndividual =  Your individual upload request: {0}, is about to be closed in <b>{1} days</b>.
endingMainMsgPlural = There are a total of <b> {0} files </b> in the Upload Request.
endingMainMsgPluralForRecipient = and so far you have sent <b> {0} files </b> in the Upload Request.
endingMainMsgSingular = There is a total of <b>1 file </b> in the upload request.
endingMainMsgSingularForRecipient = and you currently have sent <b>1 file </b>in the repository.
filesInURDepot = Files uploaded
formatMailSubject = : {0}
invitationActivationDate = Activation date
invitationClosureDate = Closure date
recipientsURequest = Recipients
subjectForOwner =  Your invitation is about to be closed.
subjectForRecipient =  {0} {1}''''s  invitation is about to be closed
uploadFileBtn = Upload a file',messages_russian='beginningMainMsgForRecipient = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>''''s запрос на загрузку:  <b>{2}</b> приближается к окончанию срока действия через <b>{3} дня</b>
beginningMainMsgCollective = Ваш коллективный запрос на загрузку: {0}, закроется через  <b>{1} дня</b>.
beginningMainMsgIndividual =  Ваш индивидуальный запрос на загрузку: {0}, закроется через <b>{1} дня</b>.
endingMainMsgPlural = Всего загрузка содержит <b> {0} файлов </b>.
endingMainMsgPluralForRecipient = вы отправили <b> {0} файлов </b> в загрузку.
endingMainMsgSingular = Всего в репозитории of <b>1 файл </b>.
endingMainMsgSingularForRecipient = вы отправили <b>1 файл </b> в репозиторий.
filesInURDepot = Загруженные файлы
formatMailSubject = : {0}
invitationActivationDate = Дата активации
invitationClosureDate = Дата закрытия
recipientsURequest = Получатели
subjectForOwner =  Срок действия вашего приглашения заканчивается.
subjectForRecipient =  {0} {1}''''s срок действия вашего приглашения заканчивается.
uploadFileBtn = Загрузить файл',messages_vietnamese='beginningMainMsgForRecipient = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>''''s yêu cầu tải lên:  <b>{2}</b> sắp tới ngày kết thúc trong <b>{3} ngày</b>
beginningMainMsgCollective = Yêu cầu tải lên chung của bạn: {0}, sắp được đóng trong  <b>{1} ngày</b>.
beginningMainMsgIndividual =  Yêu cầu tải lên cá nhân của bạn: {0}, sắp được đóng trong <b>{1} ngày</b>.
endingMainMsgPlural = Có tổng cộng <b> {0} files </b> trong yêu cầu tải lên. 
endingMainMsgPluralForRecipient = và tính đến hiện tại bạn đã gửi <b> {0} files </b> trong yêu cầu tải lên.
endingMainMsgSingular = Có tổng cộng <b>1 file </b> trong yêu cầu tải lên.  
endingMainMsgSingularForRecipient = và hiện tại bạn đã taỉ lên <b>1 file </b>trong thư mục.
filesInURDepot = Files được tải lên
formatMailSubject = : {0}
invitationActivationDate = Ngày kích hoạt 
invitationClosureDate = Ngày đóng 
recipientsURequest = Người nhận
subjectForOwner =  Lời mời của bạn sắp được đóng. 
subjectForRecipient =  Lời mời của {0} {1}''''s sắp được đóng 
uploadFileBtn = Tải lên 1 file' WHERE id=12;
UPDATE mail_content SET subject='[# th:if="${warnOwner}"] 
           [( #{subjectForOwner(${subject})})]
       [/]
        [# th:if="${!warnOwner}"]
           [( #{subjectForRecipient(${requestOwner.firstName},${requestOwner.lastName},${subject})})]
       [/]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content container*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Upper message content for the owner of the upload request */-->
        <th:block data-th-if="(${warnOwner})" >
          <!--/* Greetings */-->
          <th:block    data-th-replace="layout :: greetings(${requestOwner.firstName})"/>
          <!--/* End of Greetings  */-->
          <!--/* Main email  message content*/-->
          <p>
            <span  data-th-if="!(${isCollective})"   data-th-utext="#{beginningMainMsgIndividual}"></span>
            <span  data-th-if="(${isCollective})"   data-th-utext="#{beginningMainMsgCollective}"></span>
            <span data-th-if="(${documentsCount} ==  1)"   data-th-utext="#{endingMainMsgSingular}" ></span>
            <span  data-th-if="(${documentsCount} >  1)"   data-th-utext="#{endingMainMsgPlural(${documentsCount})}"></span>
          </p>
        </th:block>
        <!--/* End of Main email  message content*/-->
        <!--/* End of upper message content for owner of the upload request */-->
        <!--/* upper message content for recipients of the upload request */-->
        <th:block data-th-if="(${!warnOwner})" >
          <!--/* Greetings */-->
          <th:block  data-th-replace="layout :: greetings(${requestRecipient.mail})" />
          <!--/* End of Greetings  */-->
          <!--/* Main email  message content*/-->
          <p>
            <span  data-th-utext="#{beginningMainMsgForRecipient(${requestOwner.firstName},${requestOwner.lastName},${remainingDays})}"></span>
            <span data-th-if="(${request.uploadedFilesCount} ==  1)"  data-th-utext="#{endingMainMsgSingularForRecipient}" ></span>
            <span  data-th-if="(${request.uploadedFilesCount} >  1)"   data-th-utext="#{endingMainMsgSingularForRecipient(${request.uploadedFilesCount})}"></span>
          </p>
        </th:block>
        <!--/* End of Main email  message content*/-->
        <!--/* End of upper message content for recipients of the upload request */-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of upper main-content container*/-->
  </section><!--/* End of uppermain-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <!--/*Lower message content for the owner of the upload request */-->
    <th:block  data-th-if="(${warnOwner})">
        <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsURequest},${recipients})"/>
        <th:block data-th-replace="layout :: infoFileLinksListingArea(#{filesInURDepot},${documents}, false)"/>
    </th:block>
    <!--/*Lower message content for the owner of the upload request */-->
    <!--/*Lower message content for recipients of the upload request */-->
    <th:block  data-th-if="(${!warnOwner})">
      <th:block  data-th-if="(${isCollective})">
        <th:block data-th-replace="layout :: infoRecipientListingArea(#{recipientsURequest},${recipients})"/>
        <th:block data-th-replace="layout :: infoFileListWithMyUploadRefs(#{filesInURDepot},${documents})"/>
      </th:block>
      <th:block  data-th-if="!(${isCollective})">
        <th:block data-th-replace="layout :: infoFileLinksListingArea(#{filesInURDepot},${documents}, true)"/>
      </th:block>
    </th:block>
    <!--/* End of lower message content for recipients of the upload request */-->
    <th:block data-th-replace="layout :: infoDateArea(#{invitationCreationDate},${request.activationDate})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{invitationClosureDate},${request.expirationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='beginningMainMsgForRecipient = L''''invitation de Dépôt de <b> {0} <span style="text-transform:uppercase">{1}</span> </b> a expiré.
beginningMainMsgCollective = Votre Invitation de Dépôt collective a expiré.
beginningMainMsgIndividual = Votre Invitation de Dépôt a expiré.
endingMainMsgPlural = et vous avez reçu un total  de <b>{0} fichiers</b>.
endingMainMsgPluralForRecipient = et vous avez  envoyé  <b> {0} fichiers </b>.
endingMainMsgSingular = et vous avez  reçu au total <b>1 fichier</b>.
endingMainMsgSingularForRecipient = et vous avez  envoyé <b>1 fichier </b>.
filesInURDepot = Fichiers déposés
formatMailSubject = : {0}
invitationClosureDate = Date  de clôture
invitationCreationDate =  Date d''''activation
recipientsURequest = Destinataires
subjectForOwner = Votre Invitation de Dépôt {0} est clôturée
subjectForRecipient = L'''' Invitation de Dépôt de {0} {1} intitulée {2} est clôturée',messages_english='beginningMainMsgForRecipient = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>''''s Upload Request has expired
beginningMainMsgCollective = Your collective Upload Request has expired
beginningMainMsgIndividual = Your Upload Request has expired
endingMainMsgPlural = and you have received a total of <b>{0} files</b>.
endingMainMsgPluralForRecipient = and you currently have sent  <b> {0} files </b>.
endingMainMsgSingular = and you have received a total of <b>1 file</b>.
endingMainMsgSingularForRecipient = and you currently have uploaded <b>1 file </b> to the repository.
filesInURDepot = Files uploaded
formatMailSubject = : {0}
invitationClosureDate = Closure date
invitationCreationDate = Activation date
recipientsURequest = Recipients
subjectForOwner = Your invitation {0} is now closed
subjectForRecipient =  {0} {1}''''s  invitation {2} is now closed',messages_russian='beginningMainMsgForRecipient = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>''''s Срок действия загрузки закончился
beginningMainMsgCollective = Срок действия вашего группового запроса загрузки закончился
beginningMainMsgIndividual = Срок действия загрузки закончился.
endingMainMsgPlural = Вы получили <b>{0} файлов</b>.
endingMainMsgPluralForRecipient = вы отправили всего <b> {0} файлов </b>.
endingMainMsgSingular = всего вы получили <b>1 файлов</b>.
endingMainMsgSingularForRecipient = вы загрузили в репозиторий <b>1 файл </b> .
filesInURDepot = Загружено файлов
formatMailSubject = : {0}
invitationClosureDate = Дата закрытия
invitationCreationDate = Дата активации
recipientsURequest = Получатели
subjectForOwner = Ваше приглашение  {0} больше не действительно
subjectForRecipient =  {0} {1}''''s  приглешение {2} больше не действительно',messages_vietnamese='beginningMainMsgForRecipient = <b> {0} <span style="text-transform:uppercase">{1}</span> </b>''''s Yêu cầu tải lên đã hết hạn.
beginningMainMsgCollective = Yêu cầu tải chung của bạn đã hết hạn 
beginningMainMsgIndividual = Yêu cầu tải lên của bạn đã hết hạn 
endingMainMsgPlural = và bạn nhận được tổng cộng <b>{0} files</b>.
endingMainMsgPluralForRecipient = và bạn hiện tại đã gửi  <b> {0} files </b>.
endingMainMsgSingular = và bạn nhận được tổng cộng <b>1 file</b>.
endingMainMsgSingularForRecipient = và bạn đã tải lên <b>1 file </b> vào thư mục. 
filesInURDepot = Các file được tải lên 
formatMailSubject = : {0}
invitationClosureDate = Ngày đóng 
invitationCreationDate = Ngày kích hoạt
recipientsURequest = Người nhận 
subjectForOwner = Lời mời của bạn {0} bây giờ đã được đóng 
subjectForRecipient =  {0} {1}''''s  lời mời {2} đã được đóng bây giờ' WHERE id=13;
UPDATE mail_content SET subject='[( #{subject(${workGroupName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
    <!--/* Upper main-content*/-->
    <section id="main-content">
        <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
            <div id="section-content">
                <!--/* Greetings */-->
                <th:block data-th-replace="layout :: greetings(${member.firstName})"/>
                <!--/* End of Greetings  */-->
                <!--/* Main email  message content*/-->
                <p>
                      <span th:if="(${owner.firstName} !=null AND ${owner.lastName} !=null)
                       AND (${owner.firstName} != ${member.firstName} AND ${member.lastName} != ${owner.lastName})"
                                      data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName},${workGroupName})}">
                      </span>
                      <span th:unless="(${owner.firstName} !=null AND ${owner.lastName} !=null)
                       AND (${owner.firstName} != ${member.firstName} AND ${member.lastName} != ${owner.lastName})"
                                      data-th-utext="#{mainMsgAdmin(${workGroupName})}">
                      </span>
                      <span th:if="${owner.firstName} ==null OR ${owner.lastName} ==null"
                                      data-th-utext="#{simpleMsg(${workGroupName})}">
                      </span>
                    <!--/* Activation link for initialisation of the guest account */-->
                </p> <!--/* End of Main email  message content*/-->
            </div><!--/* End of section-content*/-->
        </div><!--/* End of main-content container*/-->
    </section> <!--/* End of upper main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
        <th:block data-th-replace="layout :: infoStandardArea(#{workGroupNameTitle},${workGroupName})"/>
    </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='subject = Les accès au groupe de travail {0} vous ont été retirés.
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> vous a retiré du groupe de travail <b>{2}</b>
mainMsgAdmin = Vous vous êtes retiré de votre groupe de travail  <b>{0}</b>
simpleMsg = Les accès au groupe de travail <b>{0}</b> vous ont été retirés.
workGroupNameTitle = Nom du groupe de travail',messages_english='subject = Your access to the workgroup {0} was withdrawn
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> removed you from the workgroup  <b>{2}</b>
mainMsgAdmin = You have removed yourself from your own workgroup  <b>{0}</b>
simpleMsg =  Your access to the workgroup <b>{0}</b> was withdrawn.     
workGroupNameTitle = Workgroup Name',messages_russian='subject = У вас больше нет доступа к рабочей группе {0}.
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> удалил вас из рабочей группы  <b>{2}</b>
mainMsgAdmin = Вы удалили себя из созданной вами рабочей группы  <b>{0}</b>
simpleMsg =  У вас больше нет доступа к рабочей группе <b>{0}</b>.
workGroupNameTitle = Название рабочей группы',messages_vietnamese='subject = Quyền truy cập của bạn đối với workgroup {0} đã bị thu hồi
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã xóa bạn khỏi workgroup  <b>{2}</b>
mainMsgAdmin = Bạn đã tự xóa bạn ra khỏi workgroup của bạn  <b>{0}</b>
simpleMsg =  Quyền truy cập của bạn đối với workgroup <b>{0}</b> đã bị thu hồi.     
workGroupNameTitle = Tên Workgroup ' WHERE id=30;
UPDATE mail_content SET subject='[( #{subject(${workGroupName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
    <!--/* Upper main-content*/-->
    <section id="main-content">
        <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
            <div id="section-content">
                <!--/* Greetings */-->
                <th:block data-th-replace="layout :: greetings(${member.account.firstName})"/>
                <!--/* End of Greetings  */-->
                <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${workGroupName}, ${actor.firstName},${actor.lastName})}">
                     </span>
                  </p>
                </p> <!--/* End of Main email  message content*/-->
            </div><!--/* End of section-content*/-->
        </div><!--/* End of main-content container*/-->
    </section> <!--/* End of upper main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
        <th:block data-th-replace="layout :: infoStandardArea(#{workGroupNameTitle},${workGroupName})"/>
    </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='subject = Le groupe de travail {0} a été supprimé.
mainMsg = Le groupe de travail {0} a été supprimé par <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
workGroupNameTitle = Nom du groupe de travail',messages_english='subject = The workgroup {0} has been deleted.
mainMsg = The workgroup {0} has been deleted by <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
workGroupNameTitle = Workgroup Name',messages_russian='subject = Рабочая группа {0} была удалена.
mainMsg = Рабочая группа {0} была удалена <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
workGroupNameTitle = Название рабочей группы' ,messages_vietnamese='subject = Workgroup {0} đã bị xóa.
mainMsg = Workgroup {0} đã bị xóa bởi <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
workGroupNameTitle = Tên Workgroup' WHERE id=39;
UPDATE mail_content SET subject='[( #{subject(${workGroupName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${member.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
            <span th:if="${owner.firstName} !=null AND ${owner.lastName} !=null" data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName})}"></span>
            <span th:if="${owner.firstName} ==null OR ${owner.lastName} ==null" data-th-utext="#{simpleMainMsg}"></span>
            <span>
              <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${workGroupName}" th:href="@{${workGroupLink}}" >
               link
             </a>
            </span>
          <!--/* Activation link for initialisation of the guest account */-->
             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block th:switch="(${threadMember.role.name})">
       <p th:case="ADMIN">
          <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightAdminTitle})"/>
       </p>
       <p th:case="WRITER">
          <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightWirteTitle})"/>
       </p>
       <p th:case="CONTRIBUTOR">
          <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightContributeTitle})"/>
       </p>
       <p th:case="READER">
         <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightReadTitle})"/>
       </p>
    </th:block>
    <th:block data-th-replace="layout :: infoStandardArea(#{workGroupNameTitle},${workGroupName})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{workGroupCreationDateTitle},${threadMember.creationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='workGroupCreationDateTitle = Date de création
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> vous a ajouté au groupe de travail <br>
simpleMainMsg = Vous avez été ajouté au groupe de travail
subject = Vous avez été ajouté au groupe de travail {0}
workGroupRight = Droit par défaut 
workGroupNameTitle = Nom du groupe de travail',messages_english='workGroupCreationDateTitle = Creation date
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> added you to the workgroup <br>
simpleMainMsg = You have been added to the workgroup
subject = You have been added to the workgroup {0}
workGroupRight = Default right
workGroupNameTitle = Workgroup Name',messages_russian='workGroupCreationDateTitle = Дата создания
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> добавил вас в рабочую группу <br>
simpleMainMsg = Вас добавили в рабочую группу
subject = Вас добавили в рабочую группу {0}
workGroupRight = Права по умолчанию
workGroupNameTitle = Название рабочей группы',messages_vietnamese='workGroupCreationDateTitle = Ngày tạo
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã thêm bạn vào workgroup <br>
simpleMainMsg = Bạn đã được thêm vào workgroup 
subject =Bạn đã được thêm vào workgroup {0}
workGroupRight = Quyền mặc định 
workGroupNameTitle = Tên Workgroup' WHERE id=28;
UPDATE mail_content SET subject='[( #{subject(${document.name},${workGroupMember.node.name},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${workGroupMember.account.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
           <span data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName})}"></span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${document.name}" th:href="@{${workGroupDocumentLink}}" >
               link
             </a>
           <span th:if="${folder.nodeType.name} != ''ROOT_FOLDER''" data-th-utext="#{folderMsg}"></span>
           <span th:if="${folder.nodeType.name} != ''ROOT_FOLDER''">
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${folder.name}" th:href="@{${workGroupFolderLink}}" >
               link
             </a>
          </span>
          <span data-th-utext="#{workgroupMsg}"></span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${workGroupMember.node.name}" th:href="@{${workGroupLink}}" >
               link
             </a>
          <!--/* Activation link for initialisation of the guest account */-->
         </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoDateArea(#{workGroupCreationDateTitle},${document.creationDate})"/>
    <th:block data-th-replace="layout :: infoStandardArea(#{DocumentSize},${document.size})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='workGroupCreationDateTitle = Date de création
DocumentSize = Taille du document
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> a ajouté un nouveau document <br>
folderMsg = dans le dossier
workgroupMsg = du groupe de travail
subject = Le Document {0} a été ajouté à {1}',messages_english='workGroupCreationDateTitle = Creation date
DocumentSize = Document size
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> uploaded a new document<br>
folderMsg = into the folder
workgroupMsg = on the workgroup
subject = The document {0} was uploaded in the workgroup {1}',messages_russian='workGroupCreationDateTitle = Дата создания
DocumentSize = Размер документа
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> загрузил новый документ<br>
folderMsg = в папку
workgroupMsg = рабочей группы
subject = Документ {0} был загружен в рабочую группу {1}',messages_vietnamese='workGroupCreationDateTitle = Ngày tạo
DocumentSize = Kích cỡ tài liệu
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã tảu liên một tài liệu mới<br>
folderMsg = vào thư mục 
workgroupMsg = trong workgroup
subject = Tài liệu {0} đã được tải lên workgroup {1}' WHERE id=44;
UPDATE mail_content SET subject='[(#{subject(${workGroupName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${member.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg}"></span>
          <span>
               <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${workGroupName}" th:href="@{${workGroupLink}}" >
                link </a>
          </span>
          <span data-th-utext="#{mainMsgNext}"></span>
          <span th:if="${owner.firstName} != null AND ${owner.firstName} != null" data-th-utext="#{mainMsgNextBy(${owner.firstName},${owner.lastName})}"></span>

             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block th:switch="(${threadMember.role.name})">
       <p th:case="ADMIN">
          <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightAdminTitle})"/>
       </p>
       <p th:case="WRITER">
          <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightWirteTitle})"/>
       </p>
       <p th:case="CONTRIBUTOR">
          <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightContributeTitle})"/>
       </p>
       <p th:case="READER">
         <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightReadTitle})"/>
       </p>
    </th:block>
    <th:block data-th-replace="layout :: infoStandardArea(#{workGroupNameTitle},${workGroupName})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{workGroupUpdatedDateTitle},${threadMember.modificationDate})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='workGroupUpdatedDateTitle = Date de la mise à jour
mainMsg = Vos droits sur le groupe de travail
mainMsgNext = ont été mis à jour 
mainMsgNextBy= par <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Vos droits sur le groupe de travail {0} ont été mis à jour
workGroupRight =  Nouveau droit
workGroupNameTitle = Nom du groupe de travail',messages_english='workGroupUpdatedDateTitle = Updated date
mainMsg = Your rights on the workgroup 
mainMsgNext= have been updated
mainMsgNextBy= by <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Your rights on the workgroup {0} was updated.
workGroupRight = Current right
workGroupNameTitle = Workgroup Name',messages_russian='workGroupUpdatedDateTitle = Дата обновления
mainMsg = Ваш статус в рабочей группе
mainMsgNext= был обновлен
mainMsgNextBy= by <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Ваш статус в рабочей группе {0} был обновлен.
workGroupRight = Действующий статус
workGroupNameTitle = Название рабочей группы',messages_vietnamese='workGroupUpdatedDateTitle = Ngày cập nhật 
mainMsg = Quyền của bạn trong workgroup 
mainMsgNext= đã được cập nhật 
mainMsgNextBy= bởi <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Quyền của bạn trong workgroup {0} đã được cập nhật 
workGroupRight = Quyền hiện tại 
workGroupNameTitle = Tên Workgroup' WHERE id=29;
UPDATE mail_content SET subject='[( #{subject(${document.name},${workGroupMember.node.name},${subject})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${workGroupMember.account.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
           <span data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName})}"></span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${document.name}" th:href="@{${workGroupDocumentLink}}" >
               link
             </a>
           <span th:if="${folder.nodeType.name} != ''ROOT_FOLDER''" data-th-utext="#{folderMsg}"></span>
           <span th:if="${folder.nodeType.name} != ''ROOT_FOLDER''">
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${folder.name}" th:href="@{${workGroupFolderLink}}" >
               link
             </a>
          </span>
          <span data-th-utext="#{workgroupMsg}"></span>
             <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${workGroupMember.node.name}" th:href="@{${workGroupLink}}" >
               link
             </a>
          <span data-th-utext="#{revisionMsg}"></span>
          <!--/* Activation link for initialisation of the guest account */-->
         </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
         <section id="secondary-content">
    <th:block data-th-replace="layout :: infoDateArea(#{workGroupModificationDateTitle},${document.modificationDate})"/>
    <th:block data-th-replace="layout :: infoStandardArea(#{DocumentSize},${document.size})"/>
         </section>
         <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='workGroupModificationDateTitle = Date de modification
DocumentSize = Taille du document
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> a modifié le document <br>
folderMsg = dans le dossier
workgroupMsg = du groupe de travail
revisionMsg = en ajoutant une nouvelle révision 
subject = Le Document {0} a été modifié à {1}
name: ',messages_english='workGroupModificationDateTitle = Modification date
DocumentSize = Document size
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> updated the document<br>
folderMsg = into the folder
workgroupMsg = on the workgroup
revisionMsg = by adding a new document revision 
subject = The document {0} was updated in the workgroup {1}',messages_russian='workGroupModificationDateTitle = Дата изменения
DocumentSize = Размер документа
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> обновил документ<br>
folderMsg = в папке
workgroupMsg = рабочей группы
revisionMsg = путем добавления новой редакции документа
subject = Документ {0} был обновлен в рабочей группе {1}',messages_vietnamese='workGroupModificationDateTitle = NGày chỉnh sửa
DocumentSize = Kích cỡ tài liệu 
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã chỉnh sửa tài liệu<br>
folderMsg = trong thư mục 
workgroupMsg = trong workgroup
revisionMsg = bới thêm một phiên bản mới của tài liệu 
subject = Tài liệu {0} đã được cập nhật tron workgroup {1}' WHERE id=45;
UPDATE mail_content SET subject='[( #{subject(${workSpaceName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
    <!--/* Upper main-content*/-->
    <section id="main-content">
        <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
            <div id="section-content">
                <!--/* Greetings */-->
                <th:block data-th-replace="layout :: greetings(${member.account.firstName})"/>
                <!--/* End of Greetings  */-->
                <!--/* Main email  message content*/-->
                  <p>
                     <span data-th-utext="#{mainMsg(${workSpaceName}, ${actor.firstName},${actor.lastName})}">
                     </span>
                  </p>
                </p> <!--/* End of Main email  message content*/-->
            </div><!--/* End of section-content*/-->
        </div><!--/* End of main-content container*/-->
    </section> <!--/* End of upper main-content*/-->
    <!--/* Secondary content for  bottom email section */-->
    <section id="secondary-content">
    <div th:if="${!nestedNodes.isEmpty()}">
      <th:block data-th-utext="#{nestedWorkGroupsList}"/>
      <ul style="padding: 5px 17px; margin: 0;list-style-type:disc;">
        <li style="color:#787878;font-size:10px" th:each="node : ${nestedNodes}">
            <span style="color:#787878;font-size:13px">
              <th:block data-th-utext="#{displayNestedNodeName(${node.name})}"/>
          </li>
      </ul>  
    </div>
    </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='subject = Le Workspace {0} a été supprimé.
mainMsg = Le Workspace {0} a été supprimé par <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
nestedWorkGroupsList=Vous avez automatiquement été supprimé des groupes de travail suivants :
displayNestedNodeName:{0}',messages_english='subject = The Workspace {0} has been deleted.
mainMsg = The Workspace {0} has been deleted by <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
nestedWorkGroupsList=You have been automatically removed from the following workgroups:
workGroupNameTitle = Workgroup Name
displayNestedNodeName:{0}',messages_russian='subject = Рабочее пространство {0} было удалено.
mainMsg = Рабочее пространство {0} было удалено <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
nestedWorkGroupsList= Вы были автоматически удалены из следующих рабочих групп:
displayNestedNodeName:{0}',messages_vietnamese='subject = Workspace {0} đã bị xóa 
mainMsg = Workspace {0} đã được xóa bởi <b> {1} <span style="text-transform:uppercase">{2}</span></b>.
nestedWorkGroupsList=Bạn đã được tự động xóa khỏi các workgroup sau:
workGroupNameTitle = Tên Workgroup
displayNestedNodeName:{0}' WHERE id=40;
UPDATE mail_content SET subject='[( #{subject(${workGroupName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${member.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span th:if="${owner.firstName} !=null AND ${owner.lastName} !=null" data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName},${workGroupName})}"></span>
          <span th:if="${owner.firstName} ==null OR ${owner.lastName} ==null" data-th-utext="#{simpleMsg(${workGroupName})}"></span>
            
          <!--/* Activation link for initialisation of the guest account */-->
             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoStandardArea(#{workGroupNameTitle},${workGroupName})"/>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='subject = Les accès au workspace {0} et à ses workgroups vous ont été retirés.
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> vous a retiré du workspace <b>{2}</b>
simpleMsg = Les accès au workspace <b>{0}</b> vous ont été retirés.
workGroupNameTitle = Nom du workspace',messages_english='subject = Your access to the workspace {0}  and its workgroups was withdrawn
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> removed you from the workspace  <b>{2}</b>
simpleMsg =  Your access to the workspace <b>{0}</b> was withdrawn.
workGroupNameTitle = Workspace Name',messages_russian='subject = Ваш доступ к рабочему пространству {0}  и его рабочим группам был отозван
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> удалил вас из рабочего пространства  <b>{2}</b>
simpleMsg =  Ваш доступ к рабочему пространству <b>{0}</b> был отозван.
workGroupNameTitle = Название рабочего пространства', messages_vietnamese='subject = Quyền truy cập của bạn đối với workspace {0} và các workgroups bên trong đã bị thu hồi
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã xóa bạn khỏi workspace <b>{2}</b>
simpleMsg =  Quyền truy cập của bạn đối với workspace <b>{0}</b> đã bị thu hồi.
workGroupNameTitle = Tên workspace ' WHERE id=36;
UPDATE mail_content SET subject='[( #{subject(${workSpaceName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${member.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
            <span th:if="${owner.firstName} !=null AND ${owner.lastName} !=null" data-th-utext="#{mainMsg(${owner.firstName},${owner.lastName})}"></span>
            <span th:if="${owner.firstName} ==null OR ${owner.lastName} ==null" data-th-utext="#{simpleMainMsg}"></span>
            <span>
              <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${workSpaceName}" th:href="@{${workSpaceLink}}" >
               link
             </a>
            </span>
          <!--/* Activation link for initialisation of the guest account */-->
             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block th:switch="${workSpaceMember.role.name}">
      <p th:case="''WORK_SPACE_ADMIN''"> <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceRight}, #{workSpaceRoleAdminTitle})"/></p>
      <p th:case="''WORK_SPACE_WRITER''"> <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceRight}, #{workSpaceRoleWriteTitle})"/></p>
      <p th:case="''WORK_SPACE_READER''"> <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceRight}, #{workSpaceRoleReadTitle})"/></p>
    </th:block>
    <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceNameTitle},${workSpaceName})"/>
    <th:block data-th-replace="layout :: infoDateArea(#{workSpaceMemberCreationDateTitle},${workSpaceMember.creationDate})"/>
    <div th:if="${!childMembers.isEmpty()}">
      <th:block data-th-utext="#{nestedWorkGroupsList}"/>
      <ul style="padding: 5px 17px; margin: 0;list-style-type:disc;">
        <li style="color:#787878;font-size:10px" th:each="member : ${childMembers}">
            <span style="color:#787878;font-size:13px">
              <th:block data-th-utext="#{displayWorkSpaceAndRole(${member.node.name},${member.role.name})}"/>
          </li>
      </ul>  
    </div>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='workSpaceMemberCreationDateTitle = Date de création
mainMsg =  <b> {0} <span style="text-transform:uppercase">{1}</span> </b> vous a ajouté au WorkSpace: <br>
simpleMainMsg = Vous avez été ajouté au WorkSpace
subject = Vous avez été ajouté au WorkSpace {0}
workSpaceRight = Droit par défaut
workSpaceNameTitle = Nom du WorkSpace
nestedWorkGroupsList=Vous avez automatiquement été ajouté aux groupes de travail suivants :
displayWorkSpaceAndRole ={0} avec un rôle <span style="text-transform:uppercase">{1}</span>',messages_english='workSpaceMemberCreationDateTitle = Creation date
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> added you to the WorkSpace: <br>
simpleMainMsg = You have been added to the WorkSpace
subject = You have been added to the WorkSpace {0}
workSpaceRight = Default right
workSpaceNameTitle = WorkSpace Name
nestedWorkGroupsList=You have been automatically added to the following workgroups:
displayWorkSpaceAndRole ={0} with a <span style="text-transform:uppercase">{1}</span> role',messages_russian='workSpaceMemberCreationDateTitle = Дата создания
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> добавил вас в рабочее пространство: <br>
simpleMainMsg = Вы были добавлены в рабочее пространство
subject = Вы были добавлены в рабочее пространство {0}
workSpaceRight = Права по умолчанию
workSpaceNameTitle = Название рабочего пространства
nestedWorkGroupsList= Вы были автоматически добавлены в следующие рабочие группы:
displayWorkSpaceAndRole ={0} с ролью <span style="text-transform:uppercase">{1}</span>',messages_vietnamese='workSpaceMemberCreationDateTitle = Ngày tạo
mainMsg = <b> {0} <span style="text-transform:uppercase">{1}</span></b> đã thêm bạn vào WorkSpace: <br>
simpleMainMsg = Bạn đã được thêm vào WorkSpace
subject = Bạn đã đươcj thêm vào Workspace {0}
workSpaceRight = Quyền mặc định 
workSpaceNameTitle = Tên WorkSpace 
nestedWorkGroupsList=Bạn đã được tự động thêm vào các workgroup sau:
displayWorkSpaceAndRole ={0} với <span style="text-transform:uppercase">{1}</span> quyền' WHERE id=34;
UPDATE mail_content SET subject='[(#{subject(${workSpaceName})})]',body='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head  data-th-replace="layout :: header"></head>
<body>
<div th:replace="layout :: email_base(upperMainContentArea = ~{::#main-content},bottomSecondaryContentArea = ~{::#secondary-content})">
  <!--/* Upper main-content*/-->
  <section id="main-content">
    <div th:replace="layout :: contentUpperSection( ~{::#section-content})">
      <div id="section-content">
        <!--/* Greetings */-->
        <th:block data-th-replace="layout :: greetings(${member.firstName})"/>
        <!--/* End of Greetings  */-->
        <!--/* Main email  message content*/-->
        <p>
          <span data-th-utext="#{mainMsg}"></span>
          <span>
               <a target="_blank" style="color:#1294dc;text-decoration:none;"  data-th-text="${workSpaceName}" th:href="@{${workSpaceLink}}" >
                link </a>
          </span>
          <span data-th-utext="#{mainMsgNext}"></span>
          <span th:if="${owner.firstName} != null AND ${owner.firstName} != null" data-th-utext="#{mainMsgNextBy(${owner.firstName},${owner.lastName})}"></span>

             </p> <!--/* End of Main email  message content*/-->
      </div><!--/* End of section-content*/-->
    </div><!--/* End of main-content container*/-->
  </section> <!--/* End of upper main-content*/-->
  <!--/* Secondary content for  bottom email section */-->
  <section id="secondary-content">
    <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceNameTitle},${workSpaceName})"/>
    <th:block th:switch="${workSpaceMember.role.name}">
      <p th:case="''WORK_SPACE_ADMIN''"> <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceRight}, #{workSpaceRoleAdminTitle})"/></p>
      <p th:case="''WORK_SPACE_WRITER''"> <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceRight}, #{workSpaceRoleWriteTitle})"/></p>
      <p th:case="''WORK_SPACE_READER''"> <th:block data-th-replace="layout :: infoStandardArea(#{workSpaceRight}, #{workSpaceRoleReadTitle})"/></p>
    </th:block>
    <th:block th:switch="${workSpaceMember.nestedRole.name}">
      <p th:case="''ADMIN''"> <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightAdminTitle})"/></p>  
      <p th:case="''CONTRIBUTOR''"> <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightWirteTitle})"/></p>
      <p th:case="''WRITER''"> <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightWirteTitle})"/></p>
      <p th:case="''READER''"> <th:block data-th-replace="layout :: infoStandardArea(#{workGroupRight}, #{workGroupRightReadTitle})"/></p>
    </th:block>
    <th:block data-th-replace="layout :: infoDateArea(#{workSpaceMemberUpdatedDateTitle},${workSpaceMember.modificationDate})"/>
    <div th:if="${nbrWorkgroupsUpdated != 0}">
    <th:block data-th-replace="layout :: infoStandardArea(#{nbrWorkgoups},${nbrWorkgroupsUpdated})"/>
      <th:block data-th-utext="#{nestedWorkGroupsList}"/>
      <ul>
        <li  th:each="member : ${nestedMembers}">
              <th:block data-th-utext="${member.node.name}"/>
        </li>
        <span th:if="${nbrWorkgroupsUpdated > 3}">
             <li>...</li>
        </span>
      </ul>  
    </div>
  </section>  <!--/* End of Secondary content for bottom email section */-->
</div>
</body>
</html>',messages_french='workSpaceMemberUpdatedDateTitle = Date de la mise à jour
mainMsg = Vos droits sur le WorkSpace
mainMsgNext = et dans ses WorkGroups contenus ont été mis à jour
mainMsgNextBy= par <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Vos droits sur le WorkSpace {0} ont été mis à jour
workSpaceRight = Droit sur le WorkSpace
workGroupRight =  Droit sur le groupe de travail
workSpaceNameTitle = Nom du WorkSpace
nestedWorkGroupsList = Liste des workgoups
nbrWorkgoups = Nombre de groupe de travail mis à jours',messages_english='workSpaceMemberUpdatedDateTitle = Updated date
mainMsg = Your roles on the WorkSpace
mainMsgNext= and workgroups inside it, have been updated
mainMsgNextBy= by <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Your roles on the WorkSpace {0} was updated.
workSpaceRight = WorkSpace right
workGroupRight = Workgroup right
workSpaceNameTitle = WorkSpace Name
nestedWorkGroupsList = Workgroups list
nbrWorkgoups = Number of updated workGroups',messages_russian='workSpaceMemberUpdatedDateTitle = Дата обновления
mainMsg = Ваши роли в рабочем пространстве
mainMsgNext= и рабочих группах внутри него были обновлены
mainMsgNextBy= by <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Ваши роли в рабочем пространстве {0} обновлены.
workSpaceRight = Права в рабочем пространстве
workGroupRight = Права в рабочей группе
workSpaceNameTitle = Название рабочего пространства
nestedWorkGroupsList = Список рабочих групп
nbrWorkgoups = Количество обновленных рабочих групп',messages_vietnamese='workSpaceMemberUpdatedDateTitle = NGaỳ cập nhật
mainMsg = Quyền của bạn trong workspace 
mainMsgNext= và các workgroup bên trong đã được cập nhật 
mainMsgNextBy= by <b> {0} <span style="text-transform:uppercase">{1}</span></b>.
subject =  Quyền của bạn trong WorkSpace {0} đã được cập nhật 
workSpaceRight = Quyền trong WorkSpace 
workGroupRight = Quyền trong Workgroup
workSpaceNameTitle = Tên WorkSpace
nestedWorkGroupsList = Danh sách Workgroups 
nbrWorkgoups = Số workgroup được cập nhật' WHERE id=35;
UPDATE mail_footer SET messages_french='learnMoreAbout=En savoir plus sur
productOfficialWebsite=http://www.linshare.org/',messages_english='learnMoreAbout=Learn more about
productOfficialWebsite=http://www.linshare.org/',messages_russian='learnMoreAbout=Узнать больше
productOfficialWebsite=http://www.linshare.org/',messages_vietnamese='learnMoreAbout=Tìm hiểu chi tiết về
productOfficialWebsite=http://www.linshare.org/',footer='<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
   <body>
      <div data-th-fragment="email_footer">
         <td style="border-collapse:collapse;padding: 6px 0 4px 17px;" valign="top">
            <p style="margin: 0; font-size: 10px;">
               <span th:text="#{learnMoreAbout}">Learn more about</span>
               <a th:href="@{#{productOfficialWebsite}}"  target="_blank" style="text-decoration:none; color:#a9a9a9;">
                 <strong th:text="#{productName}">LinShare</strong>™
               </a>
            </p>
         </td>
         <td style="border-collapse:collapse; padding:  6px 17px 4px 0;"  valign="top" width="60">
            <img alt="libre-and-free" height="9"
               src="cid:logo.libre.and.free@linshare.org"
               style="line-height:100%;width:60px;height:9px;padding:0" width="60" />
         </td>
      </div>
   </body>
</html>' WHERE id=1;
-- LinShare version
INSERT INTO version (id, version, creation_date) VALUES (1, '6.5.0', now());

-- Sequence for hibernate
SELECT setval('hibernate_sequence', 1000);

COMMIT;

COMMIT;
