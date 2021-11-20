# DFTXT

An atempt to develop a very simple text markup language which is easy to parse.
This repository holds a small proof-of-concept compiler (still WIP) writen in Zig that takes
.dftxt files and outputs .html code. 

## The markup language

```
* Headings are created using '*' characters, like in emacs org-mode.
** The level of the heading corresponds to the number of '*'
*** The heading's texts follows the '*' characters and must be contained in a single line.

- Unordered lists are defined by placing a '-' as the first non-white character in a line.
 - The depth/level of a list item is defined by the number of white-space characters that appear before the '-' character.
  - Currently each item is limited to a single line,
 - but I plan to extend that in the future.

Everything else is considered paragraph text. 

Different paragraphs are separated by blank/empy lines. Otherwise they are
considered to be in the same paragraph, just like in markdown.

You can insert links like this: [http://www.danielfortes.com/ | My Website]. 
I plan to add support to wiki-style links as well [[wiki-link]].
```
sdf


