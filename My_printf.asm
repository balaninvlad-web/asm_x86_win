;:================================================
;: My_printf.asm                    (c)VOV4IK,2026
;:================================================
; My_printf – аналог printf для Windows x64 (NASM)
; Поддерживает форматы: %c, %s, %d, %u, %x, %o, %b (двоичный), %%

;nasm -f win64 My_printf.asm -o My_printf.obj -l "My_printf.lst"


; Импортируем функции из kernel32.dll
extern GetStdHandle         ; получить хендл
extern WriteConsoleA        ; ф_ция записи в консоль 

section .data
    hConsole dq 0          ; переменная для хэндла

section .text
global My_printf:          ; глобальная видна при линковке с Си кодом

; ============================================================================
; My_printf – главная функция
; Вход:  RCX = форматная строка (const char*)
;        RDX = 1-й аргумент (для %d, %c и т.д.)
;        R8  = 2-й аргумент
;        R9  = 3-й аргумент
;        [RSP+40] = 4-й аргумент, далее по стеку (соглашение Windows x64)
; Выход: нет (void)
; Регистры: сохраняет все используемые (r9, r8, rdx, rcx, rsi, rdi, rbp)
; ============================================================================
My_printf:        
        push r9
        push r8
        push rdx           ; 1-й аргумент      
        push rcx           ; фотматная строка
        push rsi
        push rdi
        push rbp
        ; восстанавливаем указатели на аргументы из стека
        mov rdi, [rsp+24]  ; RCX
        lea rbp, [rsp + 32]; 1-й аргумент
        ; получаю хендл консольного вывода 
        cmp qword [rel hConsole], 0
        jne .print_loop
        mov ecx, -11       ; STD_OUTPUT_HANDLE
        call GetStdHandle
        mov [rel hConsole], rax

; основной цикл вывода форматной строки
.print_loop:
        cmp byte [rdi], 0
        je .eoprnt        ; \0      

        cmp byte [rdi], '%'
        je .print_value   
        ; прямой обычный вывод
        mov al, [rdi]
        inc rdi
        call Print_char
        jmp .print_loop

.print_value:
        inc rdi             ; пропуск %
        call Print_value    ;обработка спецификатора
        inc rdi             ; пропус спецификатора
        jmp .print_loop
.eoprnt:
        pop rbp
        pop rdi
        pop rsi
        pop rcx
        pop rdx
        pop r8
        pop r9

        ret
; ============================================================================
; Print_value – диспетчер спецификаторов
; Вход:  RDI указывает на символ после '%'
;        RBP указывает на текущий аргумент
; Выход: RBP сдвинут на 8 
;        RDI не меняется 
; ============================================================================
Print_value:
        ; обрабатываю %
        cmp byte [rdi], '%'
        je .print_procent
        ; проверка на [a-z]
        cmp byte [rdi], 'a'
        jb .erorr

        cmp byte [rdi], 'z'
        ja .erorr
        ; вычисление индекса для таблицы переходов
        xor rcx, rcx
        mov cl, [rdi]
        sub cl, 'a'                    ; rcx = индекс от 0 до 25
        shl rcx, 3                     ; умножаем на 8 (размер qword)
        lea rax, [rel jump_table]      ; загружаем RIP-relative адрес таблицы
        mov rcx, [rax + rcx]           ; загружаем адрес обработчика
        jmp rcx
; обработка %
.print_procent:
        mov al, '%'
        call Print_char
        jmp .jmp_after_output
; обработка ошибочного символа
.erorr:
        mov al, '%'
        call Print_char
        mov al, [rdi]   ; символ типа
        call Print_char
        inc rdi
        inc rdi
        jmp .jmp_after_output

; общая точка выхода после обработки спецификатора
.jmp_after_output:
        add rbp, 8
        ret
; обработка %с
Print_char_func:
        mov al, byte [rbp]   
        call Print_char
        jmp Print_value.jmp_after_output

; обработка дефолтного кейса
Default_case:
        mov al, '?'
        call Print_char
        inc rdi
.jmp_after_output:

; обработка %s
Print_string:
        push rdi            ; соханяю rdi
        mov rdi, [rbp]      ; и кладу туда ардес из аргумента
.print_str_loop:
        cmp byte [rdi], 0
        je .eoprnt
        mov al, byte [rdi]
        call Print_char
        inc rdi
        jmp .print_str_loop
.eoprnt:
        pop rdi             ; восстанавливаю
        jmp Print_value.jmp_after_output 
        
; ============================================================================
; Print_char – вывод одного символа через WriteConsoleA
; Вход: AL – символ для вывода
; ============================================================================

Print_char:
        ; сохраняю регисты котрые может испортить функция WriteConsoleA
        push rax
        push rcx
        push rdx
        push r8
        push r9
        push r10
        push r11
        ; помещаю символ в буффер
        mov [rel out_char_buf], al

        sub rsp, 32                     ; резервирую под WriteConsole
        mov rcx, [rel hConsole]         ; хендл консоли
        lea rdx, [rel out_char_buf]     ; адрес буфера
        mov r8d, 1                      ; количесво выводимых символов
        lea r9, [rel written]           ; указатель на переменную 
        mov qword [rsp], 0              ; резерв обоссаный ублюдок
        call WriteConsoleA
        add rsp, 32                      ; освобождаю стек

        pop r11
        pop r10
        pop r9
        pop r8
        pop rdx
        pop rcx
        pop rax
        ret

; ============================================================================
; Обработчики числовых форматов: %d, %u, %x, %o, %b
; Каждый загружает значение из аргумента, расширяет знак для %d,
; и вызывает универсальную функцию Print_number.
; ============================================================================
Print_binary:
        mov rax, [rbp]
        mov rdx, 2          ; основание
        xor rcx, rcx        ; флаг беззнаковости
        call Print_number
        jmp Print_value.jmp_after_output

Print_decimal:
        Print_decimal:
        mov eax, [rbp]      
        cdqe                ; расширю знак до 64 бит (изначально лежит 32битное)
        mov rdx, 10         ; основание
        mov rcx, 1          ; флаг знаковости
        call Print_number
        jmp Print_value.jmp_after_output

Print_oct:
        mov rax, [rbp]
        mov rdx, 8          ; основание 
        xor rcx, rcx        ; флаг беззнаковости
        call Print_number
        jmp Print_value.jmp_after_output

Print_hex:
        mov rax, [rbp]
        mov rdx, 16         ; я заколебался уже понятно
        xor rcx, rcx  
        call Print_number
        jmp Print_value.jmp_after_output

Print_unsigned:
        mov rax, [rbp]
        mov rdx, 10
        xor rcx, rcx
        call Print_number
        jmp Print_value.jmp_after_output

; ============================================================================
; Print_number – преобразвывает число в строку и выводит
; Вход:  RAX = 64-битное число (для знаковых – уже расширенное)
;        RDX = основание системы счисления (2, 8, 10, 16)
;        RCX = 1 если нужно выводить знак (для %d), иначе 0
; ============================================================================
Print_number:
        push rbx
        push rcx
        push rdx
        push rsi
        push rdi

        ; Проверка на отрицательное и знак
        test rcx, rcx
        jz .unsigned
        test rax, rax
        jns .positive
        ; отрицательное: выводим минус, берём модуль
        push rax
        mov al, '-'
        call Print_char
        pop rax
        neg rax
.positive:
.unsigned:
        mov rbx, rdx                   ; сохраняю основание

        ; Буфер в number_buf, заполняем с конца
        lea rsi, [rel number_buf + 31] ; указатель на последний байт буфера
        mov byte [rsi], 0              ; терминатор

        ; Особый случай: ноль
        test rax, rax
        jnz .convert_loop
        mov al, '0'
        call Print_char
        jmp .done

.convert_loop:
        xor rdx, rdx
        div rbx                 ; rax = частное, rdx = остаток
        ; Преобразуем остаток в символ
        cmp dl, 9
        jbe .digit
        add dl, 'A' - 10       ; для основания 16
        jmp .store
.digit:
        add dl, '0'
.store:
        dec rsi                ; сдвиг указателя
        mov [rsi], dl          ; сохранение цифры в буффер
        test rax, rax
        jnz .convert_loop

        ; Вывожу цифры из буфера
.print_digits:
        mov al, [rsi]
        cmp al, 0
        je .done
        call Print_char
        inc rsi
        jmp .print_digits

.done:
        pop rdi
        pop rsi
        pop rdx
        pop rcx
        pop rbx
        ret
; ============================================================================
; Неинициализированные данные (BSS)
; ============================================================================
section .bss
    out_char_buf resb 1          ; буфер для одного символа (используется в Print_char)
    written resd 1               ; сюда WriteConsoleA пишет количество выведенных символов
    number_buf resb 32           ; буфер для преобразования чисел (до 32 цифр)

section .data
; ============================================================================
; Таблица переходов для спецификаторов от 'a' до 'z'
; ============================================================================
jump_table:
        dq Default_case            ; a
        dq Print_binary            ; b
        dq Print_char_func        ; c
        dq Print_decimal           ; d
        dq Default_case            ; e
        dq Default_case            ; f
        dq Default_case            ; g
        dq Default_case            ; h
        dq Default_case            ; i
        dq Default_case            ; j
        dq Default_case            ; k
        dq Default_case            ; l
        dq Default_case            ; m
        dq Default_case            ; n
        dq Print_oct               ; o
        dq Default_case            ; p
        dq Default_case            ; q
        dq Default_case            ; r
        dq Print_string            ; s
        dq Default_case            ; t
        dq Print_unsigned          ; u
        dq Default_case            ; v
        dq Default_case            ; w
        dq Print_hex               ; x
        dq Default_case            ; y
        dq Default_case            ; z