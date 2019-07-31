#!/usr/bin/perl -w

use strict;
use Test::More tests => 26;

BEGIN { $XML::Structured::preferred_parser = $ENV{'PREFERRED_PARSER'} }
BEGIN { $XML::Structured::force_preferred_parser = 1 }
BEGIN { $XML::Structured::pureperl = $ENV{'PUREPERL'} }
use XML::Structured;

#######################

my $dtd1 = [
  'user' =>
    'login',
    'password',
];
my $xml1 = qq{<user login="foo" password="bar"/>
};
my $data1 = {
  'login' => 'foo',
  'password' => 'bar',
};

is_deeply(XMLin($dtd1, $xml1), $data1, 'xml->data 1');
is(XMLout($dtd1, $data1), $xml1, 'data->xml 1');

#######################

my $dtd2 = [
  'user' =>
    'login',
    [ 'favorite_fruits' ],
    'password',
];
my $xml2 = qq{<user login="foo">
  <favorite_fruits>apple</favorite_fruits>
  <favorite_fruits>peach</favorite_fruits>
  <password>bar</password>
</user>
};
my $data2 = {
  'login' => 'foo',
  'password' => 'bar',
  'favorite_fruits' => ['apple', 'peach'],
};

is_deeply(XMLin($dtd2, $xml2), $data2, 'xml->data 2');
is(XMLout($dtd2, $data2), $xml2, 'data->xml 2');

#######################

my $dtd3 = [
  'user' =>
    'login',
    [ 'address' =>
        'street',
        'city',
    ],
];

my $xml3 = qq{<user login="foo">
  <address street="broadway 7" city="new york"/>
</user>
};
my $data3 = {
  'login' => 'foo',
  'address' => { street => "broadway 7",  city => "new york" },
};

is_deeply(XMLin($dtd3, $xml3), $data3, 'xml->data 3');
is(XMLout($dtd3, $data3), $xml3, 'data->xml 3');

#######################

my $dtd4 = [
  'user' =>
    'login',
    [[ 'address' =>
        'street',
        'city',
    ]],
];

my $xml4 = qq{<user login="foo">
  <address street="broadway 7" city="new york"/>
  <address street="rural road 12" city="tempe"/>
</user>
};
my $data4 = {
  'login' => 'foo',
  'address' => [ { street => "broadway 7",  city => "new york" },
                 { street => "rural road 12",  city => "tempe" }, ],
};

is_deeply(XMLin($dtd4, $xml4), $data4, 'xml->data 4');
is(XMLout($dtd4, $data4), $xml4, 'data->xml 4');

#######################

my $dtd5 = [
  'user' =>
    'login',
    [[ 'address' =>
        'street',
        'city',
    ]],
    '_content',
];

my $xml5 = qq{<user login="foo">
  <address street="broadway 7" city="new york"/>hello
  <address street="rural road 12" city="tempe"/>world
</user>
};
my $xml5_2 = qq{<user login="foo">
  <address street="broadway 7" city="new york"/>
  <address street="rural road 12" city="tempe"/>
hello world
</user>
};
my $data5 = {
  'login' => 'foo',
  'address' => [ { street => "broadway 7",  city => "new york" },
                 { street => "rural road 12",  city => "tempe" }, ],
  '_content' => 'hello world
',
};

is_deeply(XMLin($dtd5, $xml5), $data5, 'xml->data 5');
is(XMLout($dtd5, $data5), $xml5_2, 'data->xml 5');

#######################

my $dtd6 = [
  '' => 
    [ 'apple' =>
        'color',
    ],
    [ 'peach' =>
        'color',
    ],
];
my $xml6_1 = qq{<apple color="red"/>
};
my $data6_1 = {
  'apple' => {'color' => 'red'},
};
my $xml6_2 = qq{<peach color="yellow"/>
};

my $data6_2 = {
  'peach' => {'color' => 'yellow'},
};
is_deeply(XMLin($dtd6, $xml6_1), $data6_1, 'xml->data 6_1');
is(XMLout($dtd6, $data6_1), $xml6_1, 'data->xml 6_1');
is_deeply(XMLin($dtd6, $xml6_2), $data6_2, 'xml->data 6_2');
is(XMLout($dtd6, $data6_2), $xml6_2, 'data->xml 6_2');

#######################

my $dtd7 = [
  'tree' =>
     [[ '' => 
      [ 'apple' =>
          'color',
      ],
      [ 'peach' =>
          'color',
      ],
    ]]
];
my $xml7_1 = qq{<tree>
  <apple color="red"/>
</tree>
};
my $data7_1 = {
  '' => [ { 'apple' => {'color' => 'red'} } ],
};
my $xml7_2 = qq{<tree>
  <peach color="yellow"/>
  <peach color="green"/>
</tree>
};

my $data7_2 = {
  '' => [ { 'peach' => {'color' => 'yellow'} }, { 'peach' => {'color' => 'green'} } ],
};
is_deeply(XMLin($dtd7, $xml7_1), $data7_1, 'xml->data 7_1');
is(XMLout($dtd7, $data7_1), $xml7_1, 'data->xml 7_1');
is_deeply(XMLin($dtd7, $xml7_2), $data7_2, 'xml->data 7_2');
is(XMLout($dtd7, $data7_2), $xml7_2, 'data->xml 7_2');

#######################

my $dtd8 = [
  'tree' =>
     [[ '' => 
      [ 'apple' =>
          'color',
	  '_alternative',
      ],
      [ 'peach' =>
          'color',
	  '_alternative',
      ],
    ]]
];

my $xml8_1 = qq{<tree>
  <apple color="red"/>
</tree>
};
my $data8_1 = {
  '' => [ { 'color' => 'red', '_alternative' => 'apple' } ],
};
my $xml8_2 = qq{<tree>
  <peach color="yellow"/>
  <peach color="green"/>
</tree>
};
my $data8_2 = {
  '' => [ { 'color' => 'yellow', '_alternative' => 'peach' }, { 'color' => 'green', '_alternative' => 'peach' } ],
};
is_deeply(XMLin($dtd8, $xml8_1), $data8_1, 'xml->data 8_1');
is(XMLout($dtd8, $data8_1), $xml8_1, 'data->xml 8_1');
is_deeply(XMLin($dtd8, $xml8_2), $data8_2, 'xml->data 8_2');
is(XMLout($dtd8, $data8_2), $xml8_2, 'data->xml 8_2');

#######################

my $dtd9 = [
  '' => 
    [ 'apple' =>
        'color',
	'_alternative',
    ],
    [ 'peach' =>
        'color',
	'_alternative',
    ],
];
my $xml9_1 = qq{<apple color="red"/>
};
my $data9_1 = {
  'color' => 'red', '_alternative' => 'apple',
};
my $xml9_2 = qq{<peach color="yellow"/>
};

my $data9_2 = {
  'color' => 'yellow', '_alternative' => 'peach',
};
is_deeply(XMLin($dtd9, $xml9_1), $data9_1, 'xml->data 9_1');
is(XMLout($dtd9, $data9_1), $xml9_1, 'data->xml 9_1');
is_deeply(XMLin($dtd9, $xml9_2), $data9_2, 'xml->data 9_2');
is(XMLout($dtd9, $data9_2), $xml9_2, 'data->xml 9_2');
