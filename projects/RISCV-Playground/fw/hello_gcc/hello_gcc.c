
// -----------------------------------------------------------------------------
//   Now go on with C
// -----------------------------------------------------------------------------

#include <stdint.h>
#include <stdarg.h>

// -----------------------------------------------------------------------------
//   Timing
// -----------------------------------------------------------------------------

#define CYCLES_US    12
#define CYCLES_MS 12000

uint32_t cycles(void)
{
  uint32_t ticks;
  asm volatile ("rdcycle %0" : "=r"(ticks));
  return ticks;
}

void delay_cycles(uint32_t time)
{
  uint32_t now = cycles();
  while ( (cycles() - now) < time ) {};
}

void us(uint32_t time)
{
  delay_cycles(time * CYCLES_US); // For 48 MHz clock frequency
}

void ms(uint32_t time)
{
  delay_cycles(time * CYCLES_MS); // For 48 MHz clock frequency
}

// -----------------------------------------------------------------------------
//   Terminal IO
// -----------------------------------------------------------------------------

#define UART_DATA  *(volatile uint8_t  *) 0x40010000
#define UART_FLAGS *(volatile uint32_t *) 0x40020000

uint32_t keypressed(void)
{
  return 0x100 & UART_FLAGS ? -1 : 0;
}

uint8_t getchar(void)
{
  while ( 0x100 & ~UART_FLAGS) {};
  return UART_DATA;
}

void serial_putchar(uint8_t character)
{
  while ( 0x200 & UART_FLAGS) {};
  UART_DATA = character;
}

// -----------------------------------------------------------------------------
//   Random numbers
// -----------------------------------------------------------------------------

uint32_t randombit(void)
{
  delay_cycles(100);
  return 0x400 & UART_FLAGS ? 1 : 0;
}

uint32_t random(void)
{
  uint32_t randombits = 0;
  for (uint32_t i = 0; i < 32; i++)
  {
    randombits = randombits << 1 | randombit();
  }
  return randombits;
}

// -----------------------------------------------------------------------------
//   LEDs & Buttons
// -----------------------------------------------------------------------------

#define BUTTONS   *(volatile uint32_t  *) 0x40000080
#define LEDS      *(volatile uint32_t  *) 0x40000100

#define LED_RED   *(volatile uint16_t  *) 0x40000200
#define LED_GREEN *(volatile uint16_t  *) 0x40000400
#define LED_BLUE  *(volatile uint16_t  *) 0x40000800

// -----------------------------------------------------------------------------
//   Textmode handling
// -----------------------------------------------------------------------------

// Arrays for font data and characters

volatile uint8_t *characters = (volatile uint8_t*) 0x10000000;
volatile uint8_t *font       = (volatile uint8_t*) 0x20000000;

static uint32_t xpos = 0;
static uint32_t ypos = 0;
static uint32_t textmarker = 0;

void normal(void) // Default color
{
  textmarker = 0;
}

void highlight(void) // Highlight color
{
  textmarker = 0x80;
}

void clear(void) // Fills the complete screen buffer with spaces
{
  for (uint32_t pos = 0; pos < 1200; pos++) characters[pos] = 32;
  xpos = 0;
  ypos = 0;
  normal();
}

void addline(void)
{

  if (ypos < 29)
  {
    ypos++;
  }
  else
  {
    uint32_t pos;
    for (pos=40;   pos < 1200; pos++) characters[pos-40] = characters[pos];
    for (pos=1160; pos < 1200; pos++) characters[pos] = 32;
  }

  xpos = 0;
}

void addchar(uint8_t character)
{
  if (xpos > 39) { addline(); xpos = 0; }
  characters[xpos + ypos*40] = character | textmarker;
  xpos++;
}

void stepback(void)
{
  if (xpos) { xpos--; }
  else
  {
    if (ypos)
    {
      ypos--;
      xpos = 39;
    }
  }
}

#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))
#define MAX(X, Y) (((X) > (Y)) ? (X) : (Y))

void lcd_putchar(uint8_t character)
{
  switch (character) {
    case 10: addline();  break;
    case  8: stepback(); break;
    default: if ((character & 0xC0) != 0x80) { addchar(MIN(character, 127)); }

  }
}

// -----------------------------------------------------------------------------
//   Output characters both to LCD and serial terminal
// -----------------------------------------------------------------------------

void putchar(uint8_t character)
{
  serial_putchar(character);
  lcd_putchar(character);
}

// -----------------------------------------------------------------------------
//   LCD hardcopy for debug
// -----------------------------------------------------------------------------

void hardcopy(void) // Prints the contents of the LCD to the terminal for testing.
{
  for (uint32_t i = 0; i < 40; i++) serial_putchar(61); serial_putchar(10);
  for (uint32_t pos = 0; pos < 1200; pos++)
  {
    serial_putchar(MAX(characters[pos] & 0x7F, 32)); // Clip to printable characters
    if ((pos % 40) == 39) putchar(10);
  }
  for (uint32_t i = 0; i < 40; i++) serial_putchar(61); serial_putchar(10);
}

// -----------------------------------------------------------------------------
//   Pretty printing
// -----------------------------------------------------------------------------

void print_string(const char* s) {
   for(const char* p = s; *p; ++p) {
      putchar(*p);
   }
}

int puts(const char* s) {
   print_string(s);
   putchar('\n');
   return 1;
}

void print_dec(int val) {
   char buffer[255];
   char *p = buffer;
   if(val < 0) {
      putchar('-');
      print_dec(-val);
      return;
   }
   while (val || p == buffer) {
      *(p++) = val % 10;
      val = val / 10;
   }
   while (p != buffer) {
      putchar('0' + *(--p));
   }
}

void print_hex_digits(unsigned int val, int nbdigits) {
   for (int i = (4*nbdigits)-4; i >= 0; i -= 4) {
      putchar("0123456789ABCDEF"[(val >> i) % 16]);
   }
}

void print_hex(unsigned int val) {
   print_hex_digits(val, 8);
}

// -----------------------------------------------------------------------------
//   Formated printing
// -----------------------------------------------------------------------------

int printf(const char *fmt,...)
{
    va_list ap;

    for(va_start(ap, fmt);*fmt;fmt++)
    {
        if(*fmt=='%')
        {
            fmt++;
                 if(*fmt=='s') print_string(va_arg(ap,char *));
            else if(*fmt=='x') print_hex(va_arg(ap,int));
            else if(*fmt=='d') print_dec(va_arg(ap,int));
            else if(*fmt=='c') putchar(va_arg(ap,int));
            else putchar(*fmt);
        }
        else putchar(*fmt);
    }

    va_end(ap);

    return 0;
}

// -----------------------------------------------------------------------------
//   Main
// -----------------------------------------------------------------------------

void main(void)
{
  clear();

  putchar(10);
  highlight();
  puts("RISC-V Playground");
  printf("Most recent random number: 0x%x.\n", random());
  normal();
  putchar(10);

  while (1)
  {
    if (keypressed())
    {
      uint32_t character = getchar();
      putchar(character);

      printf(" Character %d received.\n", character);
    }

    uint32_t buttons = BUTTONS;

    LED_RED   = ( buttons       & 0x1f) << 11;  // Joystick
    LED_GREEN = ((buttons >> 5) & 0x0f) << 12;  // Home, Menu, Select, Start
    LED_BLUE  = ((buttons >> 9) & 0x03) << 14;  // A, B
  }
}
