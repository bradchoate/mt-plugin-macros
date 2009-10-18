# ---------------------------------------------------------------------------
# Macros
# A Plugin for Movable Type
#
# Release 1.53
# October 17, 2009
#
# From Brad Choate
# http://www.bradchoate.com/
# ---------------------------------------------------------------------------
# This software is provided as-is.
# You may use it for commercial or personal use.
# If you distribute it, please keep this notice intact.
#
# Copyright (c) 2002-2009 Brad Choate
# ---------------------------------------------------------------------------

package Macros;

use strict;
use MT::Util qw(decode_html);

sub apply_macros {
    my ($str, $param, $ctx, $cond, $recurse, $depth) = @_;
    my @m;
    my $macroHash = $ctx->stash('MacroMacroHash');
    my $macroArray = $ctx->stash('MacroMacroArray');
    return $str unless $macroHash && $macroArray;
    $depth = 0 unless defined $depth;

    if ($param eq '1') {
        @m = @{$macroArray};
    } elsif ($param =~ m|^m\W|) {
        my ($pattern,$options) = ($param =~ m|^m(.)(.*)\1(.*)$|)[1,3];
        my @m_idxs = map +($macroHash->{$_}), grep(/$pattern/, keys %$macroHash);
        if (@m_idxs) {
            @m = map +($macroArray->[$_]), sort @m_idxs;
        }
    } else {
        my @names = split /\b/, $param;
        foreach my $name (@names) {
            if (defined $macroHash->{$name}) {
                push @m, $macroArray->[$macroHash->{$name}];
            }
        }
    }
    $str = '' if !defined $str;
    my @processed;

    foreach my $macro (@m) {
        next unless $macro;  # skip any emptied (deleted) patterns
        $macro->{used} = 0 unless $depth;

        if ($macro->{no_html}) {
            my $tokens = _tokenize($str);
            my $out = '';
            foreach my $token (@$tokens) {
                if (($token->[0] eq 'text') &&
                    !($macro->{once} && $macro->{used})) {
                    $out .= _replace_portion($token->[1], $param, $ctx, $cond,
                                 $recurse, $depth, \@processed,
                                 $macro);
                } else {
                    $out .= $token->[1];
                }
            }
            $str = $out;
        } else {
            $str = _replace_portion($str, $param, $ctx, $cond,
                        $recurse, $depth, \@processed, $macro);
        }
    }
    $str;
}

sub _tokenize {
    my ($str) = @_;
    my $pos = 0;
    my $len = length $str;
    my @tokens;
    while ($str =~ m!(<([^>]+)>)!gs) {
        my ($whole_tag, $tag) = ($1, $2);
        my $sec_start = pos $str;
        my $tag_start = $sec_start - length $whole_tag;
        push @tokens, ['text', substr($str, $pos, $tag_start - $pos)] if $pos < $tag_start;
        push @tokens, ['tag', $whole_tag];
        $pos = pos $str;
    }
    push @tokens, ['text', substr($str, $pos, $len - $pos)] if $pos < $len;
    \@tokens;
}

sub _replace_portion {
    my ($str, $param, $ctx, $cond, $recurse, $depth, $processed, $macro) = @_;

    my $name = $macro->{name};
    my $tokens = $macro->{tokens};
    my $type = $macro->{type};

    if ($type eq 's') { #string
        my $string = $macro->{string};
        # now search and replace all occurrences of string with macro
        local $ctx->{__stash}{MacroContent} = '';
        my $builder = $ctx->stash('builder');
        defined(my $bout = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error("Error during macro expansion: ".$builder->errstr);
        $string =~ s/([^A-Za-z0-9_])/\\$1/g;
        if ($macro->{no_case}) {
            $string = '(?i)'.$string;
        }
        if ($macro->{once}) {
            if ($str =~ s/$string/$bout/x) {
                $macro->{used} = 1;
            }
        } else {
            $str =~ s/$string/$bout/gx;
        }
        $str = apply_macros($str, (join ' ', @$processed), $ctx, $cond, $recurse, $depth+1) if ($recurse || $macro->{recurse}) && @$processed;
        push @$processed, $name;
    } elsif ($type eq 'p') { #pattern
        my $cpatt = $macro->{compiled_pattern};
        if (!$cpatt) {
            my $pattern = $macro->{pattern};
            $cpatt = eval qq{sub {my \$s = shift;
                      my \@m = \$s =~ $pattern;
                      (\$`, \$&, \$', \@m)}}; # '`)}}
                return $ctx->error("Error in macro pattern: $@") if $@;
            $macro->{compiled_pattern} = $cpatt;
        }
        my $repl = $str;
        my $out = '';
        while (1) {
            my ($pre, $match, $post, @matches) = $cpatt->($repl);
            if (!@matches) {
                $out .= $repl;
                last;
            }

            local $ctx->{__stash}{MacroMatches} = \@matches;
            local $ctx->{__stash}{MacroContent} = $match;
            my $builder = $ctx->stash('builder');
            defined (my $bout = $builder->build($ctx, $tokens, $cond))
                or return $ctx->error("Error during macro expansion: ".$builder->errstr);
            $out .= $pre.$bout;
            $repl = $post;
            if ($macro->{once}) {
                $macro->{used} = 1;
                $out .= $repl;
                last;
            }
        }
        $str = $out;
        $str = apply_macros($str, (join ' ', @$processed), $ctx, $cond, $recurse, $depth+1) if ($recurse || $macro->{recurse}) && @$processed;
        push @$processed, $name;
    } elsif ($type eq 't') { #tag
        my $mtag = $macro->{tag};
        my $is_container = $macro->{tag_container};
        my $no_case = $macro->{no_case} || 0;
        my $out = '';
        my $pos = 0;
        my $len = length $str;
        my @matches;
        if ($no_case) {
            $mtag = '(?i)'.$mtag;
        }
        while ($str =~ m!(<($mtag(?=(\s|>))[^>]*?)>)!gx) {
            my($whole_tag, $tag, @matches) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
            ($tag, my($args)) = split /\s+/, $tag, 2;
            next if $tag !~ m/$mtag/x;

            my $sec_start = pos $str;
            my $tag_start = $sec_start - length $whole_tag;
            $out .= substr($str, $pos, $tag_start - $pos) if $pos < $tag_start;

            $args ||= '';
            my %args;
            while ($args =~ /(\w+)\s*=\s*(["'])(.*?)\2/g) { # '" ])) { # I HATE CPERL SOMETIMES
                $args{$1} = $3;
            }
            my $sec = '';
            if ($is_container) {
                    my ($sec_end, $tag_end) = _consume_up_to(\$str, $sec_start, $mtag);
                    if ($sec_end) {
                        $sec = substr $str, $sec_start, $sec_end - $sec_start;
                        $sec =~ s!^\n!!;
                    } else {
                        return $ctx->error("<$tag> with no </$tag>");
                    }
                    $pos = $tag_end + 1;
                    (pos $str) = $tag_end;
            }
            local $ctx->{__stash}{MacroTag} = $tag;
            local $ctx->{__stash}{MacroTagArgs} = \%args;
            local $ctx->{__stash}{MacroContent} = $sec;
            local $ctx->{__stash}{MacroMatches} = \@matches;
            my $builder = $ctx->stash('builder');
            my $bout = $builder->build($ctx, $tokens, $cond);
            return $ctx->error("Error building macro tag $tag: ".$builder->errstr) unless defined $bout;
            $bout = apply_macros($bout, $param, $ctx, $cond, $recurse, $depth+1) if ($recurse || $macro->{recurse});
            $out .= $bout;
            $pos = pos $str;
            if ($macro->{once}) {
                $macro->{used} = 1;
                last;
            }
        }
        $out .= substr($str, $pos, $len - $pos) if $pos < $len;
        push @$processed, $name;
        $str = $out;
    }
    return $str;
}

sub _consume_up_to {
    my ($text, $start, $stoptag) = @_;
    my $pos;
    (pos $$text) = $start;
    while ($$text =~ m!(<(/?)($stoptag[^>]*?)>)!gx) {
       my($whole_tag, $prefix, $tag) = ($1, $2, $3);
       ($tag, my($args)) = split /\s+/, $tag, 2;
       next if $tag !~ m/$stoptag/x;
       my $end = pos $$text;
       if ($prefix && ($prefix eq '/')) {
         return ($end - length($whole_tag), $end);
       } else {
         my ($sec_end, $end_tag) = _consume_up_to($text, $end, $stoptag);
         last if !$sec_end;
         (pos $$text) = $end_tag;
       }
    }
    return (0, 0);
}

sub MacroDefine {
    my ($ctx, $args) = @_;
    my $name = $args->{name} || $args->{tag} || $args->{ctag};
    return $ctx->error("You did not specify a name for your macro.") if !$name;
    my $tokens = $ctx->stash('tokens');
    my $pattern = $args->{pattern};
    my $tag = $args->{tag} || $args->{ctag};
    my $string = $args->{string};

    # macro is a combination of text/html/MT tags that
    # is to be executed upon every use of the macro

    my $type;
    if ($pattern) {
        $pattern = decode_html($pattern);
        $type = 'p';
    } elsif ($string) {
        $string = decode_html($string);
        $type = 's';
    } elsif ($tag) {
        $type = 't';
    } else {
        return $ctx->error("You did not specify the type of macro.");
    }

    if ($args->{script}) {
        my $script = $args->{script};
        my $setup = '';
        # FIXME: this needs fixin'
        my $routine = 'bradchoate::macros::Scripting::'.$script.'::MacroSetup';
        if (defined &$routine) {
            no strict 'refs';
            $setup = $routine->();
        }
        my $macro = $ctx->stash('uncompiled');
        $macro = qq{<MT$script>}.$setup.$macro.qq{</MT$script>};
        # recompile tokens
        my $builder = $ctx->stash('builder');
        $tokens = $builder->compile($ctx, $macro);
        return $ctx->error("Error during macro compilation") if !$tokens;
    }
    my %macro = (type => $type, name => $name,
         once => $args->{once},
         recurse => $args->{recurse},
         no_html => $args->{no_html},
         pattern => $pattern, compiled_pattern => undef,
                 no_case => $args->{no_case},
         tag => $tag, tag_container => exists $args->{ctag},
                 script => $args->{script},
         string => $string, tokens => $tokens);

    my $macroHash = $ctx->stash('MacroMacroHash') || {};
    my $macroArray = $ctx->stash('MacroMacroArray') || [];

    if (defined $macroHash->{$name}) {
        # update existing pattern
        $macroArray->[$macroHash->{$name}] = \%macro;
    } else {
        push @{$macroArray}, \%macro;
        $macroHash->{$name} = scalar(@{$macroArray}) - 1;
    }

    $ctx->stash('MacroMacroHash', $macroHash);
    $ctx->stash('MacroMacroArray', $macroArray);

    return '';
}

sub MacroApply {
    my ($ctx, $args, $cond) = @_;
    my $out = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond);
    apply_macros($out, (exists $args->{macro} ? $args->{macro} : '1'), $ctx, $cond, $args->{recurse});
}

sub MacroAttr {
    my ($ctx, $args, $cond) = @_;
    my $name = $args->{name};
    return $ctx->error("You must specify a name attribute") unless $name;
    my $targs = $ctx->stash('MacroTagArgs');
    if (exists $args->{value}) {
        $targs->{$name} = build_expr($ctx, $args->{value}, $cond);
        return '';
    } elsif ($args->{remove}) {
        delete $targs->{$args->{$name}};
        return '';
    } else {
        my $value = $targs->{$name};
        if (defined $value) {
            return $value;
        } else {
            my $out = build_expr($ctx, $args->{default}, $cond);
            defined $out ? $out : '';
        }
    }
}

sub MacroContent {
    my ($ctx, $args, $cond) = @_;
    my $out = $ctx->stash('MacroContent');
    return $out if defined $out;
    return build_expr($ctx, $args->{default}, $cond);
}

sub MacroTag {
    my ($ctx, $args, $cond) = @_;
    if ($args->{rebuild}) {
        my $quot = $args->{quote} || '"';
        my $tag = $ctx->stash('MacroTag');
        return '' unless $tag;
        my $res = '';
        $res .= '<' . $tag;
        my $targs = $ctx->stash('MacroTagArgs');
        if ($targs) {
            foreach my $attr (sort keys %{$targs}) {
            $res .= ' '.$attr.'='.$quot.$targs->{$attr}.$quot;
            }
        }
        $res .= '>';
        return $res;
    } else {
        return $ctx->stash('MacroTag') || '';
    }
}

sub MacroReset {
    my ($ctx, $args, $cond) = @_;
    $ctx->stash('MacroMacroHash',undef);
    $ctx->stash('MacroMacroArray',undef);
    return '';
}

sub MacroMatch {
    my ($ctx, $args, $cond) = @_;
    my $matches = $ctx->stash('MacroMatches');
    if ($args->{glue}) {
        my $joined = join $args->{glue}, @$matches;
        return $joined if defined $joined;
    } else {
        if ($args->{position} >= 1) {
            my $out = $matches->[$args->{position}-1];
            return $out if defined $out;
        }
    }
    return build_expr($ctx, $args->{default}, $cond);
}

sub build_expr {
    my ($ctx, $val, $cond) = @_;
    $val = decode_html($val);
    if (($val =~ m/\<[mM][tT].*?\>/) ||
        ($val =~ s/\[(\/?[mM][tT](.*?))\]/\<$1\>/g)) {
        my $builder = $ctx->stash('builder');
        my $tok = $builder->compile($ctx, $val);
        defined($val = $builder->build($ctx, $tok, $cond))
            or return $ctx->error($builder->errstr);
    }
    return $val;
}

1;
