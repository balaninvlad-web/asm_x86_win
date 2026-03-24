extern GetStdHandle
extern WriteConsoleA

section .data
    hConsole dq 0          ; переменная для хэндла

section .text
default rel  ; ассемблер перед каждым обращением к переменной по умолчанию 
             ; ставит rel что заставляем фыь использовать отросительную адрессацию
global My_printf

;        rdi   = форматная строка (формально первый    аргумент функции)
;        rsi   = 1 аргумент       (формально второй    аргумент функции)
;        rdx   = 2 аргумент       (формально третий    аргумент функции)
;        rcx   = 3 аргумент       (формально четвертый аргумент функции)
;        r8    = 4 аргумент       (формально пятый     аргумент функции)
;        r9    = 5 аргумент       (формально шестой    аргумент функции)
;        stack>= 6 аргументы  

My_printf:        
        push r10
        push r9
        push r8
        push rdx
        push rcx
        push rsi
        push rdi
        push rbp

        mov rdi, [rsp+24]
        lea rbp, [rsp + 32]

        cmp qword [rel hConsole], 0
        jne .got_handle
        mov ecx, -11           ; STD_OUTPUT_HANDLE
        call GetStdHandle
        mov [rel hConsole], rax
.got_handle:        

        xor r10, r10

.print_loop:
        cmp byte [rdi], 0
        je .eoprnt

        cmp byte [rdi], '%'
        je .print_value
        mov al, [rdi]
        inc rdi
        call Print_char
        jmp .print_loop
.print_value:
        inc rdi
        call Print_value
        inc rdi
        jmp .print_loop
.eoprnt:
        pop rbp
        pop rdi
        pop rsi
        pop rcx
        pop rdx
        pop r8
        pop r9
        pop r10

        ret

Print_value:
        cmp byte [rdi], '%'
        je .print_procent
        cmp byte [rdi], 'a'
        jb .erorr

        cmp byte [rdi], 'z'
        ja .erorr

                xor rcx, rcx
        mov cl, [rdi]
        sub cl, 'a'                    ; rcx = индекс от 0 до 25
        shl rcx, 3                     ; умножаем на 8 (размер qword)
        lea rax, [rel jump_table]      ; загружаем RIP-relative адрес таблицы
        mov rcx, [rax + rcx]           ; загружаем адрес обработчика
        jmp rcx

.jmp_after_output:
        add rbp, 8
        ret

.print_procent:
        mov al, '%'
        call Print_char
        jmp .jmp_after_output

.erorr:
        mov al, '%'
        call Print_char
        mov al, [rdi]   ; символ типа
        call Print_char
        inc rdi
        inc rdi
        jmp .jmp_after_output

Print_char_func:
        mov al, byte [rbp]   
        call Print_char
        jmp Print_value.jmp_after_output

Print_string:
        push rdi
        mov rdi, [rbp]
.print_str_loop:
        cmp byte [rdi], 0
        je .eoprnt
        mov al, byte [rdi]
        call Print_char
        inc rdi
        jmp .print_str_loop
.eoprnt:
        pop rdi
        jmp Print_value.jmp_after_output

Print_char:
        push rax
        push rcx
        push rdx
        push r8
        push r9
        push r10
        push r11

        mov [rel out_char_buf], al

        sub rsp, 32 ; резервируем под WriteConsole
        mov rcx, [rel hConsole]
        lea rdx, [rel out_char_buf] ; адрес буфера
        mov r8d, 1 ; количесво выводимых символов
        lea r9, [rel written] ; указатель на переменную 
        mov qword [rsp], 0
        call WriteConsoleA
        add rsp, 32 ; освобождаем

        pop r11
        pop r10
        pop r9
        pop r8
        pop rdx
        pop rcx
        pop rax
        ret

Default_case:
        mov al, '?'
        call Print_char
        inc rdi
.jmp_after_output:

Print_binary:
        mov rax, [rbp]
        mov rdx, 2
        xor rcx, rcx    
        call Print_number
        jmp Print_value.jmp_after_output

Print_decimal:
        Print_decimal:
        mov eax, [rbp]      ; 32-битное значение
        cdqe                ; расширяем знак до 64 бит
        mov rdx, 10
        mov rcx, 1
        call Print_number
        jmp Print_value.jmp_after_output

Print_oct:
        mov rax, [rbp]
        mov rdx, 8
        xor rcx, rcx
        call Print_number
        jmp Print_value.jmp_after_output

Print_hex:
        mov rax, [rbp]
        mov rdx, 16
        xor rcx, rcx  
        call Print_number
        jmp Print_value.jmp_after_output

Print_unsigned:
        mov rax, [rbp]
        mov rdx, 10
        xor rcx, rcx
        call Print_number
        jmp Print_value.jmp_after_output

Print_number:
        ; Вход: rax = число, rdx = основание, rcx = 1 если выводить знак (иначе 0)
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
        mov rbx, rdx            ; сохраняем основание

        ; Буфер в number_buf, заполняем с конца
        lea rsi, [rel number_buf + 31]
        mov byte [rsi], 0       ; терминатор

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
        add dl, 'A' - 10
        jmp .store
.digit:
        add dl, '0'
.store:
        dec rsi
        mov [rsi], dl
        test rax, rax
        jnz .convert_loop

        ; Выводим цифры из буфера
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
section .bss
    out_char_buf resb 1    ; буфер для одного символа
    written resd 1         ; переменная для записи количества выведенных символов
    number_buf resb 32     ; буффер для вывода и пербразования числа 

section .data

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