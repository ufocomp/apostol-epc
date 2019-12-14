# apostol-epc

**Apostol Electro** - RESTful API Service, исходные коды на C++.

СТРУКТУРА КАТАЛОГОВ
-

    auto/               содержит файлы со скриптами
    cmake-modules/      содержит файлы с модулями CMake
    conf/               содержит файлы с настройками
    doc/                содержит файлы с документацией
    ├─www/              содержит файлы с документацией в формате html
    src/                содержит файлы с исходным кодом
    ├─app/              содержит файлы с исходным кодом: Bitcoin Payment Service (Deal Module)
    ├─core/             содержит файлы с исходным кодом: Apostol Core
    ├─lib/              содержит файлы с исходным кодом библиотек
    | └─delphi/         содержит файлы с исходным кодом библиотеки*: Delphi classes for C++
    └─modules/          содержит файлы с исходным кодом дополнений (модулей)
      └─WebService/     содержит файлы с исходным кодом дополнения: Web-сервис

ОПИСАНИЕ
-

**Apostol Electro** (epc) - Построен на базе [Апостол](https://github.com/ufocomp/apostol).

СБОРКА И УСТАНОВКА
-
Для установки **Apostol Electro** Вам потребуется:

1. Компилятор C++;
1. [CMake](https://cmake.org) или интегрированная среда разработки (IDE) с поддержкой [CMake](https://cmake.org);
1. Библиотека [libdelphi](https://github.com/ufocomp/libdelphi/) (Delphi classes for C++);
1. Библиотека [libpq-dev](https://www.postgresql.org/download/) (libraries and headers for C language frontend development);
1. Библиотека [postgresql-server-dev-10](https://www.postgresql.org/download/) (libraries and headers for C language backend development).

###### **ВНИМАНИЕ**: Устанавливать `libdelphi` не нужно, достаточно скачать и разместить в каталоге `src/lib` проекта.

Для того чтобы установить компилятор C++ и необходимые библиотеки на Ubuntu выполните:
~~~
sudo apt-get install build-essential libssl-dev libcurl4-openssl-dev make cmake gcc g++
~~~

Для того чтобы установить PostgreSQL воспользуйтесь инструкцией по [этой](https://www.postgresql.org/download/) ссылке.

###### Подробное описание установки C++, CMake, IDE и иных компонентов необходимых для сборки проекта не входит в данное руководство. 

Для установки **Apostol Electro** (без Git) необходимо:

1. Скачать **Apostol Electro** по [ссылке](https://github.com/ufocomp/epc/archive/master.zip);
1. Распаковать;
1. Скачать **libdelphi** по [ссылке](https://github.com/ufocomp/libdelphi/archive/master.zip);
1. Распаковать в `src/lib/delphi`;
1. Настроить `CMakeLists.txt` (по необходимости);
1. Собрать и скомпилировать (см. ниже).

Для установки **Модуля сделок** с помощью Git выполните:
~~~
git clone https://github.com/ufocomp/epc.git
~~~

Чтобы добавить **libdelphi** в проект с помощью Git выполните:
~~~
cd epc/src/lib
git clone https://github.com/ufocomp/libdelphi.git delphi
cd ../../../
~~~

###### Сборка:
~~~
cd epc
cmake -DCMAKE_BUILD_TYPE=Release . -B cmake-build-release
~~~

###### Компиляция и установка:
~~~
cd cmake-build-release
make
sudo make install
~~~

По умолчанию **epc** будет установлен в:
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

Для запуска Апостол выполните:
~~~
sudo service epc start
~~~

Для проверки статуса выполните:
~~~
sudo service epc status
~~~

Результат должен быть **примерно** таким:
~~~
● epc.service - LSB: starts the epc electro
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

### **Управление epc**.

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
