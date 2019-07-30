#!/usr/bin/perl -w

use strict;
use Test::More tests => 3;

BEGIN { $XML::Structured::preferred_parser = $ENV{'PREFERRED_PARSER'} }
BEGIN { $XML::Structured::force_preferred_parser = 1 } 
BEGIN { $XML::Structured::pureperl = $ENV{'PUREPERL'} }
use XML::Structured ':bytes';

#######################

my $b1 = pack('C*', 102, 111, 195, 182, 111);
my $dtd1 = [
  'user' =>
    'login',
    'password',
];
my $xml1 = qq{<user login="$b1" password="bar"/>
};
my $data1 = {
  'login' => $b1,
  'password' => 'bar',
};
is_deeply(XMLin($dtd1, $xml1), $data1, 'xml->data 1');
is(XMLout($dtd1, $data1), $xml1, 'data->xml 1');

#######################

my $b2 = pack('C*', 102, 6, 111, 195, 182, 111);
my $b2_1 = pack('C*', 102, 111, 195, 182, 111);
my $dtd2 = [
  'user' =>
    'login',
    'password',
];
my $xml2 = qq{<user login="$b2_1" password="bar"/>
};
my $data2 = {
  'login' => $b2,
  'password' => 'bar',
};

is(XMLout($dtd2, $data2), $xml2, 'data->xml 2');

