This is an simple asm interpreter
It has:
  - Anything is 8-bit(RAM, Register, address,...)
  - 6 Register:
     + A(Accumulator)
     + B
     + C
     + D
     + S(Stack Pointer)
     + PC
  - 256 ram cells
  - Simple interrupt:
     + `int 0h`: Stop Program
     + `int 1h`: Output
        - `A = 0`: Output 1 char at register B
     + `int 2h`: input
