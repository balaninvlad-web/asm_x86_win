#include <stdio.h>

extern "C" {
    void My_printf(const char *format, ...);
}

int main() {
    // Сначала проверим обычный printf, чтобы убедиться, что консоль работает
    printf("Testing regular printf...\n");
    printf("Testing regular printf...\n");
    
    My_printf("Hello from My_printf!\n");
    My_printf("Percent: %%\n");
    My_printf("Char: %c\n", 'A');
    My_printf("String: %s \n", "demn amma work");
    My_printf("Digit: %d\n", -300);
    printf("Digit: %d\n", -300);
    My_printf("Hex: %x\n", -300);
    printf("Hex: %x\n", -300);
    My_printf("Oct: %o\n", -300);
    printf("Oct: %o\n", -300);
    My_printf("Bin: %b\n", -300);


    // Ждём нажатия клавиши, чтобы окно не закрылось
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}