# ustring.jl - Wrapper for ICU (International Components for Unicode) library

# Some content of the documentation strings was derived from the ICU header files ustring.h
# (Those portions copyright (C) 1996-2015, International Business Machines Corporation and others)

"""
   Unicode string handling functions

   These C API functions provide general Unicode string handling.

   Some functions are equivalent in name, signature, and behavior to the ANSI C <string.h>
   functions. (For example, they do not check for bad arguments like NULL string pointers.)
   In some cases, only the thread-safe variant of such a function is implemented here
   (see u_strtok_r()).

   Other functions provide more Unicode-specific functionality like locale-specific
   upper/lower-casing and string comparison in code point order.

   ICU uses 16-bit Unicode (UTF-16) in the form of arrays of UChar code units.
   UTF-16 encodes each Unicode code point with either one or two UChar code units.
   (This is the default form of Unicode, and a forward-compatible extension of the original,
   fixed-width form that was known as UCS-2. UTF-16 superseded UCS-2 with Unicode 2.0
   in 1996.)

   Some APIs accept a 32-bit UChar32 value for a single code point.

   ICU also handles 16-bit Unicode text with unpaired surrogates.
   Such text is not well-formed UTF-16.
   Code-point-related functions treat unpaired surrogates as surrogate code points,
   i.e., as separate units.

   Although UTF-16 is a variable-width encoding form (like some legacy multi-byte encodings),
   it is much more efficient even for random access because the code unit values
   for single-unit characters vs. lead units vs. trail units are completely disjoint.
   This means that it is easy to determine character (code point) boundaries from
   random offsets in the string.

   Unicode (UTF-16) string processing is optimized for the single-unit case.
   Although it is important to support supplementary characters
   (which use pairs of lead/trail code units called "surrogates"),
   their occurrence is rare. Almost all characters in modern use require only
   a single UChar code unit (i.e., their code point values are <=0xffff).

   For more details see the User Guide Strings chapter (http://icu-project.org/userguide/strings.html).
   For a discussion of the handling of unpaired surrogates see also
   Jitterbug 2145 and its icu mailing list proposal on 2002-sep-18.
"""
module ustring end

macro libstr(s)     ; _libicu(s, iculib,     "u_str")     ; end

_tolower(dest, destsiz, src, srclen, err) =
    ccall(@libstr(ToLower), Cint,
          (Ptr{UChar}, Cint, Ptr{UChar}, Cint, Ptr{UInt8}, Ptr{UErrorCode}),
          dest, destsiz, src, srclen, locale[], err)

_toupper(dest, destsiz, src, srclen, err) =
    ccall(@libstr(ToUpper), Cint,
          (Ptr{UChar}, Cint, Ptr{UChar}, Cint, Ptr{UInt8}, Ptr{UErrorCode}),
          dest, destsiz, src, srclen, locale[], err)

_foldcase(dest, destsiz, src, srclen, err) =
    ccall(@libstr(FoldCase), Cint,
          (Ptr{UChar}, Cint, Ptr{UChar}, Cint, Cint, Ptr{UErrorCode}),
          dest, destsiz, src, srclen, 0, err)

_totitle(dest, destsiz, src, srclen, breakiter, err) =
    ccall(@libstr(ToTitle), Cint,
          (Ptr{UChar}, Cint, Ptr{UChar}, Cint, Ptr{Cvoid}, Ptr{UInt8}, Ptr{UErrorCode}),
          dest, destsiz, src, src, breakiter, locale[], err)

"""
   Case-folds the characters in a string.

   Case-folding is locale-independent and not context-sensitive, but there is an option for whether to
   include or exclude mappings for dotted I and dotless i that are marked with 'T' in CaseFolding.txt.

   The result may be longer or shorter than the original.
   The source string and the destination buffer are allowed to overlap.

   Arguments:
   src       The original string
   options   Either U_FOLD_CASE_DEFAULT or U_FOLD_CASE_EXCLUDE_SPECIAL_I

   Returns:  Case-folded string
"""
function foldcase end

for f in (:tolower, :toupper, :foldcase)
    uf = Symbol(string('_',f))
    @eval begin
        function ($f)(str::T) where {T<:Union{UCS2Str, UTF16Str}}
            srclen = ncodeunits(str)
            dest, pnt = Strs._allocate(UInt16, srclen)
            err = UErrorCode[0]
            destsiz = ($uf)(dest, srclen, Strs._pnt(str), srclen, err)
            destsiz != srclen && resize!(dest, destsiz)
            # Retry with large enough buffer if got buffer overflow
            if err[1] == U_BUFFER_OVERFLOW_ERROR
                err[1] = 0
                ($uf)(dest, destsiz, Strs._pnt(str), srclen, err)
            end
            FAILURE(err[1]) && error("failed to map case")
            Str(cse(T), dest)
        end
    end
end

"""
   Titlecase a string.

   Casing is locale-dependent and context-sensitive.
   Titlecasing uses a break iterator to find the first characters of words that are to be titlecased.
   It titlecases those characters and lowercases all others.

   The titlecase break iterator can be provided to customize for arbitrary styles, using rules and
   dictionaries beyond the standard iterators.  It may be more efficient to always provide an iterator
   to avoid opening and closing one for each string.
   The standard titlecase iterator for the root locale implements the algorithm of Unicode TR 21.

   This function uses only the setText(), first() and next() methods of the provided break iterator.

   The result may be longer or shorter than the original.

   Arguments:
   src       The original string
   titleIter A break iterator to find the first characters of words that are to be titlecased.
             If none is provided, then a standard titlecase break iterator is opened.
   locale    The locale to consider, or "" for the root locale (not passed -> default locale)

   Returns: Title-cased string
"""
function totitle end

function totitle(str::T, bi) where {T<:Union{UCS2Str, UTF16Str}}
    srclen = ncodeunits(str)
    dest, pnt = Strs._allocate(UInt16, len)
    err = UErrorCode[0]
    dstlen = _totitle(pnt, srclen, Strs._pnt(src), srclen, bi, err)
    dstlen != srclen && resize!(dest, dstlen)
    # Retry with large enough buffer if got buffer overflow
    if err[1] == U_BUFFER_OVERFLOW_ERROR
        err[1] = 0
        _totitle(dest, dstlen, Strs._pnt(src), srclen, bi, err)
    end
    FAILURE(err[1]) && error("failed to map case")
    Str(cse(T), dest)
end
totitle(str::T) where {T<:Union{UCS2Str, UTF16Str}} = totitle(str, get_break_iterator())
