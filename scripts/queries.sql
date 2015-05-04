use cclr;

create temporary table _civi_export_contact_ids (cid INT);

-- insert into _civi_export_contact_ids select c.id from civicrm_contact c join civicrm_group_contact gc on gc.contact_id = c.id where gc.group_id = 39;

insert into _civi_export_contact_ids select id from civicrm_contact;

select id, first_name, middle_name, last_name, display_name, prefix_id, suffix_id, job_title, organization_name  from civicrm_contact c ;

select g.id, g.name, v.name, v.value  from civicrm_option_group g join civicrm_option_value v on g.id=v.option_group_id   where g.name like '%prefix%' or g.name like '%suffix%' or g.name like '%phone_type%' or g.name like '%location_type%';

select id, name from civicrm_location_type;

select contact_id, email, location_type_id, is_primary from civicrm_email e join _civi_export_contact_ids t on t.cid = e.contact_id;

select contact_id, phone, phone_ext, location_type_id, is_primary, phone_type_id from civicrm_phone p join _civi_export_contact_ids t on t.cid = p.contact_id;
