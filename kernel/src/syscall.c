#include "syscall.h"
#include "stdfuncs.h"

uint8_t *const ch_mem = (uint8_t *)VGA_CHAR_OFFSET;
uint8_t *const color_mem = (uint8_t *)VGA_COLOR_OFFSET;
uint32_t *const idt_mem = (uint32_t *)IDT_OFFSET;
volatile uint32_t sys_time = 0;

uint32_t monitor_write_cursor = 0;
uint32_t output_front_cursor = 0;

void wait_ms(uint32_t ms)
{
    uint32_t start_time = sys_time;
    while (sys_time - start_time < ms)
        ;
}

void putc(const char c, const uint8_t color)
{
    if (c == '\n')
    {
        monitor_write_cursor = (monitor_write_cursor / COL_CNT) * (COL_CNT) + COL_CNT;
        if (monitor_write_cursor == TOTAL_CHAR + vga_info.extra_line_cnt * COL_CNT)
            scroll_screen();
        if (monitor_write_cursor == TOTAL_CHAR_WITH_BUF)
            monitor_write_cursor = 0;
    }
    else if (c == '\t')
        print("    ", COLOR_WHITE);
    else if (c == '\b')
    {
        if (output_front_cursor < monitor_write_cursor)
            _erasec(--monitor_write_cursor);
    }
    else
    {
        _setc(c, color, monitor_write_cursor++);
        if (monitor_write_cursor == TOTAL_CHAR)
            scroll_screen();
        if (monitor_write_cursor == TOTAL_CHAR_WITH_BUF)
            monitor_write_cursor = 0;
    }
    _update_cursor();
}

void print(const char *str, const uint8_t color)
{
    char c = *str;
    while (c)
    {
        putc(c, color);
        ++str;
        c = *str;
    }
}

char getc()
{
    while (!_next_key_arrived())
        ; //wait input
    char c = kb_info.c;
    input_controller.pre_c = c;
    input_controller.input_time = sys_time;
    putc(c, COLOR_WHITE);
    return c;
}

void getline(char *buf)
{
    char c;
    int i = 0;
    while ((c = getc()) != '\n')
    {
        if (c == '\b')
        {
            if (i > 0)
                buf[--i] = '\0';
        }
        else
        {
            buf[i++] = c;
        }
    }
    buf[i] = '\0';
}

bool is_ctrl_c()
{
    return kb_info.c == 'c' && kb_info.is_ctrl;
}

void scroll_screen()
{
    vga_info.extra_line_cnt++;
    if (vga_info.extra_line_cnt == ROW_CNT)
        vga_info.extra_line_cnt = 0;
    for (int i = monitor_write_cursor; i < monitor_write_cursor + COL_CNT; ++i)
        _setc(' ', COLOR_WHITE, i);
    _update_cursor();
    *p_vga_info = vga_info;
}

void clear_screen()
{
    int i = vga_info.extra_line_cnt * COL_CNT;
    int end = i + TOTAL_CHAR;
    for (; i < end; ++i)
        _setc(' ', COLOR_WHITE, i);
}

static void _update_cursor()
{
    uint32_t r, c;
    _udiv_mod(monitor_write_cursor, COL_CNT, &r, &c);
    vga_info.cursor_y = CHAR_HEIGHT * r + 1;
    if (c != COL_CNT - 1)
        vga_info.cursor_x = CHAR_WIDTH * c + 1;
    else
        vga_info.cursor_x = 1;
    *p_vga_info = vga_info;
}

inline void lock_output_front() { output_front_cursor = monitor_write_cursor; }
inline static void _setc(const char c, const uint8_t color, const uint32_t addr)
{
    ch_mem[addr] = c;
    color_mem[addr] = color;
}
inline static void _erasec(const uint32_t addr)
{
    ch_mem[addr] = 0;
    color_mem[addr] = 0;
}
inline void error(const char *msg)
{
    print("Error: ", COLOR_RED);
    print(msg, COLOR_WHITE);
}

static inline bool _next_key_arrived()
{
    if (kb_info.c)
    {
        if (kb_info.c == input_controller.pre_c)
            return sys_time - input_controller.input_time > KEY_REPEAT_INTERVAL;
        else
            return kb_info.c != '\0';
    }
    else
        return false;
}

static uint32_t* HEX = (uint32_t*)SEG7_OFFSET;
static uint32_t* p_LEDR = (uint32_t*)LEDR_OFFSET; 
static uint32_t num2hexoutdict[] = {0x40, 0x79, 0x24, 0x30, 0x19, 0x12, 0x2, 0x78, 
                                        ~0x7f&0x7f, ~0x6f&0x7f, ~0x77&0x7f, ~0x7c&0x7f, ~0x39&0x7f, ~0x5e&0x7f, ~0x79&0x7f, ~0x71&0x7f};
inline uint32_t num2hexout(uint32_t num)
{
    if(num <= 0xF)
        return num2hexoutdict[num];
    else
        return 0x55;
}
void set_hex(uint32_t hex, uint32_t id)
{
    HEX[id] = num2hexout(hex);
}
void set_ledr(uint32_t id, bool is_on)
{
    uint32_t ledr = *p_LEDR;
    if(is_on)
        ledr |= (1 << id);
    else
        ledr &= ~(1 << id);
    set_ledr_all(ledr);
}
inline void set_ledr_all(uint32_t ledr)
{
    *p_LEDR = ledr&0x3ff;
}