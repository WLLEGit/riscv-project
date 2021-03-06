#include "irq.h"
#include "io_mm.h"

void int_handler_entrance();

void init_CSR()
{
    uint32_t addr = (uint32_t)(int_handler_entrance);
    uint32_t tmp;
    // set the address of the interrupt handler
    asm volatile("mv %[tmp], %[src];"
                "csrw mtvec, %[tmp];"
                    :
                    : [src]"r"(addr), [tmp]"r"(tmp));
    asm volatile("csrw mscratch, %[tmp];"
                    :
                    : [tmp]"r"(TMP_STACK_OFFSET));
    // enable global interrupt
    asm volatile("csrw mstatus, %[tmp];"
                    :
                    : [tmp]"r"(0x00000008));
}

void irq_handler(uint32_t mcause)
{
    if(mcause == CLOCK_INT_MCAUSE)
    {
        //clock interrupt
        sys_time++;
        KBInfo tmp_info = *p_kb_info;
        if(kb_info.c != tmp_info.c)
        {
            input_controller.pre_c = kb_info.c;
            input_controller.input_time = sys_time;
            kb_info = tmp_info;
        }
    }
    else if(mcause == ECALL_MCAUSE)
    {
        
    }
}