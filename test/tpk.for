C     THE TPK ALGORITHM
C     FORTRAN IV STYLE
      DIMENSION A(11)
      FUN(T) = SQRT(ABS(T)) + 5.0*T**3
      READ (5, 1) A
  1   FORMAT(5F10.2)
      DO 10 J = 1, 11
         I = 11 - J
         Y = FUN(A(I+1))
         IF (400.0-Y) 4, 8, 8
  4         WRITE (6,5) I
  5         FORMAT(I10, 10H TOO LARGE)
         GO TO 10
  8         WRITE (6,9) I, Y
  9         FORMAT(I10, F12.6)
 10   CONTINUE
      STOP
      END
