staload "SATS/io.sats"

implement main () = {
  val () = setbits(DDRB,DDB3)
  val () = setbits(PORTB, PORTB3)
}