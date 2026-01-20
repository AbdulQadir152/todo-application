-- Database & table creation
-- 0. Create DB
create database if not exists task_manager;
use task_manager;

-- 1. Create Tables
-- 1.1. Users
create table Users (
user_id int auto_increment primary key,
name varchar(150) not null,
email varchar(250) not null unique,
password varchar(255) not null, 
created_at datetime default current_timestamp,
updated_at datetime default current_timestamp on update current_timestamp,
is_active boolean default true
);

-- 1.2. Priorities
create table Priorities (
priority_id int auto_increment primary key,
name varchar(50) not null unique,
level int not null
);

-- 1.3. Tasks
create table tasks (
task_id int auto_increment primary key,
user_id int not null,
title varchar(255) not null,
description text,
due_date datetime null,
priority_id int,
status enum('pending', 'in_progress','completed', 'archived') default 'pending',
created_at datetime default current_timestamp,
updated_at datetime default current_timestamp on update current_timestamp,
foreign key (user_id) references Users(user_id) on delete cascade,
foreign key (priority_id) references Priorities(priority_id) on delete cascade,
index idx_user (user_id), --
index idx_priority (priority_id) --
);

-- 1.4. Categories
create table Categories(
category_id  int auto_increment primary key,
user_id int not null,
name varchar(100) not null unique,
description text,
foreign key (user_id) references Users(user_id) on delete cascade
);

-- 1.5. Task_Categories (Junction Table)
create table Task_Categories (
task_id int not null,
category_id int not null,
primary key (task_id, category_id),
foreign key (task_id) references Tasks(task_id) on delete cascade,
foreign key (category_id) references Categories(category_id) on delete cascade
);

-- 1.6. Task_History
create table Task_History(
history_id int auto_increment primary key,
task_id int not null,
changed_by int not null,
old_status enum('pending', 'in_progress','completed', 'archived') not null,
new_status enum('pending', 'in_progress','completed', 'archived') not null,
changed_at datetime default current_timestamp,
remarks text,
foreign key (task_id) references Tasks(task_id) on delete cascade,
foreign key (changed_by) references Users(user_id) on delete set null
);

-- 1.7. Password_Reset_Tokens
create table Password_Reset_Tokens(
token_id int auto_increment primary key,
user_id int not null,
token varchar(255) not null unique,
expires_at datetime not null,
used boolean default false,
created_at datetime default current_timestamp,
foreign key (user_id) references Users(user_id) on delete cascade,
index idx_user_token (user_id, used)
); 

-- 1.8. Comments
create table Comments(
comment_id int auto_increment primary key,
task_id int not null,
user_id int not null,
content text not null,
created_at datetime default current_timestamp,
foreign key (task_id) references Tasks(task_id) on delete cascade,
foreign key (user_id) references Users(user_id) on delete cascade,
index idx_task (task_id)
);

-- 2.Insert sample data (to test queries) 
-- Priorities -  Hard coded data needs to stay
insert into priorities (name, level) values
('high', 1),
('medium', 2),
('low', 3);

-- Users
insert into users (name, email, password) values
('abdul qadir', 'aqs@example.com', '$hashed$1'),
('royam ali', 'royam@example.com', '$hashed$2');

-- categories
insert into categories (name, description, user_id) values
('university work', 'work related tasks', 1),
('personal', 'personal tasks', 1),
('shopping', 'grocery and purchase tasks', 2),
('fitness', 'health and exercise related tasks', 2);

-- tasks
insert into tasks (user_id, title, description, due_date, priority_id, status) values
(1, 'finish report', 'complete dbms report', '2025-11-01 23:59:00', 1, 'pending'),
(1, 'study for lab', 'prepare sql examples', null, 2, 'in_progress'),
(2, 'buy groceries', 'milk, eggs', '2025-12-2 18:00:00', 3, 'pending'),
(2, 'morning workout', 'cardio and stretching', null, 2, 'pending');

-- task_categories
insert into task_categories (task_id, category_id) values
(1, 1), -- Abdul Qadir's task in "work"
(2, 2), -- Abdul Qadir's task in "personal"
(3, 3), -- royam's task in "shopping"
(4, 4); -- royam's task in "fitness"

-- comments
insert into comments (task_id, user_id, content) values
(1, 1, 'started writing intro'),
(1, 2, 'please add references'), -- Remove this comment
(3, 2, 'remember to use discount coupons');

-- password reset tokens (sample)
insert into password_reset_tokens (user_id, token, expires_at) values
(1, 'abc123', date_add(now(), interval 1 hour)), -- Reset these values
(2, 'xyz456', date_add(now(), interval 2 hour));
select * from password_reset_tokens;

-- 3. Creating views 
-- 3.1) ActiveTasksView - To allow a user to view their pending/in-progress task
create view ActiveTasksView as 
select
   t.task_id,
   t.title,
   t.description,
   t.due_date,
   p.name as priority_name,
   p.level as priority_level,
   u.name as user_name,
   t.status,
   t.created_at
from tasks t
left join priorities p on t.priority_id = p.priority_id
left join users u on t.user_id = u.user_id
where t.status in ('pending', 'in_progress');
 -- To allow only to user to access/view their tasks
-- SELECT * FROM ActiveTasksView where user_id = 1;

-- 3.2.UserCategoriesTasks
create view usercategoriestasks as
select
    c.category_id,
    c.name as category_name,
    c.description as category_description,
    t.task_id,
    t.title as task_title,
    t.description as task_description,
    t.due_date,
    t.status,
    t.created_at as task_created_at,
    t.updated_at as task_updated_at
from categories c
left join task_categories tc on c.category_id = tc.category_id
left join tasks t on tc.task_id = t.task_id; 
-- To allow only to user to access/view their categories
-- replace ? with the logged-in user's id in your query


-- 3.3.  UserSpecificCategoryTasks - To allow a user to view their categories and its tasks
create view userspecificcategoriestasks as
select
    c.category_id,
    c.name as category_name,
    c.description as category_description,
    t.task_id,
    t.title as task_title,
    t.description as task_description,
    t.due_date,
    t.status,
    t.created_at as task_created_at,
    t.updated_at as task_updated_at
from categories c
left join task_categories tc on c.category_id = tc.category_id
left join tasks t on tc.task_id = t.task_id; 
-- specific category id and user id to allow a user to view specific tasks;  
-- replace ? with the logged-in user's id in your query

-- 3.4. ViewCommnets
create  view taskcomments as
select
t.title as task_title,
t.description as task_description,
c.comment_id,
c.task_id,
c.user_id as comment_author_id,
u.name as comment_author_name,
c.content as comment_text,
c.created_at as comment_created_at
from comments c
join users u on c.user_id = u.user_id
join tasks t on c.task_id = t.task_id;

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
-- CALL create_reset_token(1, 'NEW_TOKEN_ABC123');

-- 6. Creating Stored Procedures
-- 6.1. Stored procedure to add user
delimiter $$
create procedure add_user(in in_name varchar(255), in in_email varchar(255), in in_password varchar(255))
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

-- 6.2. Stored procedure to add task
delimiter $$
create procedure add_task(in in_user_id int, in in_title varchar(255), in in_description text, in in_due_date datetime,
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

-- 6.3. Stored procedure for updating a task
delimiter $$
create procedure update_task(in in_task_id int, in in_user_id int, in in_title varchar(255), in in_description text, in in_due_date datetime, in in_priority_id int,
in in_status enum('pending','in_progress','completed','archived'))
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

-- 6.4. Stored procedure for deleting a task
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

-- 6.5. Stored procedure for creating a category
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

-- 6.6. Stored procedure for adding a task to a category
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

-- 6.7. Stored procedure for removing task from category
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

-- 6.8. Stored procedure for deleting a category
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

-- 6.9. Stored Procedure for adding comments to task
delimiter $$
create procedure add_commnet_to_task (in in_task_id int, in in_user_id int, in in_content text)
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

-- 6.10. Stored Procedure to update comments 
delimiter $$
create procedure update_commnet_to_task (in in_task_id int, in in_user_id int, in in_content text)
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

-- 6.11. Stored Procedure to delete comments
delimiter $$
create procedure delete_commnet_to_task (in in_task_id int, in in_user_id int, in in_content text)
begin

declare exit handler for sqlexception
begin
resignal;
end;

if not exists(select 1 from tasks where task_id = in_task_id and user_id = in_user_id)
then signal sqlstate  '45000'
set message_text = 'task does not belong to the user';
end if;

delete from commnets
where task_id = in_task_id and user_id = in_user_id;
end $$

delimiter ;