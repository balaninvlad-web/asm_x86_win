#include <stdio.h>

extern "C" {
    void My_printf(const char *format, ...);
}

int main() {
    // Сначала проверим обычный printf, чтобы убедиться, что консоль работает
    printf("Testing regular printf...\n");
    printf("Testing regular printf...\n");
    
    // Теперь твой My_printf
    My_printf("Char: %c, Percent: %%\n", 'A');
    My_printf("Hello from My_printf!\n");
    My_printf("Percent: %%\n");
    My_printf("Char: %c\n", 'A');
    
    // Ждём нажатия клавиши, чтобы окно не закрылось
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}