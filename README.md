Apostol Electro
=

**Apostol Electro** - исходные коды на C++.

СТРУКТУРА КАТАЛОГОВ
-

    auto/               содержит файлы со скриптами
    cmake-modules/      содержит файлы с модулями CMake
    conf/               содержит файлы с настройками
    db/                 содержит файлы с исходным кодом базы данных
    ├─bin/              содержит файлы для автоматизации установки базы данных
    ├─doc/              содержит файлы с документацией для базы данных
    | └─html/           содержит файлы с документацией в формате html
    ├─log/              содержит файлы с отчетами (логами) установки
    ├─scripts/          содержит скрипты для автоматизации установки
    ├─sql/              содержит файлы для создания базы данных
    src/                содержит файлы с исходным кодом
    ├─core/             содержит файлы с исходным кодом: Apostol Core
    ├─epc/              содержит файлы с исходным кодом: Apostol Electro
    ├─lib/              содержит файлы с исходным кодом библиотек
    | └─delphi/         содержит файлы с исходным кодом библиотеки: Delphi classes for C++
    └─modules/          содержит файлы с исходным кодом дополнений (модулей)
      └─Electro/        содержит файлы с исходным кодом дополнения: Сервера приложений

ОПИСАНИЕ
-

**Apostol Electro** (epc) - сервер приложений построен на базе [Апостол](https://github.com/ufocomp/apostol).

СБОРКА И УСТАНОВКА
-
Для сборки проекта Вам потребуется:

1. Компилятор C++;
1. [CMake](https://cmake.org) или интегрированная среда разработки (IDE) с поддержкой [CMake](https://cmake.org);
1. Библиотека [libelectro-system](https://github.com/libelectro/libelectro-system/) (Bitcoin Cross-Platform C++ Development Toolkit);
1. Библиотека [libpq-dev](https://www.postgresql.org/download/) (libraries and headers for C language frontend development);
1. Библиотека [postgresql-server-dev-10](https://www.postgresql.org/download/) (libraries and headers for C language backend development).

Для того чтобы установить компилятор C++ и необходимые библиотеки на Ubuntu выполните:
~~~
sudo apt-get install build-essential libssl-dev libcurl4-openssl-dev make cmake gcc g++
~~~

Для того чтобы установить PostgreSQL воспользуйтесь инструкцией по [этой](https://www.postgresql.org/download/) ссылке.

###### Подробное описание установки C++, CMake, IDE и иных компонентов необходимых для сборки проекта не входит в данное руководство. 

Для сборки **Apostol Electro**, необходимо:

1. Скачать **Apostol Electro** по [ссылке](https://github.com/ufocomp/apostol-electro/archive/master.zip);
1. Распаковать;
1. Скомпилировать (см. ниже).

Для сборки **Apostol Electro**, с помощью Git выполните:
~~~
git clone https://github.com/ufocomp/apostol-electro.git
~~~

###### Сборка:
~~~
cd apostol-electro
cmake -DCMAKE_BUILD_TYPE=Release . -B cmake-build-release
~~~

###### Компиляция и установка:
~~~
cd cmake-build-release
make
sudo make install
~~~

По умолчанию **Apostol Electro** будет установлен в:
~~~
/usr/sbin
~~~

Файл конфигурации и необходимые для работы файлы будут расположены в: 
~~~
/etc/epc
~~~

ЗАПУСК
-

Апостол - системная служба (демон) Linux. 
Для управления Апостол используйте стандартные команды управления службами.

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
● epc.service - LSB: starts the apostol electro
   Loaded: loaded (/etc/init.d/epc; generated; vendor preset: enabled)
   Active: active (running) since Thu 2019-08-15 14:11:34 BST; 1h 1min ago
     Docs: man:systemd-sysv-generator(8)
  Process: 16465 ExecStop=/etc/init.d/epc stop (code=exited, status=0/SUCCESS)
  Process: 16509 ExecStart=/etc/init.d/epc start (code=exited, status=0/SUCCESS)
    Tasks: 3 (limit: 4915)
   CGroup: /system.slice/epc.service
           ├─16520 epc: master process /usr/sbin/epc
           ├─16521 epc: worker process
           └─16522 epc: bitmessage process
~~~

### **Управление epc**.

Управлять **`epc`** можно с помощью сигналов.
Номер главного процесса по умолчанию записывается в файл `/usr/local/epc/logs/epc.pid`. 
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
