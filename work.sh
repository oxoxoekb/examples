#!/bin/bash

IMDOCKER='post:13'
PATH_DATA="$(pwd)/data"
START_TIME1=$(date +%s%3N)
DEBUG_LEVEL=3

if [[ -z $* ]]
    # Проверяем, что данные не введены и выводим помощь.
        then
            echo -e  "\n
            ОПИСАНИЕ\n
            Скрипт work.sh создает БД в докер контейнере на postgrsql.\n
            Пример: ./work.sh -d [Имя базы данных] -p [Порт] -s [Пароль для postgres]\n
            ОПЦИИ
            -d -определяет название для базы данных.
            -p -определяет порт для БД postgres.
            -s -определяет пароль для пользователя postgres.
            -l -определяет уровень дебага (не обязательный параметр):
                1 - Вывод используемых команд, результатов и затраченного времени;
                2 - Вывод части команд и результатов;
                3 - Тихий режим (по-умолчанию)."
            exit 0
        else
            while getopts "d:p:s:l:" opt
            # getopts позволяет указать ключи необходимые для запуска и присвоить
            # переменным - введенные аргументы.
            do
                case $opt in
                    d)
                        DB_NAME=$OPTARG
                        echo -e "Указано название для базы данных: $OPTARG\n"
                        ;;
                    p)
                        PORT=$OPTARG
                        echo -e "Указан порт для postgres: $OPTARG\n"
                        ;;
                    s)
                        PSWD=$OPTARG
                        echo -e "Указан пароль для пользователя postgres: ********\n"
                        ;;
                    l)
                        DEBUG_LEVEL=$OPTARG
                        echo -e "Выбран уровень дебага: $OPTARG\n"
                        ;;
                    *)
                        echo -e "Для получения справки - не указывайте ключи при запуске скрипта.\n"
                        exit 1
                        ;;
                esac
            done
fi

function renew () {
    # Функция удаляет файл dockerfile и папку data и создает новые.
    # Удаляем образ постгреса, контейнер.
    rm -rf Dockerfile ${PATH_DATA} pg_hba.conf
    touch Dockerfile
    mkdir ${PATH_DATA}
    chown -R 999:999 ${PATH_DATA}
    docker ps -a | grep "${IMDOCKER}" | awk '{print $1}' | xargs docker rm -f
    docker rmi ${IMDOCKER}

}
function conf_post() {
    # Создаем конфиг файл для постгреса и добавляем права на доступ к БД
    rm -rf pg_hba.conf
    touch pg_hba.conf
    cat >pg_hba.conf <<EOF
local all postgres peer
local all all peer
host all all 127.0.0.1/32 md5
host all all ::1/128 md5
local replication all peer
host replication all 127.0.0.1/32 md5
host replication all ::1/128 md5
host $DB_NAME test1 all md5
EOF
    chown 999:999 pg_hba.conf
}

function create_cont () {
    # Создаем dockerfile через EOF на базе postgres:13 и делаем образ. Долой форматирование!
    cat >Dockerfile <<EOF2
FROM postgres:13
#RUN psql -d $DB_NAME -U postgres GRANT SELECT ON $DB_NAME TO test1
MAINTAINER oxoxo
ENV POSTGRES_DB=$DB_NAME \\
    POSTGRES_PASSWORD=$PSWD
COPY pg_hba.conf /etc/postgresql/12/main/pg_hba.conf
EOF2
    docker build -t ${IMDOCKER} .
}
function start_cont () {
    # Запускаем контейнер, монтируем: внешнюю папку для хранения БД, конфиг для доступа к БД.
    docker run -dp $PORT:5432 \
    -v ${PATH_DATA}:/var/lib/postgresql/data/ \
     ${IMDOCKER}
     DCKR=$(docker ps -a | grep $IMDOCKER | awk '{print $1}' )
}

function ggrant () {
    # Берем паузу, для того, чтоб БД успела запуститься.
    # Определяем id контейнера. Передаем в контейнер команды для выдачи прав пользователю.
    sleep 5
    docker exec -it $DCKR psql -U postgres -d $DB_NAME \
        -c "CREATE USER test1 WITH ENCRYPTED PASSWORD 'test1'" \
        -c "GRANT CONNECT ON DATABASE $DB_NAME to test1" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO test1" \
        -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO test1"
}

case $DEBUG_LEVEL in
    # Определяем детализацию вывода в зависимости от параметра DEBUG_LEVEL.
    1)
        echo -e "Подготовка к запуску скрипта.\n"
        START_TIME=$(date +%s%3N)
        renew
        END_TIME=$(date +%s%3N)
        DIFF=$(( $END_TIME - $START_TIME ))
        echo -e "Готово. Подготовка заняла $DIFF мс.\n"
        echo -e "Создаем конфигурационный файл.\n"
        START_TIME=$(date +%s%3N)
        conf_post
        END_TIME=$(date +%s%3N)
        DIFF=$(( $END_TIME - $START_TIME ))
        echo -e "Готово. Конфигурационный файл подготовлен за $DIFF мс.\n"
        echo -e "Создаем контейнер с Postgres.\n"
        START_TIME=$(date +%s%3N)
        create_cont
        END_TIME=$(date +%s%3N)
        DIFF=$(( $END_TIME - $START_TIME ))
        echo -e "Готово. Контейнер собрали за $DIFF мс.\n"
        echo -e "Запускаем контейнер с заданными параметрами.\n"
        START_TIME=$(date +%s%3N)
        start_cont
        END_TIME=$(date +%s%3N)
        DIFF=$(( $END_TIME - $START_TIME ))
        echo -e "Готово. Контейнер запущен за $DIFF мс.\nID контейнера: $DCKR\n"
        echo -e "Выдаем права на чтение пользователю test1.\n"
        START_TIME=$(date +%s%3N)
        ggrant
        END_TIME=$(date +%s%3N)
        DIFF=$(( $END_TIME - $START_TIME ))
        echo -e "Готово. Выдача прав заняла $DIFF мс.\n"
        END_TIME=$(date +%s%3N)
        DIFF=$(( $END_TIME - $START_TIME1 ))
        echo -e "Скрипт выполнен за $DIFF мс."
        ;;
    2)
        echo -e "Подготовка к запуску скрипта.\n"
        renew
        echo -e "Создаем конфигурационный файл.\n"
        conf_post
        echo -e "Создаем контейнер с Postgres.\n"
        create_cont
        echo -e "Запускаем контейнер с заданными параметрами.\n"
        start_cont
        echo -e "Выдаем права на чтение пользователю test1.\n"
        ggrant
        echo "Скрипт выполнен."
        ;;
    3)
        echo -e "Выбран тихий режим.\n"
        renew > /dev/null
        conf_post > /dev/null
        create_cont > /dev/null
        start_cont > /dev/null
        ggrant > /dev/null
        echo "Скрипт выполнен."
        ;;
    *)
        # Если параметр $DEBUG_LEVEL указан отличный от 1,2 или 3, то сообщаем об этом.
        echo -e "Указан некорректный уровень дебага.\n\nСкрипт будет выполнен в тихом режиме.\n"
        renew > /dev/null
        conf_post > /dev/null
        create_cont > /dev/null
        start_cont > /dev/null
        ggrant > /dev/null
        echo "Скрипт выполнен."
        ;;
esac
