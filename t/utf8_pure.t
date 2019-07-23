#!/usr/bin/perl -w

use strict;
use Test::More tests => 5;

BEGIN { $XML::Structured::pureperl = 1 }
use XML::Structured;

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
  'login' => "fo\N{U+00f6}o",
  'password' => 'bar',
};
my $data1_2 = {
  'login' => $b1,
  'password' => 'bar',
};

is_deeply(XMLin($dtd1, $xml1), $data1, 'xml->data 1');
is(XMLout($dtd1, $data1), $xml1, 'data->xml 1');
is(XMLout($dtd1, $data1_2), $xml1, 'data->xml 1_2');

#######################

my $b2 = pack('C*', 102, 111, 246, 111);		# iso8859-1
my $b2_2 = pack('C*', 102, 111, 195, 182, 111);		# utf8
my $dtd2 = [
  'user' =>
    'login',
    'password',
];
my $xml2 = qq{<user login="$b2_2" password="bar"/>
};
my $data2 = {
  'login' => $b2,
  'password' => 'bar',
};

is(XMLout($dtd2, $data2), $xml2, 'data->xml 2');

#######################

my $b3 = pack('C*', 102, 111, 195, 182, 111);
my $dtd3 = [
  'user' =>
    'login',
    'password',
];
my $xml3 = qq{<user login="$b3" password="bar"/>
};
my $data3 = {
  'login' => "fo\N{U+00f6}\N{U+0006}o",
  'password' => 'bar',
};


is(XMLout($dtd3, $data3), $xml3, 'data->xml 3');

#######################
