#!/opt/local/bin/perl
use strict;

# perl -ne 'if($_ !~ /\s*\*/){print;}'|perl -ne 'if(/([a-zA-Z0-9]+)\s*[=;]/){print "$1\n";}'|perl -ne 'if($_ !~ /[0-9]+/){print;}' > variables.txt
my %var_dict = ();
if($#ARGV + 1 != 1){
    print STDERR "Usage: ./produce_graph.pl source_file\n";
    exit(1);
}


my @lines = ();

open(INPUT, $ARGV[0]) or die "Cannot open file $ARGV[0].\n";
my $symbol = "[a-zA-Z0-9_]+";
while(<INPUT>){
    if($_ =~ /^\s*\*/){
	next;
    }
    # add the current line to the array @lines
    push(@lines, $_);

    # remove constructor funcitions
    $_ =~ s/\([^\)]\)//g;

    # parse variables from the current line
    if($_ =~ /($symbol)\s*[=;]/){
	if($1 !~ /^[0-9]+$/){
	    #print "vars:$1\n";
	    $var_dict{$1} = 1;	    
	}
    }
    
    # parse C++ function parameters
    if($_ =~ /::/){
	if($_ =~ /($symbol)\s*[\),]/){
	    $var_dict{$1} = 1;
	}
    }
    
    # parse pointers
    if($_ =~ /($symbol)\s*->/){
	$var_dict{$1} = 1;
    }
}
close(INPUT);

sub search_for_var{
    my $expression = shift;
    use vars qw(%var_dict);

    #my $matched_variable_length = -1;
    #my $matched_variable;
    foreach my $variable (keys %var_dict){
	if($expression =~ /\b$variable\b/){ # do a word search of teh variable
	    #if(length($variable) > $matched_variable_length){
	    #$matched_variable_length = length($variable);
	    #$matched_variable = $variable;
	    #}
	    return $variable;
	}
    }
    
    return "";
    #return $matched_variable;
}

sub search_for_vars{
    my $expression = shift;
    use vars qw(%var_dict);

    my @var_list = ();
    foreach my $variable (keys %var_dict){
	if($expression =~ /\b$variable\b/){ # do a word search of the variable
	    push(@var_list, $variable);
	}
    }

    return @var_list;
}

my @remaining_line = ();

my %result_hash = ();
# parse function calls first
foreach (@lines){
    if($_ =~ /([a-zA-Z0-9]+)(?:\.|->)([a-zA-Z0-9]+)\s*\((.*)$/){
       #print "Function call:$_";
	my $left_var = "$1";
	my $right_expression = $3;
	my @right_vars = search_for_vars($right_expression);
	foreach my $right_var (@right_vars){
	    $result_hash{"\t$right_var -> $left_var;\n"} = 1;
	}

	# this line is also an assignment line
	if($_ =~ /([^=]*)=/){
	    push(@remaining_line, "$1 = $left_var;");
	    #print "Complex statement $_ -------> $1 = $left_var;\n";
	}
	#push(@remaining_line, )
    }else{
	push(@remaining_line, $_);
    }

}


# then parse assignments
foreach(@remaining_line){

    if($_ =~ /=/){
	# assignment operation
	#print "Remaining line:$_\n";
	my ($left_expression, $right_expression) = split(/=/, $_);
	#print "left_expression:$left_expression right_expression:$right_expression\n";
	my $left_var = search_for_var($left_expression);
	#print "left_var:$left_var\n";
	if($left_var ne ""){
	    my @right_vars = search_for_vars($right_expression);
	    #print "right_vars: @right_vars $#right_vars\n";
	    if($#right_vars + 1 > 0){
		foreach my $right_var (@right_vars){
		    $result_hash{"\t$right_var -> $left_var;\n"} = 1;
		}
	    }
	}
    }
}


my $output_dot = "";
my $output_pdf = "";
if($ARGV[0] =~ /([^\.]+)\./){
    $output_dot = "$1.dot";
    $output_pdf = "$1.pdf";
}else{
    $output_dot = $ARGV[0].".dot";
    $output_pdf = $ARGV[0].".pdf";
}

open(DOT_OUTPUT, ">$output_dot") or die "Cannot open $output_dot for output";
print DOT_OUTPUT  "digraph G{\n";
foreach my $line (keys %result_hash){
    print DOT_OUTPUT $line;
}
print DOT_OUTPUT "}\n";
close(DOT_OUTPUT);


system("dot -Tpdf -o $output_pdf $output_dot");
