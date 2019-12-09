SELECT Login('admin', 'admin');

SELECT CreateDepartment(null, GetDepartmentType('main'), '0000000000', 'ООО "Наименование фирмы"');

SELECT AddMemberToDepartment(current_userid(), GetDepartment('0000000000'));
SELECT AddMemberToDepartment(GetUser('mailbot'), GetDepartment('0000000000'));
SELECT AddMemberToDepartment(GetUser('apibot'), GetDepartment('0000000000'));
SELECT AddMemberToDepartment(GetUser('ocpp'), GetDepartment('0000000000'));

SELECT SetDefaultDepartment(GetDepartment('0000000000'));
SELECT SetDepartment(GetDepartment('0000000000'));

SELECT CreateClassTree();
SELECT CreateObjectType();
SELECT KernelInit();

SELECT FillCalendar(CreateCalendar(null, GetType('workday.calendar'), 'default', 'Календарь рабочих дней', 5, ARRAY[6,7], ARRAY[[1,1], [1,7], [2,23], [3,8], [5,1], [5,9], [6,12], [11,4]], '9 hour', '9 hour', '13 hour', '1 hour', 'Календарь рабочих дней.'), '2019/01/01', '2019/12/31');

SELECT Logout();