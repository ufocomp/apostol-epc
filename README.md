# EPC Electro

**EPC Electro** - RESTful API Service, исходные коды на C++.

СТРУКТУРА КАТАЛОГОВ
-
    auto/                       содержит файлы со скриптами
    cmake-modules/              содержит файлы с модулями CMake
    conf/                       содержит файлы с настройками
    db/                         содержит файлы со скриптами базы данных
    ├─bin/                      содержит исполняемые файлы для автоматизации установки базы данных
    ├─scripts/                  содержит файлы со скриптами для автоматизации установки базы данных
    ├─sql/                      содержит файлы со скриптами базы данных
    | └─kernel/                 содержит файлы со скриптами базы данных: Ядро
    doc/                        содержит файлы с документацией
    src/                        содержит файлы с исходным кодом
    ├─app/                      содержит файлы с исходным кодом: EPC Electro
    ├─core/                     содержит файлы с исходным кодом: Apostol Core
    ├─lib/                      содержит файлы с исходным кодом библиотек
    | └─delphi/                 содержит файлы с исходным кодом библиотеки*: Delphi classes for C++
    ├─workers/                  содержит файлы с исходным кодом дополнений (модулей)
    | └─WebService/             содержит файлы с исходным кодом дополнения: Веб-сервис
    ├─helpers/                  содержит файлы с исходным кодом дополнений (модулей)
    | └─CertificateDownloader/  содержит файлы с исходным кодом дополнения: Загрузчик сертификатов
    www/                        содержит файлы с Веб-сайтом

ОПИСАНИЕ
-

**EPC Electro** (epc) - Построен на базе [Апостол](https://github.com/ufocomp/apostol).

REST API
-

[Документация по REST API](./doc/REST-API-ru.md)

Протестировать API **EPC Electro** можно с помощью встроенного Web-сервера доступного по адресу: [localhost:8080](http://localhost:8080)

СБОРКА И УСТАНОВКА
-
Для установки **EPC Electro** Вам потребуется:

Для сборки проекта Вам потребуется:

1. Компилятор C++;
1. [CMake](https://cmake.org) или интегрированная среда разработки (IDE) с поддержкой [CMake](https://cmake.org);
1. Библиотека [libpq-dev](https://www.postgresql.org/download) (libraries and headers for C language frontend development);
1. Библиотека [postgresql-server-dev-10](https://www.postgresql.org/download) (libraries and headers for C language backend development).
1. Библиотека [libdelphi](https://github.com/ufocomp/libdelphi) (Delphi classes for C++);

###### **ВНИМАНИЕ**: Устанавливать `libdelphi` не нужно, достаточно скачать и разместить в каталоге `src/lib` проекта.

### Linux (Debian/Ubuntu)

Для того чтобы установить компилятор C++ и необходимые библиотеки на Ubuntu выполните:
~~~
$ sudo apt-get install build-essential libssl-dev libcurl4-openssl-dev make cmake gcc g++
~~~

###### Подробное описание установки C++, CMake, IDE и иных компонентов необходимых для сборки проекта не входит в данное руководство. 

#### PostgreSQL

Для того чтобы установить PostgreSQL воспользуйтесь инструкцией по [этой](https://www.postgresql.org/download/) ссылке.

#### База данных `epc`

Для того чтобы установить базу данных необходимо выполнить:

1. Прописать наименование базы данных в файле db/sql/sets.conf (по умолчанию: epc)
1. Прописать пароли для пользователей СУБД [libpq-pgpass](https://postgrespro.ru/docs/postgrespro/11/libpq-pgpass):
   ~~~
   $ sudo -iu postgres -H vim .pgpass
   ~~~
   ~~~
   *:*:*:kernel:kernel
   *:*:*:admin:admin
   *:*:*:daemon:daemon
   ~~~
1. Указать в файле настроек /etc/postgresql/<version>/main/postgresql.conf:
   Пути поиска схемы kernel:
   ~~~
   search_path = '"$user", kernel, public'	# schema names
   ~~~
1. Указать в файле настроек /etc/postgresql/<version>/main/pg_hba.conf:
   ~~~
   # TYPE  DATABASE        USER            ADDRESS                 METHOD
   local	all		kernel					md5
   local	all		admin					md5
   local	all		daemon					md5
    
   host	all		kernel		127.0.0.1/32		md5
   host	all		admin		127.0.0.1/32		md5
   host	all		daemon		127.0.0.1/32		md5   
   ~~~
1. Выполнить:
   ~~~
   $ cd db/
   $ ./install.sh --make
   ~~~

###### Параметр `--make` необходим для установки базы данных в первый раз. Далее установочный скрипт можно запускать или без параметров или с параметром `--install`.

Для установки **EPC Electro** (без Git) необходимо:

1. Скачать **EPC Electro** по [ссылке](https://github.com/ufocomp/apostol-epc/archive/master.zip);
1. Распаковать;
1. Скачать **libdelphi** по [ссылке](https://github.com/ufocomp/libdelphi/archive/master.zip);
1. Распаковать в `src/lib/delphi`;
1. Настроить `CMakeLists.txt` (по необходимости);
1. Собрать и скомпилировать (см. ниже).

Для установки **EPC Electro** с помощью Git выполните:
~~~
$ git clone https://github.com/ufocomp/apostol-epc.git epc
~~~

Чтобы добавить **libdelphi** в проект с помощью Git выполните:
~~~
$ cd epc/src/lib
$ git clone https://github.com/ufocomp/libdelphi.git delphi
$ cd ../../../
~~~

###### Сборка:
~~~
$ cd epc
$ cmake -DCMAKE_BUILD_TYPE=Release . -B cmake-build-release
~~~

###### Компиляция и установка:
~~~
$ cd cmake-build-release
$ make
$ sudo make install
~~~

По умолчанию бинарный файл `epc` будет установлен в:
~~~
/usr/sbin
~~~

Файл конфигурации и необходимые для работы файлы, в зависимости от варианта установки, будут расположены в: 
~~~
/etc/epc
или
~/epc
~~~

ЗАПУСК 
-
###### Если `INSTALL_AS_ROOT` установлено в `ON`.

**`epc`** - это системная служба (демон) Linux. 
Для управления **`epc`** используйте стандартные команды управления службами.

Для запуска `epc` выполните:
~~~
$ sudo service epc start
~~~

Для проверки статуса выполните:
~~~
$ sudo service epc status
~~~

Результат должен быть **примерно** таким:
~~~
● epc.service - LSB: starts the ship safety servcie
   Loaded: loaded (/etc/init.d/epc; generated; vendor preset: enabled)
   Active: active (running) since Thu 2019-08-15 14:11:34 BST; 1h 1min ago
     Docs: man:systemd-sysv-generator(8)
  Process: 16465 ExecStop=/etc/init.d/epc stop (code=exited, status=0/SUCCESS)
  Process: 16509 ExecStart=/etc/init.d/epc start (code=exited, status=0/SUCCESS)
    Tasks: 3 (limit: 4915)
   CGroup: /system.slice/epc.service
           ├─16520 epc: master process /usr/sbin/abc
           └─16521 epc: worker process
~~~

### **Управление**.

Управлять **`epc`** можно с помощью сигналов.
Номер главного процесса по умолчанию записывается в файл `/run/epc.pid`. 
Изменить имя этого файла можно при конфигурации сборки или же в `epc.conf` секция `[daemon]` ключ `pid`. 

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
