ENTRY(_start);
SECTIONS
{
    . = 0x00;
    .text : AT(0x00)
    {
        *(.text);
    }
}