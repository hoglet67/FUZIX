#!/usr/bin/perl

use strict;

use List::Util qw/sum/;

# unpack a DECB binary as a flat binary file

my $HELP = <<ENDHELP;
decb2bin.pl [--base=<hex addr>] [-v] <in file> <out file>

Will unpack the decb file to a flat binary file. 

If no base address is specified then the output file will with the first
byte found in the decb file.

-v is verbose

ENDHELP


sub usage($) {
	my ($msg) = @_;
	if ($msg) {
		print STDERR "$msg\n"
	}
	die $HELP;
}

my $base_addr_out = -1;
my $base_addr = -1;
my $end_addr = -1;
my $verbose = 0;
my @used = (0) x 0x10000;
my @mem = (chr(0xFF)) x 0x10000;
my $chunk_count = 0;

while (scalar @ARGV && @ARGV[0] =~ /^-/) {
	my $sw = shift;
	if ($sw =~ /^--base=(0x)?([0-9a-f]+)\s*$/i) {
		$base_addr_out = hex($2);
	} elsif ($sw eq '-v') {
		$verbose=1;
	} else {
		usage "unknown switch $sw"
	}
}

my $fn_in = shift or die "Missing input file name";
my $fn_out = shift or die "Missing output file name";

open (my $fh_in, "<:raw", "$fn_in") or die "Cannot open \"$fn_in\" for input : $!";
open (my $fh_out, ">:raw", "$fn_out") or die "Cannot open \"$fn_out\" for output : $!";

while (process_chunk()) {
	$chunk_count++;	
}

if ($verbose) {
	if ($end_addr == -1) {
		print "No data chunks found\n";
		exit 1;
	} else {
		printf "%d bytes found in %d data chunks in range 0x%04x-0x%04x\n", sum(@used), $chunk_count, $base_addr, $end_addr;
	}
}

if ($base_addr_out == -1) {
	$base_addr_out = $base_addr;
}

if ($base_addr_out > $end_addr) {
	print STDERR "WARNING: base address after end of data - nothing written\n";
} else {
	print $fh_out pack("C*", @mem[$base_addr_out..$end_addr]);
}


sub process_chunk() {

	read($fh_in, my $hdr, 5) or die "Unexpected EOF in chunk header";

	my ($hdr_type, $hdr_len, $hdr_base) = unpack("C n n", $hdr);

	if ($verbose) {
		printf "CHUNK %d : %02x %04x, len=%x\n", $chunk_count, $hdr_type, $hdr_base, $hdr_len;
	}

	if ($hdr_type == 0) {
		# data chunk

		read($fh_in, my $b_data, $hdr_len) == $hdr_len or die "Unexpected EOF reading data";

		splice(@used, $hdr_base, $hdr_len, (1) x $hdr_len);
		splice(@mem, $hdr_base, $hdr_len, unpack("C*", $b_data));

		if ($base_addr == -1 || $hdr_base < $base_addr) {
			$base_addr = $hdr_base;
		}

		if ($end_addr == -1 || $hdr_base + $hdr_len - 1 > $end_addr) {
			$end_addr = $hdr_base + $hdr_len - 1;
		}


		return 1;
	} elsif ($hdr_type == 0xFF) {
		# eof chunk
		return 0;
	} else {
		die sprintf "Unexpected chunk type %x", $hdr_type;
	}

}
