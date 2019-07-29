#!/usr/bin/perl -w

use strict;
use Test::More tests => 4;

BEGIN { $XML::Structured::preferred_parser = $ENV{'PREFERRED_PARSER'} }
BEGIN { $XML::Structured::force_preferred_parser = 1 }
BEGIN { $XML::Structured::pureperl = 1 }
use XML::Structured;
use Data::Dumper;

#######################

my $dtd = [
  'bar' => [
  'user' =>
    [],
    'login',
    '_content',
    'password',
  ]
];

my $data1 = {
  'user' => {
  '_content' => "  hello world  ",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data1)), $data1, 'data 1');

#######################

my $data2 = {
  'user' => {
  'login' => 'foo',
  '_content' => "  hello world  ",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data2)), $data2, 'data 2');

#######################

my $data3 = {
  'user' => {
  'password' => 'foo',
  '_content' => "  hello world  ",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data3)), $data3, 'data 3');

#######################

my $data4 = {
  'user' => {
  'login' => 'foo',
  'password' => 'foo',
  '_content' => "  hello world  ",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data4)), $data4, 'data 4');

