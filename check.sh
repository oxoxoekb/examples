#!/bin/bash

#Указываем аргументы.
TARGET_URL=$1
DEBUG_LEVEL=$2 #Можно задать через переменные окружения.

function curly_curly (){
    #Функция делает запрос к URL и определяет код ответа.
        echo -e "Делаю запрос к $TARGET_URL\n"
        curly_code=$(curl -LIs $TARGET_URL -o /dev/null -w '%{http_code}')
            #Ключи:
                #-o/--output <file> - Вывод в указанный путь.
                #-w/--write-out <format> - Определяет данные, которые будут выданы в stdout при успехе.
                #http_code - Код ответа от ресурса.
                # -s/--silent - Тихий режим.
                # -L/ - Если есть редирект, то повторяет запрос по новому расположению.
                #       С ключом -i выводит заголовки со всех ресурсов.
                # -I/ - Включает в вывод http-заголовок.
}

function get_html (){
    #Функция выкачивает всю страницу в html файл.
        #Указываем путь для сохранения файла. //Можно добавить его как глобальную переменную или брать из env.
            path_html=/home/oxoxo/scripts/"$TARGET_URL".html
        #Сохраняем содержимое вывода в файл $path_html.
            get_html=$(curl -sL $TARGET_URL -o $path_html)
                #Ключи см. выше.
        #Вывод на экран текста.
            echo Страница скачана в "$path_html"
}

function search_url (){
    #Функция поиска URL на указанном сайте.
        search_done=$(curl -sL $TARGET_URL | grep -wo "http[s]*[^/]\/\/[^/|^?|^:|^\"]*\/[^/|^?|^\"|^&]*")
            #Ключи для grep:
            #-w - ищет выражение как слово.
            #-o - показывает только ту часть совпадающей строки, которая соответствует запросу.
}

function nsl (){
    #Функция определяет IP-адрес узла.
        echo "Определяю IP-адрес узла $TARGET_URL"
        dns_adr=$(dig $TARGET_URL +short)
            #+short - выводит только IP-адрес, без лишней информации.
        echo -e "$dns_adr\n"
}

function check_code (){
    #Функция по http-коду определяет, что нужно будет сделать.
        if (( "$curly_code" == 200 ))
            #Если код 200, то выполняет по очереди две функции и выводим результат.
                then curly_curly && search_url
                    echo **********"Вывожу список ссылок $TARGET_URL"**********
                    echo "$search_done"
                    echo **********"Вывод ссылок завершен"**********
        elif (( "$curly_code" == 000 ))
            #Если код 000, то выводим ошибку (url не найден).
                then
                    echo "Узел не найден, введите корректный адрес"
                else get_html
fi
}

if [[ -z "$TARGET_URL" ]]
    #Проверяем, что URl указан. Если не указан, то сообщаем об этом.
        then
            echo "Людка, тащи ключ, у нас ОТМЕНА"
            echo "Укажите URL проверяемого узла"
            exit
        else
            echo -e "Данный URL принят\n"
fi

case $DEBUG_LEVEL in
    #Определяем детализацию вывода в зависимости от параметра DEBUG_LEVEL.
        1)
            curly_curly
            echo -e "Установлен уровень дебага $DEBUG_LEVEL\n"
            echo -e "Код ответа от $TARGET_URL = $curly_code\n"
            nsl
            check_code
            ;;
        2)
            curly_curly
            echo -e "Установлен уровень дебага $DEBUG_LEVEL\n"
            echo -e "$curly_code\n"
            check_code
            ;;
        3)
            curly_curly > /dev/null
            echo -e "Установлен уровень дебага $DEBUG_LEVEL\n"
            echo "Silent mode"
            check_code
            exit
            ;;
        $())
            #Если параметр $DEBUG_LEVEL не указан, то сообщаем об этом.
                echo "Людка, тащи ключ, у нас ОТМЕНА"
                echo "Укажите переменную DEBUG_LEVEL"
                ;;
esac
