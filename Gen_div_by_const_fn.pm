package Gen_div_by_const_fn;
require Exporter;

# This module provides a perl function 'gen_div_by_const_fn'
# that generates a verilog function (e.g. 'div_by_3_fn')
# that implements division by a constant.
#
# The code generated by this module synthesizes better than 
# raw verilog code like :
# ' assign q = x/3; '
#

our @ISA = qw(Exporter);
our @EXPORT = qw(gen_div_by_const_fn);
our $VERSION = 1.00;

sub clog2 {
  my ($n) = @_;
  my $l = int( (log($n)/log(2)) + 0.99999 );
  return $l;
}

sub gen_div_by_const_fn{
  my ($N, $ibits, $obits, $fname) = @_;
  # N = constant to divide by.
  # ibits = input bits (default = 32)
  # obits = output quotient bits (optional)
  # fname = function name (optional).

  die "N must be defined. N=$N." unless (defined $N);
  $ibits //= 32;
  $obits //= &clog2( 1.0*(2**$ibits)/$N );
  $fname //= "div_by_${N}_fn";

  my $cN = clog2($N);

  # Header
  my $return_type = "div_result_${ibits}_${N}_t";
  my $output = "";
  $output .= <<DONE;
  typedef struct packed {
    u${obits}_t \tq; // quotient
    u${cN}_t \tr; // remainder
  } $return_type;
  function $return_type $fname ( u${ibits}_t x );
   $return_type result;
DONE

  if ($N & ($N - 1) == 0) { # $N is a power of 2
    $output .= <<DONE;
  begin
    result.q = x[$ibits-1:$cN];
    result.r = x[$cN-1:0];
DONE

  } else { # $N is not a power of 2.

    # Declarations
    my ($piece_sz, $num_pieces);
    $piece_sz = $cN + 2;
    $num_pieces = 1;
    $num_pieces *= 2 while ($num_pieces * $piece_sz < $ibits);

    my ($np, $ps, $i) = ($num_pieces, $piece_sz, 0);
    while ($np >= 1) {
      my $npm1 = $np - 1;
      $output .= <<DONE;
   u${ps}_t \t[$npm1:0] q_${i};
DONE
      if ($i > 0) {
        $output .= <<DONE;
   u${cN}_t \t[$npm1:0] r_${i};
DONE
        $np /= 2; $ps *= 2; 
      }
      $i++;
    }

    # End header
    $output .= <<DONE;
  begin

DONE

    # Calculate first layer : divide each piece by $N.
    $output .= <<DONE;
    // Separate input into $num_pieces pieces of size $piece_sz bits each.
    q_0 = x;

    // Divide each piece by $N 
    q_1 = 0; r_1 = 0;
    for (int i = 0; i < $num_pieces; i++) begin
      case(q_0[i])
DONE
    foreach $i (1 .. (2**$piece_sz - 1)) {
      my $i_div_N = int ($i / $N);
      my $i_mod_N = $i % $N;
      $output .= <<DONE;
        $i : begin q_1[i] = $i_div_N; r_1[i] = $i_mod_N; end
DONE
    }
    $output .= <<DONE;
      endcase
    end

DONE

    # Refine result as many times as needed.
    my ($np, $ps, $j) = ($num_pieces, $piece_sz, 1);
    while ($np > 1) {
      $np /= 2; $ps *= 2; $j++;
      my $k = $j - 1;
      $output .= <<DONE;
    // Refine result for each pair of pieces
    q_${j} = 0; r_${j} = 0;
    for (int i = 0; i < $np; i++) begin
      case({r_${k}[2*i+:2]})
DONE
      foreach my $rem1 (1 .. ($N-1)) {
        foreach my $rem2 (0 .. ($N-1)) {
          my $total_rem = ($rem1 << ($ps/2)) + $rem2;
          my $total_rem_div_N = int($total_rem / $N);
          my $total_rem_mod_N = $total_rem % $N;
          $output .= <<DONE;
        {${cN}'d${rem1}, ${cN}'d${rem2}} : begin q_${j}[i] = q_${k}[2*i+:2] + $total_rem_div_N; r_${j}[i] = $total_rem_mod_N; end // rem = $total_rem = $total_rem_div_N * $N + $total_rem_mod_N
DONE
        }
      }
    $output .= <<DONE;
        default      : begin q_${j}[i] = q_${k}[2*i+:2] ; r_${j}[i] = r_${k}[2*i]; end
      endcase
    end

DONE
    }

    # Final hookup.
    $output .= <<DONE;
    result.q = q_${j}[0];
    result.r = r_${j}[0];
DONE
  }

  # Footer
  $output .= <<DONE;
    return result;
  end
  endfunction
DONE

  return $output;
}

1;
