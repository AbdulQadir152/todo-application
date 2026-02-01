-- Database & table creation
-- 0. Create DB
create database if not exists task_manager;
use task_manager;

-- 1. Create Tables
-- 1.1. Users
create table users (
user_id int auto_increment primary key,
name varchar(150) not null,
email varchar(255) not null unique,
password varchar(255) not null, 
created_at datetime default current_timestamp,
updated_at datetime default current_timestamp on update current_timestamp,
is_active boolean default true
);

-- 1.2. Priorities
create table priorities (
priority_id int auto_increment primary key,
name varchar(50) not null unique,
level int not null unique
);

-- 1.3. Tasks
create table tasks (
task_id int auto_increment primary key,
user_id int not null,
title varchar(255) not null,
description text,
due_date date null,
priority_id int not null,
status enum('pending', 'in_progress','completed', 'archived') default 'pending',
is_active boolean default true,
created_at datetime default current_timestamp,
updated_at datetime default current_timestamp on update current_timestamp,
foreign key (user_id) references users(user_id) on delete cascade,
foreign key (priority_id) references priorities(priority_id) on delete restrict,
index idx_user (user_id),
index idx_priority (priority_id),
unique(user_id, title),
index idx_user_status (user_id, status)
);

-- 1.4. Categories
create table categories(
category_id  int auto_increment primary key,
user_id int not null,
name varchar(100) not null,
description text,
is_active boolean default true,
foreign key (user_id) references users(user_id) on delete cascade,
unique(user_id, name),
index idx_user_category (user_id, name)
);

-- 1.5. Task_Categories (Junction Table)
create table task_categories (
task_id int not null,
category_id int not null,
primary key (task_id, category_id),
foreign key (task_id) references tasks(task_id) on delete cascade,
foreign key (category_id) references categories(category_id) on delete cascade
);

-- 1.6. Task_History
create table task_history(
history_id int auto_increment primary key,
task_id int not null,
changed_by int null,
old_status enum('pending', 'in_progress','completed', 'archived') not null,
new_status enum('pending', 'in_progress','completed', 'archived') not null,
changed_at datetime default current_timestamp,
foreign key (task_id) references tasks(task_id) on delete cascade,
foreign key (changed_by) references users(user_id) on delete set null
);

-- 1.7. Password_Reset_Tokens
create table password_reset_tokens(
token_id int auto_increment primary key,
user_id int not null,
token varchar(255) not null unique,
expires_at datetime not null,
used boolean default false,
created_at datetime default current_timestamp,
foreign key (user_id) references users(user_id) on delete cascade,
index idx_user_token (user_id, used)
); 

-- 1.8. Comments
create table comments(
comment_id int auto_increment primary key,
task_id int null,
user_id int null,
content text not null,
created_at datetime default current_timestamp,
updated_at datetime default current_timestamp on update current_timestamp,
is_active boolean default true,
foreign key (task_id) references tasks(task_id) on delete cascade,
foreign key (user_id) references users(user_id) on delete cascade,
index idx_task (task_id)
);

-- 2.Insert sample data (to test queries) 
-- Priorities -  Hard coded data needs to stay
insert into priorities (name, level) values
('high', 1),
('medium', 2),
('low', 3);

-- 3. Creating views 
-- 3.1) ActiveTasksView - To allow a user to view their pending/in-progress task
create view active_tasks_view as 
select
   t.task_id,
   t.title,
   t.description,
   t.due_date,
   p.name as priority_name,
   t.status
from tasks t
inner join users u on t.user_id = u.user_id
inner join priorities p on t.priority_id = p.priority_id
where t.status in ('pending', 'in_progress');

-- 3.2.UserCategoriesTasks
create view user_categories_tasks as
select
    c.category_id,
    c.name as category_name,
    c.description as category_description,
    t.task_id,
    t.title as task_title,
    t.description as task_description,
    t.due_date,
    t.status
from categories c
left join task_categories tc on c.category_id = tc.category_id
left join tasks t on tc.task_id = t.task_id; 

-- 3.3. ViewComments
create  view task_comments as
select
c.comment_id,
c.task_id,
t.title as task_title,
t.description as task_description,
u.user_id as comment_author_id,
u.name as comment_author_name,
c.content as comment_text,
c.created_at as comment_created_at
from comments c
inner join users u on c.user_id = u.user_id
inner join tasks t on c.task_id = t.task_id;

-- 4 Trigger: auto-insert into Task_History on status change
DELIMITER $$

create trigger task_after_update
after update on tasks
for each row
begin
if not (old.status <=> new.status) then
insert into task_history (task_id, changed_by, old_status, new_status, remarks)
values (new.task_id, new.user_id, old.status, new.status, CONCAT('Status changed by user_id=', NEW.user_id)); --
end if;
end $$

DELIMITER ;

-- 5.Transaction example: safe password reset token creation (use in MySQL)
delimiter $$
create procedure create_reset_token(in in_user_id int, in in_token varchar(255))
begin

  -- error handling block
  declare exit handler for sqlexception 
  begin
    rollback;
    resignal;
  end;

  start transaction;
  
    -- mark previous unused tokens as used
    update password_reset_tokens
    set used = true
    where user_id = in_user_id and used = false;

    -- insert the new token
    insert into password_reset_tokens (user_id, token, expires_at, used)
    values (in_user_id, in_token, date_add(now(), interval 1 hour), false);

  commit;
end$$
delimiter ;

-- 6. Creating Stored Procedures
-- 6.1. Stored procedure to add user
delimiter $$
create procedure add_user(in in_name varchar(150), in in_email varchar(255), in in_password varchar(255))
begin 

declare exit handler for sqlexception
begin
-- just re-throw the error
resignal;
end;

insert into users(name, email, password) values
(in_name, in_email, in_password);

end $$
delimiter ;

-- 6.2. Stored procedure to delete user
delimiter $$

create procedure delete_user(in in_user_id int)
begin
    declare exit handler for sqlexception
    begin
        -- re-throw the error if something goes wrong
        resignal;
    end;

    delete from users
    where user_id = in_user_id;
end $$

delimiter ;

-- 6.3. Stored procedure to add task
delimiter $$
create procedure add_task(in in_user_id int, in in_title varchar(255), in in_description text, in in_due_date date,
in in_priority_id int)
begin

declare exit handler for sqlexception
begin
-- just re-throw the error
resignal;
end;

insert into tasks(user_id, title, description, due_date, priority_id)
values (in_user_id, in_title, in_description, in_due_date, in_priority_id);

end $$
delimiter ;

-- 6.4. Stored procedure for updating a task
delimiter $$
create procedure update_task(in in_task_id int, in in_user_id int, in in_title varchar(255), in in_description text, 
in in_due_date date, in in_priority_id int, in in_status enum('pending','in_progress','completed','archived'))
begin

declare exit handler for sqlexception
begin
-- just re-throw the error
resignal;
end;

update tasks
set
title = ifnull(in_title, title), 
description = ifnull(in_description, description), 
due_date = ifnull(in_due_date, due_date),
priority_id = ifnull(in_priority_id, priority_id),
status = ifnull(in_status, status)
where task_id = in_task_id and user_id = in_user_id;
end $$

delimiter ;

-- 6.5. Stored procedure for deleting a task
delimiter $$
create procedure delete_tasks(in in_task_id int, in in_user_id int )
begin

declare exit handler for sqlexception
begin
-- just re-throw the error
resignal;
end;

delete from tasks
where task_id  = in_task_id
and user_id = in_user_id;
end $$

delimiter ;

-- 6.6. Stored procedure for creating a category
delimiter $$
create procedure add_category(in in_user_id int, in in_name varchar(100), in in_description text )
begin
declare exit handler for sqlexception
begin
resignal;
end;

-- insert the category
insert into categories(user_id, name, description)
values (in_user_id, in_name, in_description);
end $$

delimiter ;

-- 6.7. Stored procedure for adding a task to a category
delimiter $$
create procedure add_task_to_category(in in_task_id int, in in_category_id int, in in_user_id int )
begin

declare exit handler for sqlexception
begin
resignal;
end;

-- check ownership: task belongs to user
if exists (select 1 from tasks where task_id = in_task_id and user_id = in_user_id)
and exists (select 1 from categories where category_id = in_category_id and user_id = in_user_id) then

insert into task_categories(task_id, category_id)
values (in_task_id, in_category_id);
end if;
end $$

delimiter ;

-- 6.8. Stored procedure for removing task from category
delimiter $$
create procedure remove_task_from_category(in in_task_id int, in in_category_id int, in in_user_id int )
begin

declare exit handler for sqlexception
begin
resignal;
end;

delete tc
from task_categories tc
join task t on t.task_id = tc.task_id
join  categories c on c.categories = tc.categories_id
where tc.task_id = in_task_id
and tc.category_id = in_category_id
and t.user_id = in_user_id
and c.user_id = in_user_id;
 end $$

delimiter ;

-- 6.9. Stored procedure for deleting a category
delimiter $$
create procedure delete_category(in in_category_id int, in in_user_id int)
begin

declare exit handler for sqlexception
begin
resignal;
end;

-- delete category only if it belongs to the user
delete from categories
where category_id = in_category_id
and user_id = in_user_id;
end $$

delimiter ;

-- 6.10. Stored Procedure for adding comments to task
delimiter $$
create procedure add_comment_to_task (in in_task_id int, in in_user_id int, in in_content text)
begin

declare exit handler for sqlexception
begin
resignal;
end;

if not exists(select 1 from tasks where task_id = in_task_id and user_id = in_user_id)
then signal sqlstate  '45000'
set message_text = 'task does not belong to the user';
end if;

insert into comments(task_id, user_id, content)
values (in_task_id, in_user_id, in_content);
end $$

delimiter ;

-- 6.11. Stored Procedure to update comments 
delimiter $$
create procedure update_comment_to_task (in in_task_id int, in in_user_id int, in_commnet_id int, in in_content text)
begin

declare exit handler for sqlexception
begin
resignal;
end;

if not exists(select 1 from tasks where task_id = in_task_id and user_id = in_user_id)
then signal sqlstate  '45000'
set message_text = 'task does not belong to the user';
end if;

update comments
set content = ifnull(in_content, content)
where comment_id = in_commnet_id
and user_id = in_user_id;
end $$

delimiter ;

-- 6.12. Stored Procedure to delete comments
delimiter $$
create procedure delete_comment_to_task (in in_task_id int, in in_user_id int)
begin

declare exit handler for sqlexception
begin
resignal;
end;

if not exists(select 1 from tasks where task_id = in_task_id and user_id = in_user_id)
then signal sqlstate  '45000'
set message_text = 'task does not belong to the user';
end if;

delete from comments
where task_id = in_task_id and user_id = in_user_id;
end $$

delimiter ;