Apostol Electro
=

**Apostol Electro** - сервис обработки **Bitcoin** платежей, исходные коды на C++.

СТРУКТУРА КАТАЛОГОВ
-

    auto/               содержит файлы со скриптами
    cmake-modules/      содержит файлы с модулями CMake
    conf/               содержит файлы с настройками
    doc/                содержит файлы с документацией
    ├─www/              содержит файлы с документацией в формате html
    src/                содержит файлы с исходным кодом
    ├─apostol-bitcoin/  содержит файлы с исходным кодом: Apostol Electro
    ├─core/             содержит файлы с исходным кодом: Apostol Core
    ├─lib/              содержит файлы с исходным кодом библиотек
    | └─delphi/         содержит файлы с исходным кодом библиотеки: Delphi classes for C++
    └─modules/          содержит файлы с исходным кодом дополнений (модулей)
      └─BitTrade/       содержит файлы с исходным кодом дополнения: Модуль сделок

ОПИСАНИЕ
-

**Apostol Electro** (ABC) - сервис обработки **Bitcoin** платежей построен на базе [Апостол](https://github.com/ufocomp/apostol).

СБОРКА И УСТАНОВКА
-
Для сборки проекта Вам потребуется:

1. Компилятор C++;
1. [CMake](https://cmake.org) или интегрированная среда разработки (IDE) с поддержкой [CMake](https://cmake.org);
1. Библиотека [libbitcoin-system](https://github.com/libbitcoin/libbitcoin-system/) (Bitcoin Cross-Platform C++ Development Toolkit);
1. Библиотека [libpq-dev](https://www.postgresql.org/download/) (libraries and headers for C language frontend development);
1. Библиотека [postgresql-server-dev-10](https://www.postgresql.org/download/) (libraries and headers for C language backend development).
1. Библиотека [sqllite3](https://www.sqlite.org/download/) (SQLite 3);

Для того чтобы установить компилятор C++ и необходимые библиотеки на Ubuntu выполните:
~~~
sudo apt-get install build-essential libssl-dev libcurl4-openssl-dev make cmake gcc g++
~~~

Для того чтобы установить SQLite3 выполните:
~~~
sudo apt-get install sqlite3 libsqlite3-dev
~~~

Для того чтобы установить PostgreSQL воспользуйтесь инструкцией по [этой](https://www.postgresql.org/download/) ссылке.

###### Подробное описание установки C++, CMake, IDE и иных компонентов необходимых для сборки проекта не входит в данное руководство. 

Для сборки **Апостол Bitcoin**, необходимо:

1. Скачать **Апостол Bitcoin** по [ссылке](https://github.com/ufocomp/apostol-bitcoin/archive/master.zip);
1. Распаковать;
1. Скомпилировать (см. ниже).

Для сборки **Апостол Bitcoin**, с помощью Git выполните:
~~~
git clone https://github.com/ufocomp/apostol-bitcoin.git
~~~

###### Сборка:
~~~
cd apostol-bitcoin
cmake -DCMAKE_BUILD_TYPE=Release . -B cmake-build-release
~~~

###### Компиляция и установка:
~~~
cd cmake-build-release
make
sudo make install
~~~

По умолчанию **Апостол Bitcoin** будет установлен в:
~~~
/usr/sbin
~~~

Файл конфигурации и необходимые для работы файлы будут расположены в: 
~~~
/etc/abc
~~~

ЗАПУСК
-

Апостол - системная служба (демон) Linux. 
Для управления Апостол используйте стандартные команды управления службами.

Для запуска Апостол выполните:
~~~
sudo service abc start
~~~

Для проверки статуса выполните:
~~~
sudo service abc status
~~~

Результат должен быть **примерно** таким:
~~~
● abc.service - LSB: starts the apostol bitcoin
   Loaded: loaded (/etc/init.d/abc; generated; vendor preset: enabled)
   Active: active (running) since Thu 2019-08-15 14:11:34 BST; 1h 1min ago
     Docs: man:systemd-sysv-generator(8)
  Process: 16465 ExecStop=/etc/init.d/abc stop (code=exited, status=0/SUCCESS)
  Process: 16509 ExecStart=/etc/init.d/abc start (code=exited, status=0/SUCCESS)
    Tasks: 3 (limit: 4915)
   CGroup: /system.slice/abc.service
           ├─16520 abc: master process /usr/sbin/abc
           ├─16521 abc: worker process
           └─16522 abc: bitmessage process
~~~

### **Управление abc**.

Управлять **`abc`** можно с помощью сигналов.
Номер главного процесса по умолчанию записывается в файл `/usr/local/abc/logs/abc.pid`. 
Изменить имя этого файла можно при конфигурации сборки или же в `abc.conf` секция `[daemon]` ключ `pid`. 

Главный процесс поддерживает следующие сигналы:

|Сигнал   |Действие          |
|---------|------------------|
|TERM, INT|быстрое завершение|
|QUIT     |плавное завершение|
|HUP	  |изменение конфигурации, запуск новых рабочих процессов с новой конфигурацией, плавное завершение старых рабочих процессов|
|WINCH    |плавное завершение рабочих процессов|	

Управлять рабочими процессами по отдельности не нужно. Тем не менее, они тоже поддерживают некоторые сигналы:

|Сигнал   |Действие          |
|---------|------------------|
|TERM, INT|быстрое завершение|
|QUIT	  |плавное завершение|
