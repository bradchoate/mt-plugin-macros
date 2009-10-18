# Macros, a plugin for Movable Type

Sometimes it's nice to get a lot for a little. Macros let you do that. Instead
of typing laborious HTML as you write your entries, a macro can do all the
work for you so you can concentrate on writing. Perhaps you want to use a set
of icons within your posts but don't care to write `<img>` tags all day
long. Or maybe you'd like to link up to Google queries without having to type
out the full URL. This plugin allows you to do that and much more.

## Availability

You can download this plugin here: [MT-Macros-1.53.tar.gz][]

## Installation

To install, place all the files underneath the "plugins" directory from the
distribution into your Movable Type "plugins" directory. There are only two
files necessary to install. Specifically, these:

* (mt home)/plugins/Macros/config.yaml
* (mt home)/plugins/Macros/lib/Macros.pm

Refer to the Movable Type documentation for more information regarding
plugins.

## Description

This plugin allows you to define custom macros that can be expanded in a
variety of ways.

Tags made available through this plugin:

* `<MTMacroDefine>`: Container tag used to declare a new macro.
* `<MTMacroApply>`: Container tag that applies defined macros against content.
* `<MTMacroReset>`: Resets the macro system, clearing all existing macros.
* `<MTMacroContent>`: Tag for accessing child data from container tag macros.
* `<MTMacroTag>`: Provides the tag being processed.
* `<MTMacroAttr>`: Tag for reading attributes from tag macros.
* `<MTMacroMatch>`: Tag for retrieving matched elements from a pattern-based
  macro or matched elements from a tag-based macro that uses a pattern for the
  tag name.

### `<MTMacroDefine>`

These attributes are allowed:

* **name**: Uniquely identifies a given macro. This attribute
  is required for the pattern and string macro types. If not specified
  for tag or ctag macros, the tag/ctag value will be used as the name.
* **pattern**: Used to define a pattern-based macro.
* **tag**: Used to define a tag-based macro (a tag with no closing element).
* **ctag**: Used to define a container tag-based macro.
* **string**: Used to define a simple search/replace macro.
* **once**: Only process macro against the first match.
* **recurse**: Evaluate the result of this macro for additional macros.
* **no_html**: Keeps macro from altering any content within HTML tags. Should
  not be used with tag and ctag macros since they would never match anything.
* **no_case**: If specified, string, tag and container tags are matched
  without respect to case.
* **script**: Causes the Macro to be evaluated as an executable script. The
  value of this attribute should be a defined scripting language that is known
  to the Macros plugin.

Note: You can only specify **one** of the following attributes: pattern, tag,
ctag, string.

Note: tags specified with the 'tag' and 'ctag' attributes can contain pattern
matching elements.

Note: Macros are processed in the order they have been defined.

Here's an example:

    <MTMacroDefine name="smiley1" string=":-)">
        <img src="/images/smiley1.gif" height="20" width="20"
            alt=":-)" />
    </MTMacroDefine>

There's a simple search/replace macro that changes all the ':-)' to an `<img>`
HTML tag that points to (hopefully) a smiley graphic.

Here's a pattern-based macro:

    <MTMacroDefine name="uppercase" pattern="m/\^\^(.+?)\^\^/">
        <MTMacroMatch position="1" upper_case="1">
    </MTMacroDefine>

Here's a tag macro:

    <MTMacroDefine name="line" tag="line">
        <hr noshade="noshade" width="<MTMacroAttr name="width"
            default="100%">" />
    </MTMacroDefine>

Finally, a container tag macro:

    <MTMacroDefine name="blue" ctag="blue">
        <span style="color: blue"><MTMacroContent></span>
    </MTMacroDefine>

Tag macros can use patterns too:

    <MTMacroDefine name="smileys" tag="smiley(\d+)">
        <img src="/images/smiley<MTMacroMatch position="1">"
            height="20" width="20" alt=":-)" />
    </MTMacroDefine>

Your macros can be as complex as you'd like. Here's a fancy one I put together
that invokes the <a href="http://mtamazon.sourceforge.net/">MTAmazon
plugin</a> whenever you use a custom 'amazon' tag in your posts:

    <MTMacroDefine name="amazon" ctag="amazon">
        <MTUnless tag="MacroAttr" name="asin">
            <MTMacroAttr name="asin" setvar="asin">
            <MTAmazon devtoken="xxxxxxxxxx" associateid="bradchoate"
                search="$asin" method="Asin">
                <a href="<MTAmazonLink>"
                    title="Buy now at amazon.com-- only <MTAmazonSalePrice>!"
                    onmouseover="return overlib('<img
                        src=\'<MTAmazonSmallImage>\' align=\'left\'
                        border=\'0\' hspace=\'5\' /><b>
                        <MTAmazonTitle escape="js"></b><br />
                        Amazon Price: <b><MTAmazonSalePrice></b><br />
                        <a href=\'<MTAmazonLink>\'>Buy</a>', STICKY,
                        TIMEOUT, 5000);"
                    onmouseout="return nd();">
                    <MTAmazonTitle setvar="title">
                    <MTMacroContent default="$title">
                </a>
            </MTAmazon>
        </MTUnless>
        <MTUnless tag="MacroAttr" name="keyword">
            <MTMacroAttr name="keyword" setvar="keyword">
            <MTAmazon devtoken="xxxxxxxx" associateid="bradchoate"
                search="$keyword" method="Keyword" lastn="1">
                <a href="<MTAmazonLink>"
                    title="Buy now at amazon.com-- only <MTAmazonSalePrice>!"
                    onmouseover="return overlib('<img
                        src=\'<MTAmazonSmallImage>\' align=\'left\'
                        border=\'0\' hspace=\'5\' /><b>
                        <MTAmazonTitle escape="js"></b><br />
                        Amazon Price: <b><MTAmazonSalePrice></b><br />
                        <a href=\'<MTAmazonLink>\'>Buy</a>', STICKY,
                        TIMEOUT, 5000);"
                    onmouseout="return nd();">
                    <MTAmazonTitle setvar="title">
                    <MTMacroContent default="$title">
                </a>
            </MTAmazon>
        </MTUnless>
    </MTMacroDefine>

If you can follow that, you'll begin to see the power of this plugin. Here's a
before/after view what it does:

    I'm also interested in <amazon keyword="tangerine dream">some TD music</amazon>.

And when you publish, it comes out like this (the purple popup there is done
using the <a href="http://www.bosrup.com/web/overlib/">Overlib</a> script):

<div align="center">
    <img src="http://www.bradchoate.com/past/images/mtmacros-ctag2.jpg"
        width="250" height="98" alt="after" />
</div>

### `<MTMacroApply>`

This container tag applies macro rules to anything contained within it.

These attributes are available:

* **macro**: Assign '1' to cause all defined macros to expand. Or you can
  provide a list of space-delimited macro names. Or you can specify a regular 
  expression matching pattern in the form of "m/pattern/" to have 
  it select macros by a pattern.
* **recurse**: Instructs macro expansion to continue to evaluate macro results.

Here's how you might use it:

    <MTMacroApply>
        <MTEntryBody>
    </MTMacroApply>

Or perhaps you only want to apply certain macros. This will only apply the
macros named 'bold' and 'italic':

    <MTMacroApply macro="bold italic">
        <MTEntryBody>
    </MTMacroApply>

A pattern can also be used to select macros. This applies any macros
that are named with 'body_' as a prefix:

    <MTMacroApply macro="m/^body_/">
        <MTEntryBody>
    </MTMacroApply>

Another way to invoke the macros is to use the 'apply_macros' global
tag attribute. This allows you to apply macros to any 'MT' tag.

    <MTEntryBody apply_macros="1">

Or apply selectively, with a list of macro names or a pattern:

    <MTEntryBody apply_macros="m/^body_/">

### `<MTMacroReset>`

Use this tag to clear all defined macros.

### `<MTMacroConten>`

When used in side a macro definition, this tag expands to the value of the
content contained within the container macro tag currently being processed.

These attributes are available:

* **default**: Allows you to specify a default value in the event that there
  wasn't any content in the macro tag. Supports embedded expressions.

### `<MTMacroTag>`

Returns the name of the tag currently being processed.

These attributes are available:

* **rebuild**: If specified, MTMacroTag will return the full opening tag for
  the tag being processed. It will add all existing attributes.
* **quote**: Used to specify the quote character for rebuilding the tag
  expression (defaults to ").

### `<MTMacroAttr>`

This tag is used with tag or container tag macros. You can use it to select
the values of attributes used in your tag.

These attributes are available:

* **name**: The name of the attribute you are fetching.
* **value**: A value to assign to the existing tag. Useful in conjunction with
  the 'rebuild' attribute of the MacroTag tag. Supports embedded expressions.
* **remove**: If specified, the named attribute will be removed from the list
  of tag attributes.
* **default**: A default value to assign in case the attribute was unspecified
  (note: blanks are considered values-- the attribute must not be present at
  all in order for a default value to be assigned). Supports embedded
  expressions.

### `<MTMacroMatch>`

This tag is used to select matched elements of a pattern-based macro or parts
matched from a tag-based macro.

These attributes are available:

* **position**: The matched element you want to extract.
* **default**: The default value to assign in case the matched value is empty.
  Supports embedded expressions.

### Usage Notes

* For any tag attribute above that mentions 'supports embedded expressions',
  that means that the attribute can contain a Movable Type expression in the
  form of "`[MTEntryTitle]`" or "`<MTEntryTitle>`". If the attribute contains
  such content, it will be evaluated.
* If you use the pattern matching macros or you use a pattern to define your
  tag macros, please form them carefully or your macro may match more than you
  expect. For a tutorial on using Perl regular expressions visit this page:
  http://www.perldoc.com/perl5.6.1/pod/perlretut.html  
  And for advanced documentation, look here:
  http://www.perldoc.com/perl5.6.1/pod/perlre.html
* The 'script' attribute of the `<MTMacroDefine>` tag is extensible. Refer to
  my "PerlScript" plugin as an example of how to provide scripting support
  to this plugin.

### License

Released under the MIT License.

### Changelog

* 1.53: Updated structure of plugin for Movable Type 4.
* 1.52: string and pattern attribute values of the MTMacroDefine tag are
  now decoded for HTML entities.
* 1.51: Bugfix for 'script' attribute when nested MT tags are present.
* 1.5: Added 'script' attribute to MTMacroDefine.
* 1.4: Added 'no_case' attribute to MTMacroDefine.
* 1.31: Corrected closure tags for embedded expressions.
* 1.3: Added 'no_html' attribute to MTMacroDefine.
* 1.2: Added 'recurse' and 'once' attributes to MTMacroDefine. Added 'recurse'
  to MTMacroApply. Fixed bug where container tag 'MyTag' matches tag
  'MyTagSomething' (due to similar name prefix).
* 1.1: Added 'value' and 'remove' to MTMacroAttr. Added 'rebuild' to
  MTMacroTag.
* 1.0: Initial release

[MT-Macros-1.53.tar.gz]: http://cloud.github.com/downloads/bradchoate/mt-plugin-macros/MT-Macros-1.53.tar.gz
