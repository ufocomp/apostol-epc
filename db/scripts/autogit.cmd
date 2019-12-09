@ECHO OFF

setlocal

pushd ..

SET GIT=git.exe
SET CHOICE=%CD%\bin\Choice.exe
SET SCRIPTS=%CD%\scripts

SET DOC=%CD%\doc
SET SQL=%CD%\sql
SET LOG=%CD%\log

REM Разбиваем дату на составляющие
SET DD=%DATE:~0,2%
SET MM=%DATE:~3,2%
SET YY=%DATE:~6,4%

REM В 2000 перед датой выводится два символа дня недели, в XP и 2003 нет, поэтому...
SET YX=%DATE:~10,3%

if NOT +%YX% == + (
  REM Это Windows 2000

  SET DD=%DATE:~3,2%
  SET MM=%DATE:~6,2%
  SET YY=%DATE:~9,4%
)

REM ECHO %DATE%
REM ECHO %SCRIPTS%

%GIT% status

%CHOICE% "Будем продолжать?"
if errorlevel 2 goto end

%GIT% add README.md
%GIT% add %DOC%\*.html
%GIT% add %SQL%\*.sql
%GIT% add %SQL%\kernel\*.sql

%GIT% status

%CHOICE% "Будем продолжать?"
if errorlevel 2 goto end

%GIT% commit -m "auto commit: %DD%.%MM%.%YY% %TIME:~0,8%"

%CHOICE% "Будем продолжать?"
if errorlevel 2 goto end

%GIT% push
%GIT% checkout master
%GIT% merge postgres
%GIT% push
%GIT% checkout postgres

pause

:end

popd

endlocal