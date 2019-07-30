#!/usr/bin/perl -w

use strict;
use Test::More tests => 6;

BEGIN { $XML::Structured::preferred_parser = $ENV{'PREFERRED_PARSER'} }
BEGIN { $XML::Structured::force_preferred_parser = 1 }
BEGIN { $XML::Structured::pureperl = 1 }
use XML::Structured;

#######################

my $dtd = [
  'bar' => [
  'user' =>
    [],
    'login',
    '_content',
    'password',
    'password2',
  ]
];

my $data1 = {
  'user' => {
  '_content' => "\n  hello world  \n",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data1)), $data1, 'data 1');

#######################

my $data2 = {
  'user' => {
  'login' => 'foo',
  '_content' => "\n  hello world  \n",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data2)), $data2, 'data 2');

#######################

my $data3 = {
  'user' => {
  'password' => 'foo',
  '_content' => "\n  hello world  \n",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data3)), $data3, 'data 3');

#######################

my $data4 = {
  'user' => {
  'login' => 'foo',
  'password' => 'foo',
  '_content' => "\n  hello world  \n",
  }
};

is_deeply(XMLin($dtd, XMLout($dtd, $data4)), $data4, 'data 4');

#######################

my $xml5 = qq{
<bar>
  <user>
hello
    <login>foo</login>
world
    <password>foo</password>
hi<password2>xxx</password2>ho
  </user>
</bar>
};
my $data5 = {
  'user' => {
  'login' => 'foo',
  'password' => 'foo',
  'password2' => 'xxx',
  '_content' => "\nhello world hiho\n  ",
  }
};

is_deeply(XMLin($dtd, $xml5), $data5, 'data 5');

#######################

my $xml6 = qq{
<bar>
  <user> 
    <login>foo</login>
    <password>foo</password>
  </user>
</bar>
};
my $data6 = {
  'user' => {
  'login' => 'foo',
  'password' => 'foo',
  }
};
is_deeply(XMLin($dtd, $xml6), $data6, 'data 6');

