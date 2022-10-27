
// -----------------------------------------------------------------------------
//   How to use a C standard library: Picolibc
// -----------------------------------------------------------------------------

// apt-get install picolibc-riscv64-unknown-elf

// https://github.com/picolibc/picolibc/blob/main/doc/using.md
// https://github.com/picolibc/picolibc/blob/main/doc/linking.md

// -----------------------------------------------------------------------------
//   Now go on with C
// -----------------------------------------------------------------------------

#include <stdio.h>
#include <sys/cdefs.h>
#include <stdint.h>
#include <stdarg.h>
#include <math.h>

// -----------------------------------------------------------------------------
//   Timing
// -----------------------------------------------------------------------------

#define CYCLES_US    15
#define CYCLES_MS 15000

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

uint8_t serial_getchar(void)
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
//   Wire STDIO of the library into the UART terminal
// -----------------------------------------------------------------------------

static int sample_putc(char c, FILE *file)
{
  // (void) file;         /* Not used in this function */
  serial_putchar(c);     /* Defined by underlying system */
  lcd_putchar(c);
  return c;
}

static int sample_getc(FILE *file)
  {
  unsigned char c;
  // (void) file;         /* Not used in this function */
  c = serial_getchar();  /* Defined by underlying system */
  return c;
}

static int sample_flush(FILE *file)
        {
  /* This function doesn't need to do anything */
  // (void) file;         /* Not used in this function */
  return 0;
    }

static FILE __stdio = FDEV_SETUP_STREAM(sample_putc, sample_getc, sample_flush, _FDEV_SETUP_RW);

FILE *const __iob[3] = { &__stdio, &__stdio, &__stdio };

// -----------------------------------------------------------------------------
//   Main
// -----------------------------------------------------------------------------

void main(void)
{
  clear();

  putchar(10);
  highlight();
  puts("RISC-V Playground");
  printf("Most recent random number: 0x%X.\n", random());
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
