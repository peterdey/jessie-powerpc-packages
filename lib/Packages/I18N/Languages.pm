# Taken from the webwml CVS tree (english/templates/languages.wml)

package Packages::I18N::Languages;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( langcmp get_transliteration get_selfname );

# language directory name => ISO 639 two-letter code for the language name
my %langs = (
	     english    => "en",
	     arabic     => "ar",
	     armenian   => "hy",
	     bulgarian  => "bg",
	     catalan    => "ca",
	     chinese    => "zh",
	     croatian   => "hr",
	     czech	=> "cs",
	     danish     => "da",
	     dutch      => "nl",
	     german     => "de",
	     greek      => "el",
	     esperanto  => "eo",
	     spanish    => "es",
	     finnish    => "fi",
	     french     => "fr",
	     hungarian  => "hu",
	     indonesian => "id",
	     italian    => "it",
	     japanese   => "ja",
	     korean     => "ko",
	     lithuanian => "lt",
	     norwegian  => "no",
	     persian    => "fa",
	     polish     => "pl",
	     portuguese => "pt",
	     romanian   => "ro",
	     russian    => "ru",
	     swedish    => "sv",
	     slovene    => "sl",
	     slovak     => "sk",
	     turkish    => "tr",
	     );

# language directory name => native name of the language
# non-ASCII letters must be escaped (using entities)!
my %selflang = (
		ar     => '&#1593;&#1585;&#1576;&#1610;&#1577;',
		bg     => '&#1041;&#1098;&#1083;&#1075;&#1072;&#1088;&#1089;&#1082;&#1080;',
		ca     => 'catal&agrave;',
		cs     => '&#269;esky',
		da     => 'dansk',
		de     => 'Deutsch',
		el     => '&#917;&#955;&#955;&#951;&#957;&#953;&#954;&#940;',
		en     => 'English',
		eo     => 'Esperanto',
		es     => 'espa&ntilde;ol',
		fa     => '&#x0641;&#x0627;&#x0631;&#x0633;&#x06cc;',
		fi     => 'suomi',
		fr     => 'fran&ccedil;ais',
		hu     => 'magyar',
		hr     => 'hrvatski',
		hy     => '&#1344;&#1377;&#1397;&#1381;&#1408;&#1381;&#1398;',
		id     => 'Indonesia',
		it     => 'Italiano',
		ja     => '&#26085;&#26412;&#35486;',
		km     => 'Khmer',
		ko     => '&#54620;&#44397;&#50612;',
		lt     => 'Lietuvi&#371;',
		nl     => 'Nederlands',
		"no"   => 'norsk&nbsp;(bokm&aring;l)',
		pl     => 'polski',
		pt     => 'Portugu&ecirc;s (pt)',
		'pt-pt'=> 'Portugu&ecirc;s (pt)',
		'pt-br'=> 'Portugu&ecirc;s (br)',
		ro     => 'rom&acirc;n&#259;',
		ru     => '&#1056;&#1091;&#1089;&#1089;&#1082;&#1080;&#1081;',
		sk     => 'slovensky',
		sv     => 'svenska',
		'sv-se'=> 'svenska',
		sl     => 'sloven&#353;&#269;ina',
		tr     => 'T&uuml;rk&ccedil;e',
		uk     => '&#1091;&#1082;&#1088;&#1072;&#1111;&#1085;&#1089;&#1100;&#1082;&#1072;',
		zh     => '&#20013;&#25991;',
		'zh-cn'=> '&#20013;&#25991;',
		'zh-hk'=> '&#27491;&#39636;&#20013;&#25991;',
		'zh-tw'=> '&#20013;&#25991;',
		);

# language directory name => Latin transliteration of the language name
# This is used for language names which consist entirely of non-Latin
# characters, to aid those that have browsers which cannot show different
# character sets at once.
my %translit = (
		ar => "Arabiya",
		bg => "B&#601;lgarski",
		el => "Ellinika",
		fa => "Farsi",
		hy => "hayeren",
		ja => "Nihongo",
		ko => "Hangul", # Not sure. "Hanguk-Mal" (=Spoken Korean)?
		ru => "Russkij",
		uk => "ukrajins'ka",
		zh => "Zhongwen",
		'zh-cn'=> "Zhongwen,&#31616;",
		'zh-hk'=> "Zhongwen,HK",
		'zh-tw'=> "Zhongwen,&#32321;",
		);

# second transliteration table, used for languages starting with a latin
# diacritic letter
my %translit2 = (
		 cs    => "cesky",
);

sub langcmp ($$) {
  my ($first, $second) = @_;

  # Handle sorting of non-latin characters
  # If there is a transliteration for this language available, use it
  $first = $translit{$first} if defined $translit{$first};
  $second = $translit{$second} if defined $translit{$second};

  # Then handle special cases (initial latin letters with diacritics)
  $first = $translit2{$first} if defined $translit2{$first};
  $second = $translit2{$second} if defined $translit2{$second};

  # Put remaining entity-only names last in the list
  if (substr($first,0,1) eq '&')
  {
    $first =~ s/^&/ZZZ&/;
  }
  if (substr($second,0,1) eq '&')
  {
    $second =~ s/^&/ZZZ&/;
  }
  #    There seems to be a bug with localization in
  #    Perl 5.005 so we need those extra variables.
  my ($ufirst, $usecond) = (uc($first), uc($second));
  return $ufirst cmp $usecond;
}

sub get_selfname {
    return $selflang{$_[0]} if exists $selflang{$_[0]};
    return undef;
}

sub get_transliteration {
    return $translit{$_[0]} if exists $translit{$_[0]};
    return undef;
}

1;
